import Config

config :feedback_bot, FeedbackBot.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "feedback_bot_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :feedback_bot, FeedbackBotWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "changeme-generate-new-secret-key-base-for-production",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:feedback_bot, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:feedback_bot, ~w(--watch)]}
  ]

config :feedback_bot, FeedbackBotWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/feedback_bot_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  enable_expensive_runtime_checks: true

# Redis URL for dev (optional, cache will be disabled if not set)
config :feedback_bot, :redis_url, System.get_env("REDIS_URL")
