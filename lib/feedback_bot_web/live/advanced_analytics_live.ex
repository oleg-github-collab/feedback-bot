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
      topics = extract_top_topics(feedbacks)
      timeline = Enum.take(feedbacks, 20)
      risks = extract_risks(feedbacks)

      socket
      |> assign(:feedbacks, feedbacks)
      |> assign(:summary, summary)
      |> assign(:top_topics, topics)
      |> assign(:timeline_data, timeline)
      |> assign(:risk_register, risks)
    rescue
      e ->
        Logger.error("Failed to load analytics data: #{inspect(e)}")

        socket
        |> assign(:feedbacks, [])
        |> assign(:summary, default_summary())
        |> assign(:top_topics, [])
        |> assign(:timeline_data, [])
        |> assign(:risk_register, [])
        |> assign(:error, "Помилка завантаження даних: #{Exception.message(e)}")
    end
  end

  defp extract_top_topics(feedbacks) do
    feedbacks
    |> Enum.flat_map(fn f -> f.topics || [] end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_topic, count} -> count end, :desc)
    |> Enum.take(8)
    |> Enum.map(fn {topic, count} -> %{topic: topic, count: count} end)
  end

  defp extract_risks(feedbacks) do
    feedbacks
    |> Enum.filter(fn f ->
      (f.sentiment_label == "negative" && (f.sentiment_score || 0) < -0.1) ||
        (f.urgency_score || 0) > 0.7 ||
        (f.impact_score || 0) > 0.7
    end)
    |> Enum.sort_by(fn f -> -(f.urgency_score || 0) * (f.impact_score || 0) end)
    |> Enum.take(10)
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
  def handle_event("filter", %{"employee_id" => emp_id, "sentiment" => sent, "search" => search}, socket) do
    socket =
      socket
      |> assign(:selected_employee_id, parse_employee_id(emp_id))
      |> assign(:sentiment_filter, sent)
      |> assign(:search_term, search)
      |> reload_with_filters()

    {:noreply, socket}
  end

  def handle_event("set_period", %{"days" => days_str}, socket) do
    days = String.to_integer(days_str)
    period_end = DateTime.utc_now()
    period_start = DateTime.add(period_end, -days * 24 * 60 * 60, :second)

    socket =
      socket
      |> assign(:period_start, period_start)
      |> assign(:period_end, period_end)
      |> reload_with_filters()

    {:noreply, socket}
  end

  defp parse_employee_id(""), do: nil
  defp parse_employee_id(id), do: id

  defp reload_with_filters(socket) do
    try do
      filters = build_filters(socket.assigns)
      feedbacks = Feedbacks.filter_feedbacks(filters)
      filtered_feedbacks = apply_search(feedbacks, socket.assigns.search_term)
      summary = calculate_summary(filtered_feedbacks)
      topics = extract_top_topics(filtered_feedbacks)
      timeline = Enum.take(filtered_feedbacks, 20)
      risks = extract_risks(filtered_feedbacks)

      socket
      |> assign(:feedbacks, filtered_feedbacks)
      |> assign(:summary, summary)
      |> assign(:top_topics, topics)
      |> assign(:timeline_data, timeline)
      |> assign(:risk_register, risks)
    rescue
      e ->
        Logger.error("Failed to reload with filters: #{inspect(e)}")
        assign(socket, :error, "Помилка фільтрації: #{Exception.message(e)}")
    end
  end

  defp build_filters(assigns) do
    filters = %{from: assigns.period_start, to: assigns.period_end}

    filters =
      if assigns.selected_employee_id,
        do: Map.put(filters, :employee_id, assigns.selected_employee_id),
        else: filters

    filters =
      if assigns.sentiment_filter != "all",
        do: Map.put(filters, :sentiment, assigns.sentiment_filter),
        else: filters

    filters
  end

  defp apply_search(feedbacks, ""), do: feedbacks
  defp apply_search(feedbacks, nil), do: feedbacks

  defp apply_search(feedbacks, term) do
    normalized = String.downcase(term)

    Enum.filter(feedbacks, fn f ->
      (f.summary && String.contains?(String.downcase(f.summary), normalized)) ||
        (f.transcription && String.contains?(String.downcase(f.transcription), normalized))
    end)
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
            <p class="text-slate-400 mt-2">Розширена аналітика з потужними зрізами</p>
          </div>

          <!-- Filters -->
          <div class="bg-slate-900/70 border border-slate-800 rounded-xl p-4">
            <form phx-change="filter">
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                <div>
                  <label class="block text-xs uppercase tracking-wide text-slate-400 mb-1">Співробітник</label>
                  <select name="employee_id" class="w-full rounded-lg border border-slate-700 bg-slate-800 text-white px-3 py-2 focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500">
                    <option value="">Всі</option>
                    <%= for emp <- @employees do %>
                      <option value={emp.id} selected={emp.id == @selected_employee_id}><%= emp.name %></option>
                    <% end %>
                  </select>
                </div>

                <div>
                  <label class="block text-xs uppercase tracking-wide text-slate-400 mb-1">Тональність</label>
                  <select name="sentiment" class="w-full rounded-lg border border-slate-700 bg-slate-800 text-white px-3 py-2 focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500">
                    <option value="all" selected={@sentiment_filter == "all"}>Всі</option>
                    <option value="positive" selected={@sentiment_filter == "positive"}>Позитивна</option>
                    <option value="neutral" selected={@sentiment_filter == "neutral"}>Нейтральна</option>
                    <option value="negative" selected={@sentiment_filter == "negative"}>Негативна</option>
                  </select>
                </div>

                <div>
                  <label class="block text-xs uppercase tracking-wide text-slate-400 mb-1">Пошук</label>
                  <input
                    type="text"
                    name="search"
                    value={@search_term}
                    placeholder="Пошук по тексту..."
                    class="w-full rounded-lg border border-slate-700 bg-slate-800 text-white px-3 py-2 focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
                  />
                </div>

                <div>
                  <label class="block text-xs uppercase tracking-wide text-slate-400 mb-1">Період</label>
                  <select phx-change="set_period" name="days" class="w-full rounded-lg border border-slate-700 bg-slate-800 text-white px-3 py-2 focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500">
                    <option value="7">7 днів</option>
                    <option value="30" selected>30 днів</option>
                    <option value="90">90 днів</option>
                  </select>
                </div>
              </div>
            </form>
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

          <!-- Top Topics -->
          <div class="bg-slate-900/70 border border-slate-800 rounded-xl p-6">
            <h2 class="text-xl font-bold text-white mb-4">🔥 Топ теми</h2>
            <%= if length(@top_topics) > 0 do %>
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
                <%= for topic <- @top_topics do %>
                  <div class="bg-slate-800/50 border border-slate-700 rounded-lg p-3">
                    <p class="text-sm text-white font-semibold"><%= topic.topic %></p>
                    <p class="text-2xl font-black text-emerald-400 mt-1"><%= topic.count %></p>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-slate-400">Немає тем для відображення</p>
            <% end %>
          </div>

          <!-- Timeline -->
          <div class="bg-slate-900/70 border border-slate-800 rounded-xl p-6">
            <h2 class="text-xl font-bold text-white mb-4">📊 Живий потік (останні 20)</h2>
            <%= if length(@timeline_data) > 0 do %>
              <div class="space-y-3 max-h-96 overflow-y-auto">
                <%= for feedback <- @timeline_data do %>
                  <div class="bg-slate-800/50 border border-slate-700 rounded-lg p-4">
                    <div class="flex items-start justify-between gap-3">
                      <div class="flex-1">
                        <p class="text-sm text-slate-300"><%= feedback.summary || "Без резюме" %></p>
                        <%= if feedback.employee do %>
                          <p class="text-xs text-slate-500 mt-1">👤 <%= feedback.employee.name %></p>
                        <% end %>
                      </div>
                      <div class="flex flex-col items-end gap-1">
                        <span class={[
                          "px-2 py-1 rounded text-xs font-bold",
                          case feedback.sentiment_label do
                            "positive" -> "bg-green-500/20 text-green-400"
                            "negative" -> "bg-red-500/20 text-red-400"
                            _ -> "bg-slate-500/20 text-slate-400"
                          end
                        ]}>
                          <%= feedback.sentiment_label || "?" %>
                        </span>
                        <p class="text-xs text-slate-500">
                          <%= Calendar.strftime(feedback.inserted_at, "%d.%m %H:%M") %>
                        </p>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-slate-400">Немає фідбеків для відображення</p>
            <% end %>
          </div>

          <!-- Risk Register -->
          <div class="bg-slate-900/70 border border-slate-800 rounded-xl p-6">
            <h2 class="text-xl font-bold text-white mb-4">⚠️ Реєстр ризиків (топ 10)</h2>
            <%= if length(@risk_register) > 0 do %>
              <div class="space-y-3">
                <%= for risk <- @risk_register do %>
                  <div class="bg-red-900/20 border border-red-500/30 rounded-lg p-4">
                    <div class="flex items-start justify-between gap-3">
                      <div class="flex-1">
                        <p class="text-sm text-white font-semibold"><%= risk.summary || "Критичний фідбек" %></p>
                        <%= if risk.employee do %>
                          <p class="text-xs text-slate-400 mt-1">👤 <%= risk.employee.name %></p>
                        <% end %>
                      </div>
                      <div class="flex gap-2">
                        <div class="text-center">
                          <p class="text-xs text-slate-400">U</p>
                          <p class="text-sm font-bold text-orange-400"><%= Float.round(risk.urgency_score || 0, 2) %></p>
                        </div>
                        <div class="text-center">
                          <p class="text-xs text-slate-400">I</p>
                          <p class="text-sm font-bold text-red-400"><%= Float.round(risk.impact_score || 0, 2) %></p>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-green-400">✅ Ризикових фідбеків не виявлено!</p>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
