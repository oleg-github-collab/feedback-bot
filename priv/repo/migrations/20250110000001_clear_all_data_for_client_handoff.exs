defmodule FeedbackBot.Repo.Migrations.ClearAllDataForClientHandoff do
  use Ecto.Migration

  def up do
    # Очищаємо всі feedbacks
    execute("DELETE FROM feedbacks")

    # Очищаємо analytics snapshots
    execute("DELETE FROM analytics_snapshots")

    # Очищаємо опитування менеджерів
    execute("DELETE FROM manager_surveys")

    # Очищаємо Oban jobs
    execute("DELETE FROM oban_jobs")

    IO.puts("✅ База очищена для передачі клієнту. Співробітники збережені.")
  end

  def down do
    IO.puts("⚠️ Rollback неможливий - дані були видалені")
  end
end
