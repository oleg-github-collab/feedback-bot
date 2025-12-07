import Config

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :feedback_bot, FeedbackBot.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

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

  config :feedback_bot, :telegram,
    allowed_user_id: System.get_env("ALLOWED_USER_ID") ||
      raise """
      environment variable ALLOWED_USER_ID is missing.
      """

  config :feedback_bot, :openai,
    api_key: System.get_env("OPENAI_API_KEY") ||
      raise """
      environment variable OPENAI_API_KEY is missing.
      """
end
