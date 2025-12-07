defmodule FeedbackBot.Analytics.Snapshot do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "analytics_snapshots" do
    field :period_type, :string
    field :period_start, :utc_datetime
    field :period_end, :utc_datetime

    field :total_feedbacks, :integer, default: 0
    field :avg_sentiment, :float
    field :sentiment_trend, :float

    field :positive_count, :integer, default: 0
    field :neutral_count, :integer, default: 0
    field :negative_count, :integer, default: 0

    field :top_issues, {:array, :map}, default: []
    field :top_strengths, {:array, :map}, default: []
    field :emerging_issues, {:array, :map}, default: []
    field :resolved_issues, {:array, :map}, default: []

    field :employee_stats, {:array, :map}, default: []
    field :issue_correlations, {:array, :map}, default: []
    field :employee_correlations, {:array, :map}, default: []

    field :ai_insights, :string
    field :recommendations, {:array, :string}, default: []

    timestamps(type: :utc_datetime)
  end

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [
      :period_type,
      :period_start,
      :period_end,
      :total_feedbacks,
      :avg_sentiment,
      :sentiment_trend,
      :positive_count,
      :neutral_count,
      :negative_count,
      :top_issues,
      :top_strengths,
      :emerging_issues,
      :resolved_issues,
      :employee_stats,
      :issue_correlations,
      :employee_correlations,
      :ai_insights,
      :recommendations
    ])
    |> validate_required([:period_type, :period_start, :period_end])
    |> validate_inclusion(:period_type, ["daily", "weekly", "monthly"])
    |> unique_constraint([:period_type, :period_start])
  end
end
