defmodule FeedbackBot.Repo do
  use Ecto.Repo,
    otp_app: :feedback_bot,
    adapter: Ecto.Adapters.Postgres
end
