defmodule FeedbackBot.Repo.Migrations.CreateFeedbacks do
  use Ecto.Migration

  def change do
    create table(:feedbacks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :employee_id, references(:employees, type: :binary_id, on_delete: :restrict), null: false

      # Аудіо та транскрипція
      add :audio_file_id, :string, null: false
      add :audio_file_path, :string
      add :duration_seconds, :integer
      add :transcription, :text

      # Аналіз AI
      add :summary, :text
      add :sentiment_score, :float  # -1.0 до 1.0
      add :sentiment_label, :string  # positive, neutral, negative
      add :key_points, {:array, :string}, default: []
      add :issues, {:array, :map}, default: []
      add :strengths, {:array, :string}, default: []
      add :improvement_areas, {:array, :string}, default: []

      # Метадані
      add :telegram_message_id, :bigint
      add :telegram_user_id, :bigint
      add :raw_ai_response, :map
      add :processing_status, :string, default: "pending"
      # pending, processing, completed, failed

      timestamps(type: :utc_datetime)
    end

    create index(:feedbacks, [:employee_id])
    create index(:feedbacks, [:sentiment_score])
    create index(:feedbacks, [:sentiment_label])
    create index(:feedbacks, [:processing_status])
    create index(:feedbacks, [:inserted_at])
    create index(:feedbacks, [:employee_id, :inserted_at])
  end
end
