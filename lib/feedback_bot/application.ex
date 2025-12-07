defmodule FeedbackBot.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FeedbackBotWeb.Telemetry,
      FeedbackBot.Repo,
      {Oban, Application.fetch_env!(:feedback_bot, Oban)},
      FeedbackBot.Cache,
      {DNSCluster, query: Application.get_env(:feedback_bot, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FeedbackBot.PubSub},
      {Finch, name: FeedbackBot.Finch},
      FeedbackBot.Bot.State,
      FeedbackBotWeb.Endpoint,
      {FeedbackBot.Bot.Supervisor, []}
    ]

    opts = [strategy: :one_for_one, name: FeedbackBot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    FeedbackBotWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
