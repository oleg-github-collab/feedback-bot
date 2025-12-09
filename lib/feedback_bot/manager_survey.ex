defmodule FeedbackBot.ManagerSurvey do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "manager_surveys" do
    field :user_id, :integer
    field :week_start, :utc_datetime
    field :q1_team_performance, :integer
    field :q2_communication, :integer
    field :q3_kpi_achievement, :integer
    field :q4_problem_solving, :integer
    field :q5_motivation, :integer
    field :q6_task_speed, :integer
    field :q7_collaboration, :integer
    field :q8_work_quality, :integer
    field :q9_improvement, :integer
    field :q10_overall, :integer
    field :average_score, :float
    field :completed_at, :utc_datetime

    timestamps()
  end

  def changeset(survey, attrs) do
    survey
    |> cast(attrs, [
      :user_id,
      :week_start,
      :q1_team_performance,
      :q2_communication,
      :q3_kpi_achievement,
      :q4_problem_solving,
      :q5_motivation,
      :q6_task_speed,
      :q7_collaboration,
      :q8_work_quality,
      :q9_improvement,
      :q10_overall,
      :average_score,
      :completed_at
    ])
    |> validate_required([:user_id, :week_start])
    |> validate_number(:q1_team_performance, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_number(:q2_communication, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_number(:q3_kpi_achievement, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_number(:q4_problem_solving, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_number(:q5_motivation, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_number(:q6_task_speed, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_number(:q7_collaboration, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_number(:q8_work_quality, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_number(:q9_improvement, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_number(:q10_overall, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
  end

  def calculate_average(survey) do
    scores = [
      survey.q1_team_performance,
      survey.q2_communication,
      survey.q3_kpi_achievement,
      survey.q4_problem_solving,
      survey.q5_motivation,
      survey.q6_task_speed,
      survey.q7_collaboration,
      survey.q8_work_quality,
      survey.q9_improvement,
      survey.q10_overall
    ]

    valid_scores = Enum.reject(scores, &is_nil/1)

    if length(valid_scores) > 0 do
      Enum.sum(valid_scores) / length(valid_scores)
    else
      0.0
    end
  end
end
