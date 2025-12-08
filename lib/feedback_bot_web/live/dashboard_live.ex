defmodule FeedbackBotWeb.DashboardLive do
  use FeedbackBotWeb, :live_view

  alias FeedbackBot.{Employees, Feedbacks, Analytics}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Отримуємо статистику
      latest_daily = Analytics.get_latest_snapshot("daily")
      latest_weekly = Analytics.get_latest_snapshot("weekly")
      latest_monthly = Analytics.get_latest_snapshot("monthly")

      recent_feedbacks = Feedbacks.list_recent_feedbacks(5)
      employees = Employees.list_active_employees()

      # Тренд за останні 30 днів
      sentiment_trend = Analytics.get_sentiment_trend_data("daily", 30)

      socket =
        socket
        |> assign(:page_title, "Dashboard")
        |> assign(:daily_snapshot, latest_daily)
        |> assign(:weekly_snapshot, latest_weekly)
        |> assign(:monthly_snapshot, latest_monthly)
        |> assign(:recent_feedbacks, recent_feedbacks)
        |> assign(:employees, employees)
        |> assign(:sentiment_trend, sentiment_trend)

      {:ok, socket}
    else
      {:ok,
       socket
       |> assign(:page_title, "Dashboard")
       |> assign(:daily_snapshot, nil)
       |> assign(:weekly_snapshot, nil)
       |> assign(:monthly_snapshot, nil)
       |> assign(:recent_feedbacks, [])
       |> assign(:employees, [])
       |> assign(:sentiment_trend, [])}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-violet-50 via-purple-50 to-pink-50">
      <!-- Header -->
      <header class="bg-white shadow-lg border-b-4 border-violet-600">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-5xl font-black bg-gradient-to-r from-violet-600 to-purple-600 bg-clip-text text-transparent">
                📊 FeedbackBot
              </h1>
              <p class="mt-2 text-lg font-semibold text-gray-600">
                AI-powered Analytics & Insights
              </p>
            </div>
            <nav class="hidden md:flex gap-4">
              <.link
                navigate={~p"/"}
                class="px-6 py-3 rounded-xl font-bold bg-violet-600 text-white hover:bg-violet-700 transition-all shadow-lg hover:shadow-xl transform hover:-translate-y-0.5"
              >
                🏠 Dashboard
              </.link>
              <.link
                navigate={~p"/record"}
                class="px-6 py-3 rounded-xl font-bold bg-gradient-to-r from-pink-500 to-rose-500 text-white hover:from-pink-600 hover:to-rose-600 transition-all shadow-lg hover:shadow-xl transform hover:-translate-y-0.5"
              >
                🎤 Записати
              </.link>
              <.link
                navigate={~p"/employees"}
                class="px-6 py-3 rounded-xl font-bold bg-white text-violet-600 border-2 border-violet-600 hover:bg-violet-50 transition-all"
              >
                👥 Команда
              </.link>
              <.link
                navigate={~p"/analytics"}
                class="px-6 py-3 rounded-xl font-bold bg-white text-violet-600 border-2 border-violet-600 hover:bg-violet-50 transition-all"
              >
                📈 Аналітика
              </.link>
            </nav>
          </div>
        </div>
      </header>

      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <!-- Quick Stats -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <.stat_card
            title="Сьогодні"
            value={if @daily_snapshot, do: @daily_snapshot.total_feedbacks, else: 0}
            sentiment={if @daily_snapshot, do: @daily_snapshot.avg_sentiment, else: 0}
            trend={if @daily_snapshot, do: @daily_snapshot.sentiment_trend, else: 0}
          />
          <.stat_card
            title="Цього тижня"
            value={if @weekly_snapshot, do: @weekly_snapshot.total_feedbacks, else: 0}
            sentiment={if @weekly_snapshot, do: @weekly_snapshot.avg_sentiment, else: 0}
            trend={if @weekly_snapshot, do: @weekly_snapshot.sentiment_trend, else: 0}
          />
          <.stat_card
            title="Цього місяця"
            value={if @monthly_snapshot, do: @monthly_snapshot.total_feedbacks, else: 0}
            sentiment={if @monthly_snapshot, do: @monthly_snapshot.avg_sentiment, else: 0}
            trend={if @monthly_snapshot, do: @monthly_snapshot.sentiment_trend, else: 0}
          />
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <!-- Sentiment Trend Chart -->
          <div class="neo-brutal-card">
            <h2 class="text-2xl font-black uppercase mb-4">Тренд Тональності</h2>
            <div class="h-64">
              <.sentiment_chart data={@sentiment_trend} />
            </div>
          </div>

          <!-- Recent Feedbacks -->
          <div class="neo-brutal-card">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-2xl font-black uppercase">Останні Фідбеки</h2>
              <.link navigate="/feedbacks" class="neo-brutal-btn-sm">
                Всі →
              </.link>
            </div>
            <div class="space-y-3">
              <%= for feedback <- @recent_feedbacks do %>
                <div class="border-2 border-black p-3 bg-white">
                  <div class="flex justify-between items-start">
                    <div class="flex-1">
                      <p class="font-bold text-sm">
                        <%= feedback.employee.name %>
                      </p>
                      <p class="text-xs text-gray-600 mt-1 line-clamp-2">
                        <%= feedback.summary %>
                      </p>
                    </div>
                    <.sentiment_badge sentiment={feedback.sentiment_label} />
                  </div>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Top Issues -->
          <%= if @weekly_snapshot && length(@weekly_snapshot.top_issues) > 0 do %>
            <div class="neo-brutal-card">
              <h2 class="text-2xl font-black uppercase mb-4">Топ Проблем</h2>
              <div class="space-y-2">
                <%= for {issue, idx} <- Enum.with_index(@weekly_snapshot.top_issues, 1) do %>
                  <div class="flex items-start gap-3">
                    <span class="flex-shrink-0 w-6 h-6 bg-black text-white font-bold text-sm flex items-center justify-center">
                      <%= idx %>
                    </span>
                    <div class="flex-1">
                      <p class="font-medium text-sm">
                        <%= Map.get(issue, "description") %>
                      </p>
                      <p class="text-xs text-gray-600">
                        Згадувань: <%= Map.get(issue, "count") %> | Важливість: <%= Map.get(
                          issue,
                          "avg_severity"
                        ) %>
                      </p>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <!-- Employee Overview -->
          <div class="neo-brutal-card">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-2xl font-black uppercase">Співробітники</h2>
              <.link navigate="/employees" class="neo-brutal-btn-sm">
                Управління →
              </.link>
            </div>
            <div class="space-y-2">
              <%= for employee <- @employees do %>
                <.link
                  navigate={"/employees/#{employee.id}"}
                  class="block border-2 border-black p-3 bg-white hover:bg-yellow-200 transition-colors"
                >
                  <p class="font-bold"><%= employee.name %></p>
                  <%= if employee.email do %>
                    <p class="text-xs text-gray-600"><%= employee.email %></p>
                  <% end %>
                </.link>
              <% end %>
            </div>
          </div>
        </div>

        <!-- AI Insights -->
        <%= if @weekly_snapshot && @weekly_snapshot.ai_insights do %>
          <div class="mt-8 neo-brutal-card bg-yellow-100">
            <h2 class="text-2xl font-black uppercase mb-4 flex items-center gap-2">
              <span>🤖</span>
              <span>AI Інсайти</span>
            </h2>
            <p class="text-sm whitespace-pre-line mb-4">
              <%= @weekly_snapshot.ai_insights %>
            </p>

            <%= if length(@weekly_snapshot.recommendations) > 0 do %>
              <div class="mt-4 border-t-2 border-black pt-4">
                <h3 class="font-black text-lg mb-2">Рекомендації:</h3>
                <ul class="space-y-1">
                  <%= for rec <- @weekly_snapshot.recommendations do %>
                    <li class="flex items-start gap-2">
                      <span class="text-yellow-600 font-black">▸</span>
                      <span class="text-sm"><%= rec %></span>
                    </li>
                  <% end %>
                </ul>
              </div>
            <% end %>
          </div>
        <% end %>
      </main>
    </div>
    """
  end

  # Components
  attr :title, :string, required: true
  attr :value, :integer, required: true
  attr :sentiment, :float, required: true
  attr :trend, :float, required: true

  defp stat_card(assigns) do
    ~H"""
    <div class="relative overflow-hidden rounded-2xl bg-white shadow-2xl border-4 border-violet-200 hover:border-violet-400 transition-all duration-300 transform hover:-translate-y-2 hover:shadow-violet-200">
      <div class="absolute top-0 right-0 w-32 h-32 bg-gradient-to-br from-violet-400 to-purple-400 opacity-10 rounded-full -mr-16 -mt-16">
      </div>
      <div class="p-6 relative">
        <h3 class="text-sm font-bold uppercase text-gray-500 tracking-wider"><%= @title %></h3>
        <p class="text-5xl font-black mt-3 bg-gradient-to-r from-violet-600 to-purple-600 bg-clip-text text-transparent">
          <%= @value %>
        </p>
        <div class="mt-4 space-y-2">
          <div class="flex items-center justify-between">
            <span class="text-xs font-semibold text-gray-600">Тональність:</span>
            <span class={[
              "px-3 py-1 rounded-full text-xs font-bold",
              sentiment_badge_color(@sentiment)
            ]}>
              <%= if is_float(@sentiment), do: Float.round(@sentiment, 2), else: @sentiment %>
            </span>
          </div>
          <%= if @trend != 0 do %>
            <div class="flex items-center justify-between">
              <span class="text-xs font-semibold text-gray-600">Тренд:</span>
              <span class={[
                "px-3 py-1 rounded-full text-xs font-bold",
                if(@trend > 0, do: "bg-green-100 text-green-700", else: "bg-red-100 text-red-700")
              ]}>
                <%= if @trend > 0, do: "↑", else: "↓" %>
                <%= Float.round(abs(@trend), 2) %>
              </span>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :sentiment, :string, required: true

  defp sentiment_badge(assigns) do
    ~H"""
    <span class={[
      "px-2 py-1 text-xs font-black uppercase border-2 border-black",
      case @sentiment do
        "positive" -> "bg-green-300"
        "negative" -> "bg-red-300"
        _ -> "bg-gray-300"
      end
    ]}>
      <%= @sentiment %>
    </span>
    """
  end

  attr :data, :list, required: true

  defp sentiment_chart(assigns) do
    ~H"""
    <div class="h-full flex items-end justify-between gap-1">
      <%= for point <- @data do %>
        <div class="flex-1 flex flex-col items-center">
          <div
            class="w-full bg-blue-500 border-2 border-black"
            style={"height: #{normalize_sentiment(point.avg_sentiment)}%"}
            title={"#{Calendar.strftime(point.date, "%d/%m")}: #{Float.round(point.avg_sentiment, 2)}"}
          >
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp sentiment_color(sentiment) when sentiment > 0.3, do: "text-green-600"
  defp sentiment_color(sentiment) when sentiment < -0.3, do: "text-red-600"
  defp sentiment_color(_), do: "text-gray-600"

  defp sentiment_badge_color(sentiment) when sentiment > 0.3,
    do: "bg-green-100 text-green-700 border border-green-300"

  defp sentiment_badge_color(sentiment) when sentiment < -0.3,
    do: "bg-red-100 text-red-700 border border-red-300"

  defp sentiment_badge_color(_), do: "bg-gray-100 text-gray-700 border border-gray-300"

  defp normalize_sentiment(sentiment) do
    # Перетворюємо -1..1 в 0..100
    ((sentiment + 1) / 2 * 100) |> max(5) |> min(100) |> round()
  end
end
