defmodule FeedbackBot.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Базові сервіси
    base_children = [
      FeedbackBotWeb.Telemetry,
      FeedbackBot.Repo,
      {Oban, Application.fetch_env!(:feedback_bot, Oban)},
      {Phoenix.PubSub, name: FeedbackBot.PubSub},
      {Finch, name: FeedbackBot.Finch},
      FeedbackBot.Bot.State,
      FeedbackBotWeb.Endpoint,
      {Registry, keys: :unique, name: Registry.ExGram},
      {FeedbackBot.Bot.Supervisor, []}
    ]

    # Додаємо Cache тільки якщо Redis налаштовано
    children = if Application.get_env(:feedback_bot, :redis_url) do
      List.insert_at(base_children, 3, FeedbackBot.Cache)
    else
      base_children
    end

    opts = [strategy: :one_for_one, name: FeedbackBot.Supervisor]

    # Start the supervisor
    result = Supervisor.start_link(children, opts)

    # Initialize analytics snapshots after successful startup
    Task.start(fn ->
      # Wait for Repo to be ready
      Process.sleep(2000)

      require Logger
      Logger.info("🔄 Initializing analytics snapshots...")

      try do
        FeedbackBot.Analytics.initialize_all_snapshots()
        Logger.info("✅ Analytics snapshots initialized successfully")
      rescue
        e ->
          Logger.error("❌ Failed to initialize analytics snapshots: #{inspect(e)}")
      end
    end)

    result
  end

  @impl true
  def config_change(changed, _new, removed) do
    FeedbackBotWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
