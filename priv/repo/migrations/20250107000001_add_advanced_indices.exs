defmodule FeedbackBot.Repo.Migrations.AddAdvancedIndices do
  use Ecto.Migration

  def up do
    # Full-text search index для транскрипцій (PostgreSQL)
    execute """
    CREATE INDEX feedbacks_transcription_search_idx
    ON feedbacks
    USING gin(to_tsvector('english', coalesce(transcription, '')))
    """

    # Composite index для фільтрації по даті та sentiment
    create index(:feedbacks, [:inserted_at, :sentiment_label])
    create index(:feedbacks, [:employee_id, :sentiment_score])

    # Index для швидкого пошуку по датах (DESC)
    execute "CREATE INDEX feedbacks_inserted_at_desc_idx ON feedbacks (inserted_at DESC)"

    # Index для аналітики
    create index(:feedbacks, [:employee_id, :inserted_at, :sentiment_score])
  end

  def down do
    execute "DROP INDEX IF EXISTS feedbacks_transcription_search_idx"
    drop index(:feedbacks, [:inserted_at, :sentiment_label])
    drop index(:feedbacks, [:employee_id, :sentiment_score])
    execute "DROP INDEX IF EXISTS feedbacks_inserted_at_desc_idx"
    drop index(:feedbacks, [:employee_id, :inserted_at, :sentiment_score])
  end
end
