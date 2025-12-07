import Config

config :feedback_bot, FeedbackBot.Repo,
  ssl: true,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :feedback_bot, FeedbackBotWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

config :logger, level: :info

config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: FeedbackBot.Finch
