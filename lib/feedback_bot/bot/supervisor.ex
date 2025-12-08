defmodule FeedbackBot.Bot.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    token = fetch_token()

    # Встановлюємо Menu Button для веб-апп
    # DISABLED: ExGram 0.57.0 doesn't support this format
    # Task.start(fn ->
    #   Process.sleep(2000)
    #   FeedbackBot.Bot.Handler.setup_menu_button()
    # end)

    children = [
      {FeedbackBot.Bot.Handler, [method: :polling, token: token]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp fetch_token do
    case Application.fetch_env(:ex_gram, :token) do
      {:ok, token} when is_binary(token) and byte_size(token) > 0 ->
        token

      _ ->
        raise """
        TELEGRAM_BOT_TOKEN is missing or empty.
        Set TELEGRAM_BOT_TOKEN env var so the bot can start.
        """
    end
  end
end
