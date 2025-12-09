defmodule FeedbackBot.Repo.Migrations.ClearFeedbacksForProduction do
  use Ecto.Migration

  def up do
    # Очищаємо всі feedbacks перед production запуском
    execute("DELETE FROM feedbacks")

    # Очищаємо також analytics snapshots щоб почати з чистого листа
    execute("DELETE FROM analytics_snapshots")

    IO.puts("✅ Очищено feedbacks та analytics_snapshots для production")
  end

  def down do
    # Неможливо відновити видалені дані
    IO.puts("⚠️ Rollback неможливий - дані були видалені")
  end
end
