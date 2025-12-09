defmodule FeedbackBot.Feedbacks do
  @moduledoc """
  Context для управління фідбеками
  """

  import Ecto.Query, warn: false
  alias FeedbackBot.Repo
  alias FeedbackBot.Feedbacks.Feedback

  @doc """
  Повертає список усіх фідбеків
  """
  def list_feedbacks(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    employee_id = Keyword.get(opts, :employee_id)

    query = from f in Feedback, order_by: [desc: f.inserted_at], limit: ^limit

    query =
      if employee_id do
        from f in query, where: f.employee_id == ^employee_id
      else
        query
      end

    Repo.all(query) |> Repo.preload(:employee)
  end

  @doc """
  Отримує фідбек за ID
  """
  def get_feedback!(id) do
    Repo.get!(Feedback, id) |> Repo.preload(:employee)
  end

  @doc """
  Створює новий фідбек
  """
  def create_feedback(attrs \\ %{}) do
    %Feedback{}
    |> Feedback.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Оновлює фідбек
  """
  def update_feedback(%Feedback{} = feedback, attrs) do
    feedback
    |> Feedback.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Видаляє фідбек
  """
  def delete_feedback(%Feedback{} = feedback) do
    Repo.delete(feedback)
  end

  @doc """
  Повертає фідбеки за період
  """
  def list_feedbacks_by_period(period_start, period_end) do
    from(f in Feedback,
      where: f.inserted_at >= ^period_start and f.inserted_at < ^period_end,
      where: f.processing_status == "completed",
      order_by: [desc: f.inserted_at]
    )
    |> Repo.all()
    |> Repo.preload(:employee)
  end

  @doc """
  Повертає останні N фідбеків
  """
  def list_recent_feedbacks(limit \\ 10) do
    from(f in Feedback,
      where: f.processing_status == "completed",
      order_by: [desc: f.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
    |> Repo.preload(:employee)
  end

  @doc """
  Повертає статистику по тональності за період
  """
  def get_sentiment_stats(period_start, period_end) do
    query =
      from f in Feedback,
        where: f.inserted_at >= ^period_start and f.inserted_at < ^period_end,
        where: f.processing_status == "completed",
        select: %{
          avg_sentiment: avg(f.sentiment_score),
          total: count(f.id),
          positive: filter(count(f.id), f.sentiment_label == "positive"),
          neutral: filter(count(f.id), f.sentiment_label == "neutral"),
          negative: filter(count(f.id), f.sentiment_label == "negative")
        }

    Repo.one(query) || %{
      avg_sentiment: 0.0,
      total: 0,
      positive: 0,
      neutral: 0,
      negative: 0
    }
  end

  @doc """
  Фільтрація фідбеків з розширеними опціями
  """
  def filter_feedbacks(filters \\ %{}) do
    base_query = from(f in Feedback, where: f.processing_status == "completed")

    query =
      base_query
      |> filter_by_employee(filters)
      |> filter_by_sentiment(filters)
      |> filter_by_date_range(filters)
      |> filter_by_urgency(filters)
      |> filter_by_impact(filters)
      |> filter_by_trend(filters)
      |> order_feedbacks(filters)
      |> maybe_limit(filters)

    Repo.all(query) |> Repo.preload(:employee)
  end

  defp filter_by_employee(query, %{employee_id: employee_id}) when not is_nil(employee_id) do
    from f in query, where: f.employee_id == ^employee_id
  end
  defp filter_by_employee(query, _), do: query

  defp filter_by_sentiment(query, %{sentiment: sentiment}) when sentiment in ["positive", "neutral", "negative"] do
    from f in query, where: f.sentiment_label == ^sentiment
  end
  defp filter_by_sentiment(query, _), do: query

  defp filter_by_date_range(query, %{from: from_date, to: to_date}) do
    from f in query, where: f.inserted_at >= ^from_date and f.inserted_at <= ^to_date
  end
  defp filter_by_date_range(query, %{from: from_date}) do
    from f in query, where: f.inserted_at >= ^from_date
  end
  defp filter_by_date_range(query, %{to: to_date}) do
    from f in query, where: f.inserted_at <= ^to_date
  end
  defp filter_by_date_range(query, _), do: query

  defp filter_by_urgency(query, %{min_urgency: min_urgency}) do
    from f in query, where: f.urgency_score >= ^min_urgency
  end
  defp filter_by_urgency(query, _), do: query

  defp filter_by_impact(query, %{min_impact: min_impact}) do
    from f in query, where: f.impact_score >= ^min_impact
  end
  defp filter_by_impact(query, _), do: query

  defp filter_by_trend(query, %{trend: trend}) when trend in ["improving", "declining", "stable"] do
    from f in query, where: f.trend_direction == ^trend
  end
  defp filter_by_trend(query, _), do: query

  defp order_feedbacks(query, %{order_by: order_by}) when order_by in [:urgency, :impact, :date] do
    case order_by do
      :urgency -> from f in query, order_by: [desc: f.urgency_score, desc: f.inserted_at]
      :impact -> from f in query, order_by: [desc: f.impact_score, desc: f.inserted_at]
      :date -> from f in query, order_by: [desc: f.inserted_at]
    end
  end
  defp order_feedbacks(query, _), do: from(f in query, order_by: [desc: f.inserted_at])

  defp maybe_limit(query, %{limit: limit}) when is_integer(limit) and limit > 0 do
    from f in query, limit: ^limit
  end
  defp maybe_limit(query, _), do: query

  @doc """
  Full-text search по транскрипціях
  """
  def search_feedbacks(search_term) when is_binary(search_term) and search_term != "" do
    search_query = "%#{search_term}%"

    from(f in Feedback,
      where: f.processing_status == "completed",
      where:
        ilike(f.transcription, ^search_query) or
        ilike(f.summary, ^search_query) or
        fragment("? @@ to_tsquery('english', ?)", f.transcription, ^search_term),
      order_by: [desc: f.inserted_at]
    )
    |> Repo.all()
    |> Repo.preload(:employee)
  end
  def search_feedbacks(_), do: []

  @doc """
  Отримати heatmap data для sentiment по співробітниках і часу
  """
  def get_sentiment_heatmap(period_start, period_end, interval \\ :day) do
    interval_str = to_string(interval)

    from(f in Feedback,
      where: f.inserted_at >= ^period_start and f.inserted_at < ^period_end,
      where: f.processing_status == "completed",
      join: e in assoc(f, :employee),
      group_by: [e.id, e.name],
      select: %{
        employee_id: e.id,
        employee_name: e.name,
        period: fragment("date_trunc(?, MIN(?))", ^interval_str, f.inserted_at),
        avg_sentiment: avg(f.sentiment_score),
        count: count(f.id)
      },
      order_by: [fragment("date_trunc(?, MIN(?))", ^interval_str, f.inserted_at), e.name]
    )
    |> Repo.all()
  end

  @doc """
  Отримати word frequency для word cloud
  """
  def get_word_frequencies(arg \\ %{})

  def get_word_frequencies(feedbacks) when is_list(feedbacks) do
    feedbacks
    |> Enum.flat_map(fn f ->
      (f.transcription || "")
      |> String.downcase()
      |> String.replace(~r/[^\p{L}\s]/u, "")
      |> String.split()
      |> Enum.filter(&(String.length(&1) > 3))
    end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_word, count} -> count end, :desc)
    |> Enum.take(100)
  end

  def get_word_frequencies(filters) when is_map(filters) do
    feedbacks = filter_feedbacks(filters)

    feedbacks
    |> get_word_frequencies()
  end

  @doc """
  Отримати timeline дані для хронології фідбеків
  """
  def get_timeline_data(period_start, period_end) do
    from(f in Feedback,
      where: f.inserted_at >= ^period_start and f.inserted_at < ^period_end,
      where: f.processing_status == "completed",
      join: e in assoc(f, :employee),
      select: %{
        id: f.id,
        date: f.inserted_at,
        employee_name: e.name,
        employee_id: e.id,
        sentiment_score: f.sentiment_score,
        sentiment_label: f.sentiment_label,
        urgency_score: f.urgency_score,
        impact_score: f.impact_score,
        summary: f.summary,
        topics: f.topics
      },
      order_by: [desc: f.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Порівняльна статистика між співробітниками
  """
  def get_employee_comparison(employee_ids, period_start, period_end) do
    from(f in Feedback,
      where: f.employee_id in ^employee_ids,
      where: f.inserted_at >= ^period_start and f.inserted_at < ^period_end,
      where: f.processing_status == "completed",
      join: e in assoc(f, :employee),
      group_by: [e.id, e.name],
      select: %{
        employee_id: e.id,
        employee_name: e.name,
        avg_sentiment: avg(f.sentiment_score),
        avg_urgency: avg(f.urgency_score),
        avg_impact: avg(f.impact_score),
        total_feedbacks: count(f.id),
        positive_count: filter(count(f.id), f.sentiment_label == "positive"),
        neutral_count: filter(count(f.id), f.sentiment_label == "neutral"),
        negative_count: filter(count(f.id), f.sentiment_label == "negative")
      }
    )
    |> Repo.all()
  end

  @doc """
  Trend lines - динаміка змін sentiment по днях
  """
  def get_sentiment_trend(employee_id, days \\ 30) do
    period_start = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    from(f in Feedback,
      where: f.employee_id == ^employee_id,
      where: f.inserted_at >= ^period_start,
      where: f.processing_status == "completed",
      group_by: fragment("date_trunc('day', ?)", f.inserted_at),
      select: %{
        date: fragment("date_trunc('day', ?)", f.inserted_at),
        avg_sentiment: avg(f.sentiment_score),
        avg_urgency: avg(f.urgency_score),
        avg_impact: avg(f.impact_score),
        count: count(f.id)
      },
      order_by: fragment("date_trunc('day', ?)", f.inserted_at)
    )
    |> Repo.all()
  end

  @doc """
  Отримує summary статистику для Analytics snapshots
  """
  def get_summary_stats(%{from: period_start, to: period_end}) do
    # Основна статистика
    base_stats = from(f in Feedback,
      where: f.inserted_at >= ^period_start and f.inserted_at <= ^period_end,
      where: f.processing_status == "completed",
      select: %{
        total_count: count(f.id),
        avg_sentiment: avg(f.sentiment_score),
        positive_count: filter(count(f.id), f.sentiment_label == "positive"),
        neutral_count: filter(count(f.id), f.sentiment_label == "neutral"),
        negative_count: filter(count(f.id), f.sentiment_label == "negative")
      }
    ) |> Repo.one() || %{
      total_count: 0,
      avg_sentiment: 0.0,
      positive_count: 0,
      neutral_count: 0,
      negative_count: 0
    }

    # Top issues - групуємо по description з issues (JSON array)
    feedbacks = filter_feedbacks(%{from: period_start, to: period_end})

    top_issues = feedbacks
      |> Enum.flat_map(fn f -> f.issues || [] end)
      |> Enum.group_by(fn issue -> Map.get(issue, "description", "Unknown") end)
      |> Enum.map(fn {description, issues} ->
        %{
          "description" => description,
          "count" => length(issues),
          "avg_severity" => (Enum.map(issues, fn i -> Map.get(i, "severity", "medium") end) |> Enum.at(0))
        }
      end)
      |> Enum.sort_by(fn issue -> issue["count"] end, :desc)
      |> Enum.take(10)

    # Top strengths - групуємо strengths
    top_strengths = feedbacks
      |> Enum.flat_map(fn f -> f.strengths || [] end)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_strength, count} -> count end, :desc)
      |> Enum.take(10)
      |> Enum.map(fn {strength, count} ->
        %{"description" => strength, "count" => count}
      end)

    # Employee stats
    employee_stats = from(f in Feedback,
      where: f.inserted_at >= ^period_start and f.inserted_at <= ^period_end,
      where: f.processing_status == "completed",
      join: e in assoc(f, :employee),
      group_by: [e.id, e.name],
      select: %{
        "employee_id" => e.id,
        "employee_name" => e.name,
        "total_feedbacks" => count(f.id),
        "avg_sentiment" => avg(f.sentiment_score),
        "positive_count" => filter(count(f.id), f.sentiment_label == "positive"),
        "negative_count" => filter(count(f.id), f.sentiment_label == "negative")
      }
    ) |> Repo.all()

    Map.merge(base_stats, %{
      top_issues: top_issues,
      top_strengths: top_strengths,
      employee_stats: employee_stats
    })
  end
end
