defmodule FeedbackBot.Analytics.TrendAnalyzer do
  @moduledoc """
  Потужний аналізатор трендів, який виявляє:
  - Зміни тональності
  - Нові та вирішені проблеми
  - Кореляції між проблемами
  - Звʼязки між співробітниками
  """

  import Ecto.Query
  alias FeedbackBot.{Repo, Feedbacks}
  alias FeedbackBot.Analytics.Snapshot
  require Logger

  @doc """
  Виконує щоденний аналіз
  """
  def analyze_daily do
    yesterday = DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.to_date()
    period_start = DateTime.new!(yesterday, ~T[00:00:00])
    period_end = DateTime.new!(yesterday, ~T[23:59:59])

    analyze_period("daily", period_start, period_end)
  end

  @doc """
  Виконує щотижневий аналіз
  """
  def analyze_weekly do
    today = DateTime.utc_now() |> DateTime.to_date()
    week_start = Date.add(today, -7)

    period_start = DateTime.new!(week_start, ~T[00:00:00])
    period_end = DateTime.new!(today, ~T[23:59:59])

    analyze_period("weekly", period_start, period_end)
  end

  @doc """
  Виконує щомісячний аналіз
  """
  def analyze_monthly do
    today = DateTime.utc_now() |> DateTime.to_date()
    month_start = Date.add(today, -30)

    period_start = DateTime.new!(month_start, ~T[00:00:00])
    period_end = DateTime.new!(today, ~T[23:59:59])

    analyze_period("monthly", period_start, period_end)
  end

  @doc """
  Аналізує період та створює snapshot
  """
  def analyze_period(period_type, period_start, period_end) do
    Logger.info("Analyzing #{period_type} period: #{period_start} to #{period_end}")

    feedbacks = Feedbacks.list_feedbacks_by_period(period_start, period_end)

    if Enum.empty?(feedbacks) do
      Logger.info("No feedbacks found for period")
      {:ok, :no_data}
    else
      # Базова статистика
      total_feedbacks = length(feedbacks)
      sentiment_stats = calculate_sentiment_stats(feedbacks)

      # Отримуємо попередній період для порівняння
      previous_stats = get_previous_period_stats(period_type, period_start)
      sentiment_trend = calculate_trend(sentiment_stats.avg_sentiment, previous_stats)

      # Аналіз проблем
      issue_analysis = analyze_issues(feedbacks, previous_stats)

      # Аналіз по співробітниках
      employee_stats = analyze_employees(feedbacks)

      # Кореляції
      issue_correlations = find_issue_correlations(feedbacks)
      employee_correlations = find_employee_correlations(feedbacks)

      # AI інсайти
      ai_insights = generate_ai_insights(feedbacks, sentiment_trend, issue_analysis)

      snapshot_attrs = %{
        period_type: period_type,
        period_start: period_start,
        period_end: period_end,
        total_feedbacks: total_feedbacks,
        avg_sentiment: sentiment_stats.avg_sentiment,
        sentiment_trend: sentiment_trend,
        positive_count: sentiment_stats.positive_count,
        neutral_count: sentiment_stats.neutral_count,
        negative_count: sentiment_stats.negative_count,
        top_issues: issue_analysis.top_issues,
        top_strengths: issue_analysis.top_strengths,
        emerging_issues: issue_analysis.emerging_issues,
        resolved_issues: issue_analysis.resolved_issues,
        employee_stats: employee_stats,
        issue_correlations: issue_correlations,
        employee_correlations: employee_correlations,
        ai_insights: ai_insights.text,
        recommendations: ai_insights.recommendations
      }

      %Snapshot{}
      |> Snapshot.changeset(snapshot_attrs)
      |> Repo.insert(
        on_conflict: {:replace_all_except, [:id, :inserted_at]},
        conflict_target: [:period_type, :period_start]
      )
    end
  end

  # === Приватні функції ===

  defp calculate_sentiment_stats(feedbacks) do
    total = length(feedbacks)

    sentiment_counts =
      feedbacks
      |> Enum.group_by(& &1.sentiment_label)
      |> Enum.map(fn {label, list} -> {label, length(list)} end)
      |> Enum.into(%{})

    avg_sentiment =
      feedbacks
      |> Enum.map(& &1.sentiment_score)
      |> Enum.sum()
      |> Kernel./(max(total, 1))

    %{
      avg_sentiment: avg_sentiment,
      positive_count: Map.get(sentiment_counts, "positive", 0),
      neutral_count: Map.get(sentiment_counts, "neutral", 0),
      negative_count: Map.get(sentiment_counts, "negative", 0)
    }
  end

  defp get_previous_period_stats(period_type, current_period_start) do
    shift_days =
      case period_type do
        "daily" -> -1
        "weekly" -> -7
        "monthly" -> -30
      end

    previous_start = DateTime.add(current_period_start, shift_days, :day)

    query =
      from s in Snapshot,
        where: s.period_type == ^period_type,
        where: s.period_start == ^previous_start,
        limit: 1

    case Repo.one(query) do
      nil -> %{avg_sentiment: 0.0, top_issues: []}
      snapshot -> snapshot
    end
  end

  defp calculate_trend(current_sentiment, previous_stats) do
    previous_sentiment = Map.get(previous_stats, :avg_sentiment, 0.0)

    if previous_sentiment == 0.0 do
      0.0
    else
      current_sentiment - previous_sentiment
    end
  end

  defp analyze_issues(feedbacks, previous_stats) do
    # Всі проблеми з поточного періоду
    current_issues =
      feedbacks
      |> Enum.flat_map(& &1.issues)
      |> Enum.group_by(&Map.get(&1, "description"))
      |> Enum.map(fn {description, issues} ->
        %{
          "description" => description,
          "count" => length(issues),
          "avg_severity" => calculate_avg_severity(issues),
          "categories" => Enum.map(issues, &Map.get(&1, "category")) |> Enum.uniq(),
          "affected_employees" =>
            feedbacks
            |> Enum.filter(fn f ->
              Enum.any?(f.issues, &(Map.get(&1, "description") == description))
            end)
            |> Enum.map(& &1.employee_id)
            |> Enum.uniq()
            |> length()
        }
      end)
      |> Enum.sort_by(&Map.get(&1, "count"), :desc)

    top_issues = Enum.take(current_issues, 10)

    # Попередні проблеми
    previous_issue_descriptions =
      previous_stats
      |> Map.get(:top_issues, [])
      |> Enum.map(&Map.get(&1, "description"))
      |> MapSet.new()

    current_issue_descriptions =
      current_issues
      |> Enum.map(&Map.get(&1, "description"))
      |> MapSet.new()

    # Нові проблеми (є зараз, але не було раніше)
    emerging_issues =
      current_issues
      |> Enum.filter(fn issue ->
        !MapSet.member?(previous_issue_descriptions, Map.get(issue, "description"))
      end)
      |> Enum.take(5)

    # Вирішені проблеми (були раніше, але зараз немає)
    resolved_issue_descriptions =
      MapSet.difference(previous_issue_descriptions, current_issue_descriptions)

    resolved_issues =
      previous_stats
      |> Map.get(:top_issues, [])
      |> Enum.filter(fn issue ->
        MapSet.member?(resolved_issue_descriptions, Map.get(issue, "description"))
      end)
      |> Enum.take(5)

    # Сильні сторони
    top_strengths =
      feedbacks
      |> Enum.flat_map(& &1.strengths)
      |> Enum.frequencies()
      |> Enum.map(fn {strength, count} -> %{"strength" => strength, "count" => count} end)
      |> Enum.sort_by(&Map.get(&1, "count"), :desc)
      |> Enum.take(10)

    %{
      top_issues: top_issues,
      top_strengths: top_strengths,
      emerging_issues: emerging_issues,
      resolved_issues: resolved_issues
    }
  end

  defp calculate_avg_severity(issues) do
    severity_values = %{"low" => 1, "medium" => 2, "high" => 3}

    total =
      issues
      |> Enum.map(&Map.get(&1, "severity", "medium"))
      |> Enum.map(&Map.get(severity_values, &1, 2))
      |> Enum.sum()

    avg = total / max(length(issues), 1)

    cond do
      avg < 1.5 -> "low"
      avg < 2.5 -> "medium"
      true -> "high"
    end
  end

  defp analyze_employees(feedbacks) do
    feedbacks
    |> Enum.group_by(& &1.employee_id)
    |> Enum.map(fn {employee_id, emp_feedbacks} ->
      employee = List.first(emp_feedbacks).employee

      avg_sentiment =
        emp_feedbacks
        |> Enum.map(& &1.sentiment_score)
        |> Enum.sum()
        |> Kernel./(length(emp_feedbacks))

      sentiment_distribution =
        emp_feedbacks
        |> Enum.group_by(& &1.sentiment_label)
        |> Enum.map(fn {label, list} -> {label, length(list)} end)
        |> Enum.into(%{})

      top_issues =
        emp_feedbacks
        |> Enum.flat_map(& &1.issues)
        |> Enum.frequencies_by(&Map.get(&1, "description"))
        |> Enum.sort_by(fn {_k, v} -> v end, :desc)
        |> Enum.take(3)
        |> Enum.map(fn {desc, count} -> %{"description" => desc, "count" => count} end)

      %{
        "employee_id" => employee_id,
        "employee_name" => employee.name,
        "feedback_count" => length(emp_feedbacks),
        "avg_sentiment" => Float.round(avg_sentiment, 3),
        "sentiment_distribution" => sentiment_distribution,
        "top_issues" => top_issues
      }
    end)
    |> Enum.sort_by(&Map.get(&1, "avg_sentiment"))
  end

  defp find_issue_correlations(feedbacks) do
    # Знаходимо проблеми, які часто зʼявляються разом
    issue_pairs =
      feedbacks
      |> Enum.flat_map(fn feedback ->
        issues = Enum.map(feedback.issues, &Map.get(&1, "description"))

        for i1 <- issues, i2 <- issues, i1 < i2 do
          Enum.sort([i1, i2])
        end
      end)
      |> Enum.frequencies()
      |> Enum.filter(fn {_pair, count} -> count >= 2 end)
      |> Enum.sort_by(fn {_pair, count} -> count end, :desc)
      |> Enum.take(10)
      |> Enum.map(fn {[issue1, issue2], count} ->
        %{
          "issue1" => issue1,
          "issue2" => issue2,
          "correlation_count" => count,
          "strength" => calculate_correlation_strength(count, length(feedbacks))
        }
      end)

    issue_pairs
  end

  defp find_employee_correlations(feedbacks) do
    # Знаходимо співробітників з подібними проблемами
    employee_issues =
      feedbacks
      |> Enum.group_by(& &1.employee_id)
      |> Enum.map(fn {emp_id, emp_feedbacks} ->
        issues =
          emp_feedbacks
          |> Enum.flat_map(& &1.issues)
          |> Enum.map(&Map.get(&1, "description"))
          |> Enum.uniq()
          |> MapSet.new()

        {emp_id, issues}
      end)

    correlations =
      for {emp1_id, issues1} <- employee_issues,
          {emp2_id, issues2} <- employee_issues,
          emp1_id < emp2_id do
        common_issues = MapSet.intersection(issues1, issues2)
        similarity = MapSet.size(common_issues) / max(MapSet.size(MapSet.union(issues1, issues2)), 1)

        if similarity > 0.3 do
          emp1 = feedbacks |> Enum.find(&(&1.employee_id == emp1_id)) |> Map.get(:employee)
          emp2 = feedbacks |> Enum.find(&(&1.employee_id == emp2_id)) |> Map.get(:employee)

          %{
            "employee1_id" => emp1_id,
            "employee1_name" => emp1.name,
            "employee2_id" => emp2_id,
            "employee2_name" => emp2.name,
            "common_issues" => MapSet.to_list(common_issues),
            "similarity_score" => Float.round(similarity, 3)
          }
        end
      end
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(&Map.get(&1, "similarity_score"), :desc)
      |> Enum.take(5)

    correlations
  end

  defp calculate_correlation_strength(count, total_feedbacks) do
    ratio = count / max(total_feedbacks, 1)

    cond do
      ratio > 0.5 -> "strong"
      ratio > 0.2 -> "moderate"
      true -> "weak"
    end
  end

  defp generate_ai_insights(feedbacks, sentiment_trend, issue_analysis) do
    # Тут можна використати GPT для генерації інсайтів
    # Для простоти зараз створимо базові інсайти

    trend_text =
      cond do
        sentiment_trend > 0.1 -> "значно покращилась"
        sentiment_trend > 0 -> "трохи покращилась"
        sentiment_trend < -0.1 -> "значно погіршилась"
        sentiment_trend < 0 -> "трохи погіршилась"
        true -> "залишилась стабільною"
      end

    insights = """
    Загальна тональність #{trend_text} порівняно з попереднім періодом (#{Float.round(sentiment_trend, 3)}).

    Проаналізовано #{length(feedbacks)} фідбеків.

    #{if length(issue_analysis.emerging_issues) > 0, do: "Виявлено #{length(issue_analysis.emerging_issues)} нових проблем, які потребують уваги.", else: ""}

    #{if length(issue_analysis.resolved_issues) > 0, do: "#{length(issue_analysis.resolved_issues)} попередніх проблем більше не згадуються, що може вказувати на покращення.", else: ""}
    """

    recommendations =
      build_recommendations(sentiment_trend, issue_analysis.top_issues, issue_analysis.emerging_issues)

    %{
      text: String.trim(insights),
      recommendations: recommendations
    }
  end

  defp build_recommendations(sentiment_trend, top_issues, emerging_issues) do
    recs = []

    recs =
      if sentiment_trend < -0.1 do
        ["Терміново звернути увагу на погіршення загальної тональності" | recs]
      else
        recs
      end

    recs =
      if length(top_issues) > 0 do
        top_issue = List.first(top_issues)

        [
          "Найбільш критична проблема: #{Map.get(top_issue, "description")} (згадується #{Map.get(top_issue, "count")} разів)"
          | recs
        ]
      else
        recs
      end

    recs =
      if length(emerging_issues) > 0 do
        ["Моніторити нові проблеми, які з'явились у цьому періоді" | recs]
      else
        recs
      end

    Enum.reverse(recs)
  end
end
