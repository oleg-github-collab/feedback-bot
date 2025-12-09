defmodule Mix.Tasks.InitSnapshots do
  @moduledoc """
  Mix task для ініціалізації analytics snapshots.

  Використання:
    mix init_snapshots

  Або на Railway:
    railway run --service feedback-bot mix init_snapshots
  """
  use Mix.Task

  @shortdoc "Initialize analytics snapshots for dashboard counters"

  @impl Mix.Task
  def run(_args) do
    # Start application dependencies
    Mix.Task.run("app.start")

    IO.puts("""
    ========================================
      Analytics Snapshots Initialization
    ========================================
    """)

    # Check feedbacks count
    feedbacks_count = count_feedbacks()
    completed_count = count_completed_feedbacks()

    IO.puts("📊 Database Statistics:")
    IO.puts("   Total feedbacks: #{feedbacks_count}")
    IO.puts("   Completed feedbacks: #{completed_count}")

    if completed_count == 0 do
      IO.puts("\n⚠️  WARNING: No completed feedbacks found!")
      IO.puts("   Snapshots will be created with zero values.")
      IO.puts("   Please process some feedbacks first via Telegram bot.\n")
    end

    IO.puts("\n🔄 Creating snapshots...\n")

    # Create snapshots
    results = %{
      daily: create_snapshot("daily"),
      weekly: create_snapshot("weekly"),
      monthly: create_snapshot("monthly")
    }

    IO.puts("\n✅ Snapshot Creation Results:\n")

    Enum.each(results, fn {type, result} ->
      case result do
        {:ok, snapshot} ->
          IO.puts("   ✓ #{String.upcase(to_string(type))}: #{snapshot.total_feedbacks} feedbacks, sentiment: #{format_float(snapshot.avg_sentiment)}")

        {:error, changeset} ->
          IO.puts("   ✗ #{String.upcase(to_string(type))}: ERROR")
          IO.puts("     #{inspect(changeset.errors)}")
      end
    end)

    success_count = results |> Enum.count(fn {_k, v} -> match?({:ok, _}, v) end)

    IO.puts("\n" <> String.duplicate("=", 40))

    if success_count == 3 do
      IO.puts("✅ SUCCESS! All snapshots created successfully!")
      IO.puts("\nNext steps:")
      IO.puts("1. Open dashboard in browser")
      IO.puts("2. Refresh the page (Cmd+R / Ctrl+R)")
      IO.puts("3. Counters should now display correct numbers")
      IO.puts("4. Record new feedback via bot to test real-time updates")
    else
      IO.puts("⚠️  WARNING: #{3 - success_count} snapshot(s) failed!")
      IO.puts("Please check the errors above and try again.")
      System.halt(1)
    end

    IO.puts(String.duplicate("=", 40) <> "\n")
  end

  defp count_feedbacks do
    FeedbackBot.Repo.aggregate(FeedbackBot.Feedbacks.Feedback, :count, :id)
  end

  defp count_completed_feedbacks do
    import Ecto.Query

    FeedbackBot.Repo.one(
      from(f in FeedbackBot.Feedbacks.Feedback,
        where: f.processing_status == "completed",
        select: count(f.id)
      )
    )
  end

  defp create_snapshot(type) do
    FeedbackBot.Analytics.create_snapshot(type)
  end

  defp format_float(nil), do: "0.00"
  defp format_float(value) when is_float(value), do: Float.round(value, 2)
  defp format_float(value), do: value
end
