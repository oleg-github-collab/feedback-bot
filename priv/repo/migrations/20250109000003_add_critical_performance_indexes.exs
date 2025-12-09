defmodule FeedbackBot.Repo.Migrations.AddCriticalPerformanceIndexes do
  use Ecto.Migration

  def up do
    # Index для analytics snapshots - швидкий пошук останнього snapshot
    create index(:analytics_snapshots, [:period_type, :period_start],
      name: :analytics_snapshots_period_lookup_idx
    )

    # Index для processing_status - критичний для dashboard queries
    create index(:feedbacks, [:processing_status, :inserted_at],
      where: "processing_status = 'completed'"
    )

    # Index для urgency та impact scores - для risk register
    create index(:feedbacks, [:urgency_score],
      where: "urgency_score > 0.7"
    )

    create index(:feedbacks, [:impact_score],
      where: "impact_score > 0.7"
    )

    # Composite index для date range queries в аналітиці
    create index(:feedbacks, [:inserted_at, :processing_status, :sentiment_label])

    # Index для manager surveys - швидкий пошук по user_id та week_start
    # (already exists in create_manager_surveys migration)

    # Index для оптимізації heatmap queries
    create index(:feedbacks, [:employee_id, :inserted_at, :processing_status])
  end

  def down do
    drop index(:analytics_snapshots, [:period_type, :period_start],
      name: :analytics_snapshots_period_lookup_idx
    )
    drop index(:feedbacks, [:processing_status, :inserted_at])
    drop index(:feedbacks, [:urgency_score])
    drop index(:feedbacks, [:impact_score])
    drop index(:feedbacks, [:inserted_at, :processing_status, :sentiment_label])
    drop index(:feedbacks, [:employee_id, :inserted_at, :processing_status])
  end
end
