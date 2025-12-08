import Config

if config_env() == :prod do
  # Використовуємо окремі змінні замість DATABASE_URL для більшої надійності
  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :feedback_bot, FeedbackBot.Repo,
    hostname: System.get_env("PGHOST") || "postgres.railway.internal",
    port: String.to_integer(System.get_env("PGPORT") || "5432"),
    database: System.get_env("PGDATABASE") || "railway",
    username: System.get_env("PGUSER") || "postgres",
    password: System.get_env("PGPASSWORD") || raise("PGPASSWORD is required"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6,
    # Disable SSL for Railway internal network
    ssl: false,
    show_sensitive_data_on_connection_error: true,
    queue_target: 5000,
    queue_interval: 1000

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :feedback_bot, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :feedback_bot, FeedbackBotWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  config :ex_gram,
    token: System.get_env("TELEGRAM_BOT_TOKEN") ||
      raise """
      environment variable TELEGRAM_BOT_TOKEN is missing.
      """

  # Валідація: хоча б один з ALLOWED_USER_ID або ALLOWED_USER_IDS повинен бути встановлений
  unless System.get_env("ALLOWED_USER_ID") || System.get_env("ALLOWED_USER_IDS") do
    raise """
    environment variable ALLOWED_USER_ID or ALLOWED_USER_IDS is missing.
    Set at least one of them.
    """
  end

  config :feedback_bot, :telegram,
    allowed_user_id: System.get_env("ALLOWED_USER_ID"),
    allowed_user_ids: System.get_env("ALLOWED_USER_IDS")

  config :feedback_bot, :openai,
    api_key: System.get_env("OPENAI_API_KEY") ||
      raise """
      environment variable OPENAI_API_KEY is missing.
      """

  # Redis URL (опціонально, якщо не встановлено - кешування буде вимкнено)
  config :feedback_bot, :redis_url,
    System.get_env("REDIS_URL")
end
