defmodule FeedbackBot.Analytics do
  @moduledoc """
  Context для роботи з аналітикою
  """

  import Ecto.Query
  alias FeedbackBot.Repo
  alias FeedbackBot.Analytics.Snapshot
  alias FeedbackBot.Feedbacks

  @doc """
  Ініціалізує всі типи snapshots (daily, weekly, monthly)
  Викликається при старті застосунку або вручну для заповнення даних
  """
  def initialize_all_snapshots do
    results = %{
      daily: create_snapshot("daily"),
      weekly: create_snapshot("weekly"),
      monthly: create_snapshot("monthly")
    }

    # Логуємо результати
    require Logger
    Logger.info("Analytics snapshots initialized: daily=#{inspect(elem(results.daily, 0))}, weekly=#{inspect(elem(results.weekly, 0))}, monthly=#{inspect(elem(results.monthly, 0))}")

    results
  end

  @doc """
  Створює або оновлює analytics snapshot для заданого періоду
  """
  def create_snapshot(period_type) do
    {period_start, period_end} = get_period_bounds(period_type)

    # Отримуємо статистику за період
    stats = Feedbacks.get_summary_stats(%{from: period_start, to: period_end})

    snapshot_attrs = %{
      period_type: period_type,
      period_start: period_start,
      period_end: period_end,
      total_feedbacks: stats.total_count || 0,
      avg_sentiment: stats.avg_sentiment || 0.0,
      positive_count: stats.positive_count || 0,
      neutral_count: stats.neutral_count || 0,
      negative_count: stats.negative_count || 0,
      sentiment_trend: calculate_sentiment_trend(period_type, stats.avg_sentiment || 0.0),
      top_issues: stats.top_issues || [],
      top_strengths: stats.top_strengths || [],
      employee_stats: stats.employee_stats || []
    }

    # Шукаємо існуючий snapshot для цього періоду
    existing = from(s in Snapshot,
      where: s.period_type == ^period_type and s.period_start == ^period_start
    ) |> Repo.one()

    case existing do
      nil ->
        # Створюємо новий
        %Snapshot{}
        |> Snapshot.changeset(snapshot_attrs)
        |> Repo.insert()

      existing_snapshot ->
        # Оновлюємо існуючий
        existing_snapshot
        |> Snapshot.changeset(snapshot_attrs)
        |> Repo.update()
    end
  end

  defp get_period_bounds("daily") do
    now = DateTime.utc_now()
    start_of_day = DateTime.new!(Date.utc_today(), ~T[00:00:00])
    {start_of_day, now}
  end

  defp get_period_bounds("weekly") do
    now = DateTime.utc_now()
    days_since_monday = Date.day_of_week(Date.utc_today()) - 1
    start_of_week = DateTime.add(now, -days_since_monday, :day)
    start_of_week = DateTime.new!(DateTime.to_date(start_of_week), ~T[00:00:00])
    {start_of_week, now}
  end

  defp get_period_bounds("monthly") do
    now = DateTime.utc_now()
    start_of_month = DateTime.new!(Date.utc_today() |> Date.beginning_of_month(), ~T[00:00:00])
    {start_of_month, now}
  end

  defp calculate_sentiment_trend(period_type, current_sentiment) do
    # Отримуємо попередній snapshot
    previous = get_previous_snapshot(period_type)

    if previous && previous.avg_sentiment != 0 do
      ((current_sentiment - previous.avg_sentiment) / abs(previous.avg_sentiment)) * 100
    else
      0.0
    end
  end

  defp get_previous_snapshot(period_type) do
    shift_days =
      case period_type do
        "daily" -> -1
        "weekly" -> -7
        "monthly" -> -30
      end

    target_date = DateTime.utc_now() |> DateTime.add(shift_days, :day)

    from(s in Snapshot,
      where: s.period_type == ^period_type,
      where: s.period_start <= ^target_date,
      order_by: [desc: s.period_start],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Повертає останній snapshot для певного типу періоду
  """
  def get_latest_snapshot(period_type) do
    from(s in Snapshot,
      where: s.period_type == ^period_type,
      order_by: [desc: s.period_start],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Повертає snapshots за період
  """
  def list_snapshots(period_type, opts \\ []) do
    limit = Keyword.get(opts, :limit, 30)

    from(s in Snapshot,
      where: s.period_type == ^period_type,
      order_by: [desc: s.period_start],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Повертає дані для графіка тренду тональності
  """
  def get_sentiment_trend_data(period_type, days_back \\ 30) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days_back, :day)

    from(s in Snapshot,
      where: s.period_type == ^period_type,
      where: s.period_start >= ^cutoff_date,
      order_by: [asc: s.period_start],
      select: %{
        date: s.period_start,
        avg_sentiment: s.avg_sentiment,
        positive: s.positive_count,
        neutral: s.neutral_count,
        negative: s.negative_count
      }
    )
    |> Repo.all()
  end

  @doc """
  Порівнює поточний період з попереднім
  """
  def compare_periods(current_snapshot_id) do
    current = Repo.get!(Snapshot, current_snapshot_id)

    shift_days =
      case current.period_type do
        "daily" -> -1
        "weekly" -> -7
        "monthly" -> -30
      end

    previous_start = DateTime.add(current.period_start, shift_days, :day)

    previous =
      from(s in Snapshot,
        where: s.period_type == ^current.period_type,
        where: s.period_start == ^previous_start
      )
      |> Repo.one()

    if previous do
      %{
        current: current,
        previous: previous,
        sentiment_change: current.avg_sentiment - previous.avg_sentiment,
        feedback_count_change: current.total_feedbacks - previous.total_feedbacks,
        sentiment_change_percent:
          if previous.avg_sentiment != 0 do
            (current.avg_sentiment - previous.avg_sentiment) / abs(previous.avg_sentiment) * 100
          else
            0
          end
      }
    else
      %{
        current: current,
        previous: nil,
        sentiment_change: 0,
        feedback_count_change: 0,
        sentiment_change_percent: 0
      }
    end
  end
end
