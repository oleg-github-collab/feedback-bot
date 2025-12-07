defmodule FeedbackBot.Feedbacks.Feedback do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "feedbacks" do
    belongs_to :employee, FeedbackBot.Employees.Employee

    field :audio_file_id, :string
    field :audio_file_path, :string
    field :duration_seconds, :integer
    field :transcription, :string

    field :summary, :string
    field :sentiment_score, :float
    field :sentiment_label, :string
    field :mood_intensity, :float
    field :key_points, {:array, :string}, default: []
    field :issues, {:array, :map}, default: []
    field :strengths, {:array, :string}, default: []
    field :improvement_areas, {:array, :string}, default: []

    # Advanced AI fields
    field :topics, {:array, :string}, default: []
    field :action_items, {:array, :map}, default: []
    field :urgency_score, :float, default: 0.0
    field :impact_score, :float, default: 0.0
    field :trend_direction, :string
    field :compared_to_previous, :map

    field :telegram_message_id, :integer
    field :telegram_user_id, :integer
    field :raw_ai_response, :map
    field :processing_status, :string, default: "pending"

    timestamps(type: :utc_datetime)
  end

  def changeset(feedback, attrs) do
    feedback
    |> cast(attrs, [
      :employee_id,
      :audio_file_id,
      :audio_file_path,
      :duration_seconds,
      :transcription,
      :summary,
      :sentiment_score,
      :sentiment_label,
      :mood_intensity,
      :key_points,
      :issues,
      :strengths,
      :improvement_areas,
      :topics,
      :action_items,
      :urgency_score,
      :impact_score,
      :trend_direction,
      :compared_to_previous,
      :telegram_message_id,
      :telegram_user_id,
      :raw_ai_response,
      :processing_status
    ])
    |> validate_required([:employee_id, :audio_file_id])
    |> validate_inclusion(:sentiment_label, ["positive", "neutral", "negative"])
    |> validate_inclusion(:processing_status, ["pending", "processing", "completed", "failed"])
    |> validate_inclusion(:trend_direction, ["improving", "declining", "stable", "unknown"], allow_nil: true)
    |> validate_number(:sentiment_score, greater_than_or_equal_to: -1.0, less_than_or_equal_to: 1.0)
    |> validate_number(:mood_intensity, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:urgency_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:impact_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> foreign_key_constraint(:employee_id)
  end
end
