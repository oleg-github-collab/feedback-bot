defmodule FeedbackBot.Repo.Migrations.AddAdvancedAiFields do
  use Ecto.Migration

  def change do
    alter table(:feedbacks) do
      # Розширений AI аналіз
      add :topics, {:array, :string}, default: []
      add :action_items, {:array, :map}, default: []
      add :urgency_score, :float, default: 0.0
      add :impact_score, :float, default: 0.0
      add :mood_intensity, :float, default: 0.0

      # Для трендів та порівнянь
      add :compared_to_previous, :map
      add :trend_direction, :string  # improving, declining, stable
    end

    # Indices для нових полів
    create index(:feedbacks, [:urgency_score])
    create index(:feedbacks, [:impact_score])
    create index(:feedbacks, [:trend_direction])
  end
end
