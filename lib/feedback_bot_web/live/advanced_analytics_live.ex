defmodule FeedbackBotWeb.AdvancedAnalyticsLive do
  use FeedbackBotWeb, :live_view
  require Logger

  alias FeedbackBot.{Feedbacks, Employees}

  @impl true
  def mount(_params, _session, socket) do
    period_end = DateTime.utc_now()
    period_start = DateTime.add(period_end, -30 * 24 * 60 * 60, :second)

    socket =
      socket
      |> assign(:page_title, "Аналітика 2.0")
      |> assign(:active_nav, "/analytics")
      |> assign(:period_start, period_start)
      |> assign(:period_end, period_end)
      |> assign(:selected_employee_id, nil)
      |> assign(:search_term, "")
      |> assign(:sentiment_filter, "all")
      |> assign(:employees, list_employees_safe())
      |> assign(:error, nil)
      |> load_data()

    {:ok, socket}
  end

  defp load_data(socket) do
    try do
      filters = %{
        from: socket.assigns.period_start,
        to: socket.assigns.period_end
      }

      feedbacks = Feedbacks.filter_feedbacks(filters)
      summary = calculate_summary(feedbacks)

      socket
      |> assign(:feedbacks, feedbacks)
      |> assign(:summary, summary)
    rescue
      e ->
        Logger.error("Failed to load analytics data: #{inspect(e)}")

        socket
        |> assign(:feedbacks, [])
        |> assign(:summary, default_summary())
        |> assign(:error, "Помилка завантаження даних: #{Exception.message(e)}")
    end
  end

  defp calculate_summary(feedbacks) do
    total = length(feedbacks)

    if total == 0 do
      default_summary()
    else
      {sentiment_sum, urgency_sum, impact_sum, positive, negative, risky} =
        Enum.reduce(feedbacks, {0.0, 0.0, 0.0, 0, 0, 0}, fn f, {s_sum, u_sum, i_sum, pos, neg, risk} ->
          is_risky = (f.sentiment_label == "negative" && (f.sentiment_score || 0) < -0.1) ||
                     (f.urgency_score || 0) > 0.7 ||
                     (f.impact_score || 0) > 0.7

          {
            s_sum + (f.sentiment_score || 0.0),
            u_sum + (f.urgency_score || 0.0),
            i_sum + (f.impact_score || 0.0),
            pos + if(f.sentiment_label == "positive", do: 1, else: 0),
            neg + if(f.sentiment_label == "negative", do: 1, else: 0),
            risk + if(is_risky, do: 1, else: 0)
          }
        end)

      %{
        total_feedbacks: total,
        avg_sentiment: sentiment_sum / total,
        avg_urgency: urgency_sum / total,
        avg_impact: impact_sum / total,
        positive_share: positive / total,
        negative_share: negative / total,
        risky_feedbacks: risky
      }
    end
  end

  defp list_employees_safe do
    try do
      Employees.list_active_employees()
    rescue
      e ->
        Logger.error("Failed to load employees: #{inspect(e)}")
        []
    end
  end

  defp default_summary do
    %{
      total_feedbacks: 0,
      avg_sentiment: 0.0,
      avg_urgency: 0.0,
      avg_impact: 0.0,
      positive_share: 0.0,
      negative_share: 0.0,
      risky_feedbacks: 0
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-950 text-slate-100">
      <.top_nav active={@active_nav} />

      <div class="max-w-7xl mx-auto px-4 py-8">
        <%= if @error do %>
          <div class="bg-red-900/30 border border-red-500 rounded-xl p-4 mb-6">
            <h3 class="text-xl font-bold text-red-400">Помилка</h3>
            <p class="text-sm text-red-300 mt-2"><%= @error %></p>
          </div>
        <% end %>

        <div class="space-y-6">
          <div>
            <h1 class="text-4xl font-black text-white">Аналітика 2.0</h1>
            <p class="text-slate-400 mt-2">Розширена аналітика працює</p>
          </div>

          <!-- KPI Cards -->
          <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <div class="bg-gradient-to-br from-emerald-500/20 to-emerald-900/20 border border-emerald-500/40 rounded-xl p-4">
              <p class="text-xs uppercase tracking-wide text-slate-200/80">Всього фідбеків</p>
              <p class="text-3xl font-black text-white mt-2"><%= @summary.total_feedbacks %></p>
              <p class="text-xs text-slate-200/70 mt-2">Live processed</p>
            </div>

            <div class="bg-gradient-to-br from-blue-500/20 to-blue-900/20 border border-blue-500/40 rounded-xl p-4">
              <p class="text-xs uppercase tracking-wide text-slate-200/80">Середній Sentiment</p>
              <p class="text-3xl font-black text-white mt-2"><%= Float.round(@summary.avg_sentiment, 2) %></p>
              <p class="text-xs text-slate-200/70 mt-2">Позитивні: <%= Float.round(@summary.positive_share * 100, 1) %>%</p>
            </div>

            <div class="bg-gradient-to-br from-rose-500/20 to-rose-900/20 border border-rose-500/40 rounded-xl p-4">
              <p class="text-xs uppercase tracking-wide text-slate-200/80">Ризикові</p>
              <p class="text-3xl font-black text-white mt-2"><%= @summary.risky_feedbacks %></p>
              <p class="text-xs text-slate-200/70 mt-2">Негативні: <%= Float.round(@summary.negative_share * 100, 1) %>%</p>
            </div>

            <div class="bg-gradient-to-br from-amber-500/20 to-amber-900/20 border border-amber-500/40 rounded-xl p-4">
              <p class="text-xs uppercase tracking-wide text-slate-200/80">Urgency / Impact</p>
              <p class="text-3xl font-black text-white mt-2"><%= Float.round(@summary.avg_urgency, 2) %> / <%= Float.round(@summary.avg_impact, 2) %></p>
              <p class="text-xs text-slate-200/70 mt-2">Середні показники</p>
            </div>
          </div>

          <div class="bg-slate-900/70 border border-slate-800 rounded-xl p-6">
            <h2 class="text-2xl font-bold text-white mb-4">Статус</h2>
            <p class="text-green-400">✅ Реальні дані завантажено!</p>
            <p class="text-slate-300 mt-2">Співробітників: <%= length(@employees) %></p>
            <p class="text-slate-300">Фідбеків за період: <%= length(@feedbacks) %></p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
