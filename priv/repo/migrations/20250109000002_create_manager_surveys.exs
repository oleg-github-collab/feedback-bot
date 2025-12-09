defmodule FeedbackBot.Repo.Migrations.CreateManagerSurveys do
  use Ecto.Migration

  def change do
    create table(:manager_surveys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :bigint, null: false
      add :week_start, :utc_datetime, null: false
      add :q1_team_performance, :integer
      add :q2_communication, :integer
      add :q3_kpi_achievement, :integer
      add :q4_problem_solving, :integer
      add :q5_motivation, :integer
      add :q6_task_speed, :integer
      add :q7_collaboration, :integer
      add :q8_work_quality, :integer
      add :q9_improvement, :integer
      add :q10_overall, :integer
      add :average_score, :float
      add :completed_at, :utc_datetime

      timestamps()
    end

    create index(:manager_surveys, [:user_id])
    create index(:manager_surveys, [:week_start])
    create index(:manager_surveys, [:user_id, :week_start])
  end
end
