defmodule FeedbackBot.Analytics do
  @moduledoc """
  Context для роботи з аналітикою
  """

  import Ecto.Query
  alias FeedbackBot.Repo
  alias FeedbackBot.Analytics.Snapshot

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
