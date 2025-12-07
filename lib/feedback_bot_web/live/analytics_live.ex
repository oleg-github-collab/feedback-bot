defmodule FeedbackBotWeb.AnalyticsLive do
  use FeedbackBotWeb, :live_view

  alias FeedbackBot.Analytics

  @impl true
  def mount(_params, _session, socket) do
    daily_snapshots = Analytics.list_snapshots("daily", limit: 30)
    weekly_snapshots = Analytics.list_snapshots("weekly", limit: 12)
    monthly_snapshots = Analytics.list_snapshots("monthly", limit: 6)

    socket =
      socket
      |> assign(:page_title, "Аналітика")
      |> assign(:daily_snapshots, daily_snapshots)
      |> assign(:weekly_snapshots, weekly_snapshots)
      |> assign(:monthly_snapshots, monthly_snapshots)
      |> assign(:selected_period, "weekly")

    {:ok, socket}
  end

  @impl true
  def handle_event("select_period", %{"period" => period}, socket) do
    {:noreply, assign(socket, :selected_period, period)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-50">
      <header class="border-b-4 border-black bg-white">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <.link navigate="/" class="text-sm font-bold hover:underline mb-2 inline-block">
            ← Назад
          </.link>
          <h1 class="text-5xl font-black uppercase tracking-tight">
            Аналітика
          </h1>
        </div>
      </header>

      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <!-- Period Selector -->
        <div class="flex gap-3 mb-8">
          <button
            phx-click="select_period"
            phx-value-period="daily"
            class={[
              "neo-brutal-btn-sm",
              if(@selected_period == "daily", do: "bg-blue-300", else: "bg-gray-200")
            ]}
          >
            Щоденна
          </button>
          <button
            phx-click="select_period"
            phx-value-period="weekly"
            class={[
              "neo-brutal-btn-sm",
              if(@selected_period == "weekly", do: "bg-blue-300", else: "bg-gray-200")
            ]}
          >
            Тижнева
          </button>
          <button
            phx-click="select_period"
            phx-value-period="monthly"
            class={[
              "neo-brutal-btn-sm",
              if(@selected_period == "monthly", do: "bg-blue-300", else: "bg-gray-200")
            ]}
          >
            Місячна
          </button>
        </div>

        <!-- Snapshots -->
        <div class="space-y-6">
          <%= for snapshot <- get_snapshots(@selected_period, assigns) do %>
            <div class="neo-brutal-card">
              <div class="flex justify-between items-start mb-4">
                <div>
                  <h2 class="text-2xl font-black">
                    <%= format_period(@selected_period, snapshot.period_start) %>
                  </h2>
                  <p class="text-sm text-gray-600">
                    <%= snapshot.total_feedbacks %> фідбеків
                  </p>
                </div>
                <div class="text-right">
                  <p class="text-sm font-bold">Тональність</p>
                  <p class={[
                    "text-3xl font-black",
                    sentiment_color(snapshot.avg_sentiment)
                  ]}>
                    <%= Float.round(snapshot.avg_sentiment, 2) %>
                  </p>
                  <%= if snapshot.sentiment_trend != 0 do %>
                    <p class={[
                      "text-sm font-bold",
                      if(snapshot.sentiment_trend > 0, do: "text-green-600", else: "text-red-600")
                    ]}>
                      <%= if snapshot.sentiment_trend > 0, do: "↑", else: "↓" %>
                      <%= Float.round(abs(snapshot.sentiment_trend), 2) %>
                    </p>
                  <% end %>
                </div>
              </div>

              <div class="grid grid-cols-3 gap-4 mb-4">
                <div class="p-3 bg-green-100 border-2 border-black">
                  <p class="text-xs font-bold">Позитивні</p>
                  <p class="text-2xl font-black"><%= snapshot.positive_count %></p>
                </div>
                <div class="p-3 bg-gray-100 border-2 border-black">
                  <p class="text-xs font-bold">Нейтральні</p>
                  <p class="text-2xl font-black"><%= snapshot.neutral_count %></p>
                </div>
                <div class="p-3 bg-red-100 border-2 border-black">
                  <p class="text-xs font-bold">Негативні</p>
                  <p class="text-2xl font-black"><%= snapshot.negative_count %></p>
                </div>
              </div>

              <%= if snapshot.ai_insights do %>
                <div class="mt-4 p-4 bg-yellow-50 border-2 border-black">
                  <h3 class="font-black text-sm uppercase mb-2">🤖 AI Інсайти</h3>
                  <p class="text-sm whitespace-pre-line"><%= snapshot.ai_insights %></p>
                </div>
              <% end %>

              <%= if length(snapshot.top_issues) > 0 do %>
                <div class="mt-4">
                  <h3 class="font-black text-sm uppercase mb-2">Топ Проблеми</h3>
                  <div class="space-y-1">
                    <%= for issue <- Enum.take(snapshot.top_issues, 5) do %>
                      <div class="flex justify-between text-sm">
                        <span><%= Map.get(issue, "description") %></span>
                        <span class="font-black"><%= Map.get(issue, "count") %>×</span>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </main>
    </div>
    """
  end

  defp get_snapshots("daily", assigns), do: assigns.daily_snapshots
  defp get_snapshots("weekly", assigns), do: assigns.weekly_snapshots
  defp get_snapshots("monthly", assigns), do: assigns.monthly_snapshots

  defp format_period("daily", date), do: Calendar.strftime(date, "%d.%m.%Y")
  defp format_period("weekly", date), do: "Тиждень #{Calendar.strftime(date, "%V, %Y")}"
  defp format_period("monthly", date), do: Calendar.strftime(date, "%B %Y")

  defp sentiment_color(sentiment) when sentiment > 0.3, do: "text-green-600"
  defp sentiment_color(sentiment) when sentiment < -0.3, do: "text-red-600"
  defp sentiment_color(_), do: "text-gray-600"
end
