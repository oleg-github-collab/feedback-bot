defmodule FeedbackBot.Jobs.UpdateAnalyticsJob do
  @moduledoc """
  Oban job для оновлення analytics snapshots
  Викликається після успішного збереження feedback
  """
  use Oban.Worker, queue: :analytics, max_attempts: 3

  require Logger
  alias FeedbackBot.Analytics

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => "daily"}}) do
    Logger.info("Updating daily analytics snapshot...")

    case Analytics.create_snapshot("daily") do
      {:ok, snapshot} ->
        Logger.info("Daily snapshot created: #{inspect(snapshot.id)}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to create daily snapshot: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def perform(%Oban.Job{args: %{"type" => "weekly"}}) do
    Logger.info("Updating weekly analytics snapshot...")

    case Analytics.create_snapshot("weekly") do
      {:ok, snapshot} ->
        Logger.info("Weekly snapshot created: #{inspect(snapshot.id)}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to create weekly snapshot: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def perform(%Oban.Job{args: %{"type" => "monthly"}}) do
    Logger.info("Updating monthly analytics snapshot...")

    case Analytics.create_snapshot("monthly") do
      {:ok, snapshot} ->
        Logger.info("Monthly snapshot created: #{inspect(snapshot.id)}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to create monthly snapshot: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def perform(%Oban.Job{args: %{"type" => "all"}}) do
    Logger.info("Updating all analytics snapshots...")

    results = [
      Analytics.create_snapshot("daily"),
      Analytics.create_snapshot("weekly"),
      Analytics.create_snapshot("monthly")
    ]

    case Enum.all?(results, fn {status, _} -> status == :ok end) do
      true ->
        Logger.info("All snapshots created successfully")
        :ok

      false ->
        Logger.error("Some snapshots failed: #{inspect(results)}")
        {:error, "Failed to create some snapshots"}
    end
  end
end
