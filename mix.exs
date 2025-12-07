defmodule FeedbackBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :feedback_bot,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {FeedbackBot.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix & Web
      {:phoenix, "~> 1.7.14"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:phoenix_live_view, "~> 0.20.17"},
      {:phoenix_live_dashboard, "~> 0.8.4"},

      # Database
      {:ecto_sql, "~> 3.11"},
      {:postgrex, ">= 0.0.0"},

      # Telegram Bot
      {:ex_gram, "~> 0.52"},
      {:tesla, "~> 1.9"},
      {:hackney, "~> 1.20"},

      # HTTP & API
      {:httpoison, "~> 2.2"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5"},

      # Authentication & Security
      {:bcrypt_elixir, "~> 3.1"},

      # Background Jobs & Caching
      {:oban, "~> 2.18"},
      {:redix, "~> 1.5"},
      {:castore, "~> 1.0"},

      # File Upload & Storage
      {:waffle, "~> 1.1"},
      {:waffle_ecto, "~> 0.0"},

      # Utilities
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.1"},
      {:gettext, "~> 0.24"},
      {:swoosh, "~> 1.16"},
      {:finch, "~> 0.18"},
      {:timex, "~> 3.7"},

      # Frontend
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},

      # Development & Testing
      {:floki, ">= 0.36.0", only: :test},
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind feedback_bot", "esbuild feedback_bot"],
      "assets.deploy": [
        "tailwind feedback_bot --minify",
        "esbuild feedback_bot --minify",
        "phx.digest"
      ]
    ]
  end
end
