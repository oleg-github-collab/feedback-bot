# Скрипт для ініціалізації analytics snapshots
# Запуск: mix run priv/scripts/initialize_snapshots.exs
# Або на Railway: railway run --service feedback-bot mix run priv/scripts/initialize_snapshots.exs

require Logger

IO.puts """
========================================
  Analytics Snapshots Initialization
========================================
"""

# Перевіряємо кількість feedbacks
feedbacks_count = FeedbackBot.Repo.aggregate(FeedbackBot.Feedbacks.Feedback, :count, :id)
IO.puts "Total feedbacks in database: #{feedbacks_count}"

completed_count = FeedbackBot.Repo.one(
  from f in FeedbackBot.Feedbacks.Feedback,
  where: f.processing_status == "completed",
  select: count(f.id)
)
IO.puts "Completed feedbacks: #{completed_count}"

if completed_count == 0 do
  IO.puts "\n⚠️  WARNING: No completed feedbacks found!"
  IO.puts "Snapshots will be created with zero values."
  IO.puts "Please process some feedbacks first.\n"
end

IO.puts "\nCreating snapshots...\n"

# Створюємо daily snapshot
IO.write "Creating daily snapshot... "
case FeedbackBot.Analytics.create_snapshot("daily") do
  {:ok, snapshot} ->
    IO.puts "✅ OK (#{snapshot.total_feedbacks} feedbacks, sentiment: #{Float.round(snapshot.avg_sentiment || 0.0, 2)})"
  {:error, changeset} ->
    IO.puts "❌ ERROR: #{inspect(changeset.errors)}"
end

# Створюємо weekly snapshot
IO.write "Creating weekly snapshot... "
case FeedbackBot.Analytics.create_snapshot("weekly") do
  {:ok, snapshot} ->
    IO.puts "✅ OK (#{snapshot.total_feedbacks} feedbacks, sentiment: #{Float.round(snapshot.avg_sentiment || 0.0, 2)})"
  {:error, changeset} ->
    IO.puts "❌ ERROR: #{inspect(changeset.errors)}"
end

# Створюємо monthly snapshot
IO.write "Creating monthly snapshot... "
case FeedbackBot.Analytics.create_snapshot("monthly") do
  {:ok, snapshot} ->
    IO.puts "✅ OK (#{snapshot.total_feedbacks} feedbacks, sentiment: #{Float.round(snapshot.avg_sentiment || 0.0, 2)})"
  {:error, changeset} ->
    IO.puts "❌ ERROR: #{inspect(changeset.errors)}"
end

IO.puts "\n✅ Analytics snapshots initialized successfully!"
IO.puts "\nYou can now:"
IO.puts "1. Open the dashboard to see the counters"
IO.puts "2. Check /analytics page for detailed charts"
IO.puts "3. Record new feedbacks to see real-time updates"
