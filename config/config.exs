import Config

config :feedback_bot,
  ecto_repos: [FeedbackBot.Repo],
  generators: [timestamp_type: :utc_datetime]

config :feedback_bot, FeedbackBot.Repo,
  migration_primary_key: [type: :binary_id]

config :feedback_bot, FeedbackBotWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: FeedbackBotWeb.ErrorHTML, json: FeedbackBotWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: FeedbackBot.PubSub,
  live_view: [signing_salt: "changeme-generate-new-secret"]

config :esbuild,
  version: "0.17.11",
  feedback_bot: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.0",
  feedback_bot: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :ex_gram,
  token: System.get_env("TELEGRAM_BOT_TOKEN")

config :feedback_bot, :telegram,
  allowed_user_id: System.get_env("ALLOWED_USER_ID"),
  allowed_user_ids: System.get_env("ALLOWED_USER_IDS")

config :feedback_bot, :openai,
  api_key: System.get_env("OPENAI_API_KEY"),
  whisper_model: "whisper-1",
  gpt_model: "gpt-4o-mini"

config :feedback_bot, Oban,
  repo: FeedbackBot.Repo,
  queues: [audio_processing: 3, analytics: 1, notifications: 5],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 86400},
    {Oban.Plugins.Cron,
     crontab: [
       # Щодня о 9:00 UTC - follow-up негативних feedbacks (через тиждень)
       {"0 9 * * *", FeedbackBot.Jobs.NegativeFeedbackFollowupJob},
       # Щодня о 15:00 UTC - щоденне нагадування
       {"0 15 * * *", FeedbackBot.Jobs.DailyReminderJob},
       # Щоп'ятниці о 16:00 UTC - тижнева статистика
       {"0 16 * * 5", FeedbackBot.Jobs.WeeklyStatisticsJob}
     ]}
  ]

# Redis URL is configured in runtime.exs for prod, dev default below
config :feedback_bot, :dev_routes, true

import_config "#{config_env()}.exs"
