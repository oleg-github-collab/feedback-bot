defmodule FeedbackBot.Repo.Migrations.CreateAnalytics do
  use Ecto.Migration

  def change do
    create table(:analytics_snapshots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :period_type, :string, null: false  # daily, weekly, monthly
      add :period_start, :utc_datetime, null: false
      add :period_end, :utc_datetime, null: false

      # Загальна статистика
      add :total_feedbacks, :integer, default: 0
      add :avg_sentiment, :float
      add :sentiment_trend, :float  # зміна порівняно з попереднім періодом

      # Розподіл тональності
      add :positive_count, :integer, default: 0
      add :neutral_count, :integer, default: 0
      add :negative_count, :integer, default: 0

      # Топ проблем та досягнень
      add :top_issues, {:array, :map}, default: []
      add :top_strengths, {:array, :map}, default: []
      add :emerging_issues, {:array, :map}, default: []
      add :resolved_issues, {:array, :map}, default: []

      # Статистика по співробітниках
      add :employee_stats, {:array, :map}, default: []

      # Кореляції та звʼязки
      add :issue_correlations, {:array, :map}, default: []
      add :employee_correlations, {:array, :map}, default: []

      # AI інсайти
      add :ai_insights, :text
      add :recommendations, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    create index(:analytics_snapshots, [:period_type])
    create index(:analytics_snapshots, [:period_start])
    create unique_index(:analytics_snapshots, [:period_type, :period_start])
  end
end
