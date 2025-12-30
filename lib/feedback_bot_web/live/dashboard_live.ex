defmodule FeedbackBotWeb.DashboardLive do
  use FeedbackBotWeb, :live_view

  alias FeedbackBot.{Employees, Feedbacks, Analytics}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to real-time updates
      Phoenix.PubSub.subscribe(FeedbackBot.PubSub, "feedbacks")

      # Отримуємо статистику
      latest_daily = Analytics.get_latest_snapshot("daily")
      latest_weekly = Analytics.get_latest_snapshot("weekly")
      latest_monthly = Analytics.get_latest_snapshot("monthly")

      daily = latest_daily || runtime_snapshot(1)
      weekly = latest_weekly || runtime_snapshot(7)
      monthly = latest_monthly || runtime_snapshot(30)

      recent_feedbacks = Feedbacks.list_recent_feedbacks(5)
      employees = Employees.list_active_employees()

      # Тренд за останні 30 днів
      sentiment_trend = Analytics.get_sentiment_trend_data("daily", 30)

      socket =
        socket
        |> assign(:page_title, "Dashboard")
        |> assign(:active_nav, "/")
        |> assign(:daily_snapshot, daily)
        |> assign(:weekly_snapshot, weekly)
        |> assign(:monthly_snapshot, monthly)
        |> assign(:recent_feedbacks, recent_feedbacks)
        |> assign(:employees, employees)
        |> assign(:sentiment_trend, sentiment_trend)

      {:ok, socket}
    else
      {:ok,
       socket
       |> assign(:page_title, "Dashboard")
       |> assign(:active_nav, "/")
       |> assign(:daily_snapshot, nil)
       |> assign(:weekly_snapshot, nil)
       |> assign(:monthly_snapshot, nil)
       |> assign(:recent_feedbacks, [])
       |> assign(:employees, [])
       |> assign(:sentiment_trend, [])}
    end
  end

  @impl true
  def handle_info({type, _feedback}, socket) when type in [:new_feedback, :feedback_updated, :feedback_deleted] do
    {:noreply, refresh_dashboard_assigns(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-violet-50 via-purple-50 to-pink-50">
      <.top_nav active={@active_nav} />
      <!-- Header -->
      <header class="bg-white shadow-lg border-b-2 sm:border-b-4 border-violet-600">
        <div class="max-w-7xl mx-auto px-3 sm:px-6 lg:px-8 py-4 sm:py-6">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl sm:text-4xl lg:text-5xl font-black bg-gradient-to-r from-violet-600 to-purple-600 bg-clip-text text-transparent leading-tight">
                📊 FeedbackBot
              </h1>
              <p class="mt-1 sm:mt-2 text-sm sm:text-base lg:text-lg font-semibold text-gray-600">
                AI-powered Analytics & Insights
              </p>
            </div>
          </div>
        </div>
      </header>

      <main class="max-w-7xl mx-auto px-3 sm:px-4 lg:px-8 py-4 sm:py-6 lg:py-8">
        <!-- Quick Stats -->
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6 mb-6 sm:mb-8">
          <.stat_card
            title="Сьогодні"
            value={if @daily_snapshot, do: @daily_snapshot.total_feedbacks, else: 0}
            sentiment={if @daily_snapshot, do: @daily_snapshot.avg_sentiment, else: 0}
            trend={if @daily_snapshot, do: @daily_snapshot.sentiment_trend, else: 0}
            tooltip="Кількість оброблених фідбеків за сьогодні. Тональність показує загальний настрій (-1 до +1). Тренд порівнює з вчорашнім днем."
          />
          <.stat_card
            title="Цього тижня"
            value={if @weekly_snapshot, do: @weekly_snapshot.total_feedbacks, else: 0}
            sentiment={if @weekly_snapshot, do: @weekly_snapshot.avg_sentiment, else: 0}
            trend={if @weekly_snapshot, do: @weekly_snapshot.sentiment_trend, else: 0}
            tooltip="Фідбеки за останні 7 днів. Середня тональність всіх відгуків. Тренд показує зміну порівняно з минулим тижнем."
          />
          <.stat_card
            title="Цього місяця"
            value={if @monthly_snapshot, do: @monthly_snapshot.total_feedbacks, else: 0}
            sentiment={if @monthly_snapshot, do: @monthly_snapshot.avg_sentiment, else: 0}
            trend={if @monthly_snapshot, do: @monthly_snapshot.sentiment_trend, else: 0}
            tooltip="Фідбеки за поточний місяць. Показує загальну динаміку та якість зворотного зв'язку. Тренд порівнюється з минулим місяцем."
          />
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6">
          <!-- Sentiment Trend Chart -->
          <div class="neo-brutal-card">
            <h2 class="text-lg sm:text-xl lg:text-2xl font-black uppercase mb-3 sm:mb-4 flex items-center gap-2">
              <span>📈</span>
              <span>Тренд Тональності (30 днів)</span>
            </h2>
            <div class="h-64 sm:h-72 lg:h-80">
              <div
                id="sentiment-trend-chart"
                phx-hook="SentimentTrendChart"
                data-sentiment-trend={Jason.encode!(@sentiment_trend)}
                class="h-full w-full"
              >
              </div>
            </div>
            <div class="mt-4 flex gap-2 text-xs font-bold text-gray-600">
              <div class="flex items-center gap-1">
                <div class="w-3 h-3 bg-violet-500 rounded-full"></div>
                <span>Тональність (-1 до +1)</span>
              </div>
              <div class="flex items-center gap-1">
                <div class="w-3 h-0.5 bg-yellow-500"></div>
                <span>Кількість фідбеків</span>
              </div>
            </div>
          </div>

          <!-- Recent Feedbacks -->
          <div class="neo-brutal-card">
            <div class="flex justify-between items-center mb-3 sm:mb-4">
              <h2 class="text-lg sm:text-xl lg:text-2xl font-black uppercase">
                Останні Фідбеки
              </h2>
              <.link navigate="/feedbacks" class="neo-brutal-btn-sm text-xs sm:text-sm">
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
              <h2 class="text-lg sm:text-xl lg:text-2xl font-black uppercase mb-3 sm:mb-4">
                Топ Проблем
              </h2>
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
            <div class="flex justify-between items-center mb-3 sm:mb-4">
              <h2 class="text-lg sm:text-xl lg:text-2xl font-black uppercase">Співробітники</h2>
              <.link navigate="/employees" class="neo-brutal-btn-sm text-xs sm:text-sm">
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
          <div class="mt-6 sm:mt-8 neo-brutal-card bg-yellow-100">
            <h2 class="text-lg sm:text-xl lg:text-2xl font-black uppercase mb-3 sm:mb-4 flex items-center gap-2">
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
  attr :tooltip, :string, default: nil

  defp stat_card(assigns) do
    ~H"""
    <div class="relative overflow-hidden rounded-xl sm:rounded-2xl bg-white shadow-xl border-3 sm:border-4 border-violet-200 active:border-violet-400 sm:hover:border-violet-400 transition-all duration-300 sm:transform sm:hover:-translate-y-2 sm:hover:shadow-violet-200 group">
      <div class="absolute top-0 right-0 w-24 h-24 sm:w-32 sm:h-32 bg-gradient-to-br from-violet-400 to-purple-400 opacity-10 rounded-full -mr-12 sm:-mr-16 -mt-12 sm:-mt-16">
      </div>
      <div class="p-4 sm:p-6 relative">
        <div class="flex items-start justify-between gap-2">
          <h3 class="text-xs sm:text-sm font-bold uppercase text-gray-500 tracking-wider flex-1">
            <%= @title %>
          </h3>
          <%= if @tooltip do %>
            <div class="relative group/tooltip flex-shrink-0">
              <div class="w-4 h-4 sm:w-5 sm:h-5 rounded-full bg-violet-200 text-violet-700 flex items-center justify-center text-[10px] sm:text-xs font-bold cursor-help">
                ?
              </div>
              <div class="absolute right-0 top-6 w-48 sm:w-64 p-3 bg-gray-900 text-white text-xs rounded-lg shadow-xl opacity-0 invisible group-hover/tooltip:opacity-100 group-hover/tooltip:visible transition-all duration-200 z-50 pointer-events-none">
                <%= @tooltip %>
                <div class="absolute -top-1 right-4 w-2 h-2 bg-gray-900 transform rotate-45"></div>
              </div>
            </div>
          <% end %>
        </div>
        <p class="text-4xl sm:text-5xl font-black mt-2 sm:mt-3 bg-gradient-to-r from-violet-600 to-purple-600 bg-clip-text text-transparent leading-tight">
          <%= @value %>
        </p>
        <div class="mt-3 sm:mt-4 space-y-1.5 sm:space-y-2">
          <div class="flex items-center justify-between gap-2">
            <span class="text-[10px] sm:text-xs font-semibold text-gray-600 flex-shrink-0">
              Тональність:
            </span>
            <span class={[
              "px-2 sm:px-3 py-1 rounded-full text-[10px] sm:text-xs font-bold whitespace-nowrap",
              sentiment_badge_color(@sentiment)
            ]}>
              <%= format_sentiment(@sentiment) %>
            </span>
          </div>
          <%= if @trend != 0 do %>
            <div class="flex items-center justify-between gap-2">
              <span class="text-[10px] sm:text-xs font-semibold text-gray-600 flex-shrink-0">
                Тренд:
              </span>
              <span class={[
                "px-2 sm:px-3 py-1 rounded-full text-[10px] sm:text-xs font-bold whitespace-nowrap flex items-center gap-1",
                if(@trend > 0, do: "bg-green-100 text-green-700", else: "bg-red-100 text-red-700")
              ]}>
                <span><%= if @trend > 0, do: "↑", else: "↓" %></span>
                <span><%= format_trend(@trend) %>%</span>
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


  defp sentiment_color(sentiment) when sentiment > 0.3, do: "text-green-600"
  defp sentiment_color(sentiment) when sentiment < -0.3, do: "text-red-600"
  defp sentiment_color(_), do: "text-gray-600"

  defp sentiment_badge_color(sentiment) when sentiment > 0.3,
    do: "bg-green-100 text-green-700 border border-green-300"

  defp sentiment_badge_color(sentiment) when sentiment < -0.3,
    do: "bg-red-100 text-red-700 border border-red-300"

  defp sentiment_badge_color(_), do: "bg-gray-100 text-gray-700 border border-gray-300"


  # Lightweight runtime snapshot so лічильники працюють навіть без precomputed analytics
  defp runtime_snapshot(days) do
    period_end = DateTime.utc_now()
    period_start = DateTime.add(period_end, -days, :day)
    stats = Feedbacks.get_sentiment_stats(period_start, period_end)

    # Calculate trend by comparing with previous period
    prev_period_end = period_start
    prev_period_start = DateTime.add(prev_period_end, -days, :day)
    prev_stats = Feedbacks.get_sentiment_stats(prev_period_start, prev_period_end)

    current_sentiment = stats.avg_sentiment || 0.0
    prev_sentiment = prev_stats.avg_sentiment || 0.0

    sentiment_trend =
      if prev_sentiment != 0 do
        ((current_sentiment - prev_sentiment) / abs(prev_sentiment)) * 100
      else
        0.0
      end

    %{
      total_feedbacks: stats.total || 0,
      avg_sentiment: current_sentiment,
      sentiment_trend: sentiment_trend,
      positive_count: stats.positive || 0,
      neutral_count: stats.neutral || 0,
      negative_count: stats.negative || 0,
      top_issues: [],
      ai_insights: nil,
      recommendations: []
    }
  end

  # Format helpers for responsive display
  defp format_sentiment(sentiment) when is_float(sentiment) do
    Float.round(sentiment, 2)
  end

  defp format_sentiment(sentiment) when is_integer(sentiment), do: sentiment
  defp format_sentiment(nil), do: 0.0
  defp format_sentiment(_), do: 0.0

  defp format_trend(trend) when is_float(trend) do
    Float.round(abs(trend), 1)
  end

  defp format_trend(trend) when is_integer(trend), do: abs(trend)
  defp format_trend(nil), do: 0
  defp format_trend(_), do: 0

  defp refresh_dashboard_assigns(socket) do
    latest_daily = Analytics.get_latest_snapshot("daily")
    latest_weekly = Analytics.get_latest_snapshot("weekly")
    latest_monthly = Analytics.get_latest_snapshot("monthly")
    recent_feedbacks = Feedbacks.list_recent_feedbacks(5)
    sentiment_trend = Analytics.get_sentiment_trend_data("daily", 30)

    socket
    |> assign(:daily_snapshot, latest_daily)
    |> assign(:weekly_snapshot, latest_weekly)
    |> assign(:monthly_snapshot, latest_monthly)
    |> assign(:recent_feedbacks, recent_feedbacks)
    |> assign(:sentiment_trend, sentiment_trend)
  end
end
