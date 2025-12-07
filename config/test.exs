import Config

config :feedback_bot, FeedbackBot.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "feedback_bot_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :feedback_bot, FeedbackBotWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test-secret-key-base",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :swoosh, :test_mode, true
