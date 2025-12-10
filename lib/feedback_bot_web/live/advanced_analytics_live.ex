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
      # Search in summary
      summary_match = f.summary && String.contains?(String.downcase(f.summary), normalized)

      # Search in transcription
      transcription_match = f.transcription && String.contains?(String.downcase(f.transcription), normalized)

      # Search in topics
      topics_match =
        (f.topics || [])
        |> Enum.filter(&is_binary/1)
        |> Enum.any?(fn topic -> String.contains?(String.downcase(topic), normalized) end)

      # Search in issues descriptions
      issues_match =
        (f.issues || [])
        |> Enum.any?(fn issue ->
          desc = Map.get(issue, "description", "") || Map.get(issue, :description, "")
          is_binary(desc) && String.contains?(String.downcase(desc), normalized)
        end)

      # Search in employee name
      employee_match =
        f.employee && f.employee.name && String.contains?(String.downcase(f.employee.name), normalized)

      summary_match || transcription_match || topics_match || issues_match || employee_match
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-950 text-slate-100">
      <.top_nav active={@active_nav} />

      <div class="max-w-7xl mx-auto px-3 sm:px-4 lg:px-8 py-4 sm:py-6 lg:py-8">
        <%= if @error do %>
          <div class="bg-red-900/30 border border-red-500 rounded-xl p-3 sm:p-4 mb-4 sm:mb-6">
            <h3 class="text-lg sm:text-xl font-bold text-red-400">Помилка</h3>
            <p class="text-xs sm:text-sm text-red-300 mt-2"><%= @error %></p>
          </div>
        <% end %>

        <div class="space-y-4 sm:space-y-6">
          <div>
            <h1 class="text-2xl sm:text-3xl lg:text-4xl font-black text-white">Аналітика 2.0</h1>
            <p class="text-xs sm:text-sm text-slate-400 mt-1 sm:mt-2">Розширена аналітика з потужними зрізами</p>
          </div>

          <!-- Filters -->
          <div class="bg-slate-900/70 border border-slate-800 rounded-lg sm:rounded-xl p-3 sm:p-4">
            <form phx-change="filter">
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
                <div>
                  <label class="block text-[10px] sm:text-xs uppercase tracking-wide text-slate-400 mb-1">Співробітник</label>
                  <select name="employee_id" class="w-full rounded-lg border border-slate-700 bg-slate-800 text-white text-sm px-2 sm:px-3 py-1.5 sm:py-2 focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500">
                    <option value="">Всі</option>
                    <%= for emp <- @employees do %>
                      <option value={emp.id} selected={emp.id == @selected_employee_id}><%= emp.name %></option>
                    <% end %>
                  </select>
                </div>

                <div>
                  <label class="block text-[10px] sm:text-xs uppercase tracking-wide text-slate-400 mb-1">Тональність</label>
                  <select name="sentiment" class="w-full rounded-lg border border-slate-700 bg-slate-800 text-white text-sm px-2 sm:px-3 py-1.5 sm:py-2 focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500">
                    <option value="all" selected={@sentiment_filter == "all"}>Всі</option>
                    <option value="positive" selected={@sentiment_filter == "positive"}>Позитивна</option>
                    <option value="neutral" selected={@sentiment_filter == "neutral"}>Нейтральна</option>
                    <option value="negative" selected={@sentiment_filter == "negative"}>Негативна</option>
                  </select>
                </div>

                <div>
                  <label class="block text-[10px] sm:text-xs uppercase tracking-wide text-slate-400 mb-1">Пошук</label>
                  <input
                    type="text"
                    name="search"
                    value={@search_term}
                    placeholder="Текст, теми, проблеми..."
                    class="w-full rounded-lg border border-slate-700 bg-slate-800 text-white text-sm px-2 sm:px-3 py-1.5 sm:py-2 focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 placeholder:text-slate-500"
                  />
                </div>

                <div>
                  <label class="block text-[10px] sm:text-xs uppercase tracking-wide text-slate-400 mb-1">Період</label>
                  <select phx-change="set_period" name="days" class="w-full rounded-lg border border-slate-700 bg-slate-800 text-white text-sm px-2 sm:px-3 py-1.5 sm:py-2 focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500">
                    <option value="7">7 днів</option>
                    <option value="30" selected>30 днів</option>
                    <option value="90">90 днів</option>
                  </select>
                </div>
              </div>
            </form>
          </div>

          <!-- KPI Cards -->
          <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
            <div class="bg-gradient-to-br from-emerald-500/20 to-emerald-900/20 border border-emerald-500/40 rounded-lg sm:rounded-xl p-3 sm:p-4 group relative">
              <div class="flex items-start justify-between gap-1">
                <p class="text-[10px] sm:text-xs uppercase tracking-wide text-slate-200/80 flex-1">Всього фідбеків</p>
                <div class="relative flex-shrink-0">
                  <div class="w-3 h-3 sm:w-4 sm:h-4 rounded-full bg-emerald-500/30 text-emerald-300 flex items-center justify-center text-[8px] sm:text-[10px] font-bold cursor-help">?</div>
                  <div class="absolute right-0 top-5 w-40 sm:w-56 p-2 sm:p-3 bg-slate-900 border border-emerald-500/50 text-white text-[10px] sm:text-xs rounded-lg shadow-xl opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 z-50 pointer-events-none">
                    Загальна кількість оброблених фідбеків за вибраний період з урахуванням фільтрів
                  </div>
                </div>
              </div>
              <p class="text-2xl sm:text-3xl font-black text-white mt-1 sm:mt-2"><%= @summary.total_feedbacks %></p>
              <p class="text-[10px] sm:text-xs text-slate-200/70 mt-1 sm:mt-2">Live processed</p>
            </div>

            <div class="bg-gradient-to-br from-blue-500/20 to-blue-900/20 border border-blue-500/40 rounded-lg sm:rounded-xl p-3 sm:p-4 group relative">
              <div class="flex items-start justify-between gap-1">
                <p class="text-[10px] sm:text-xs uppercase tracking-wide text-slate-200/80 flex-1">Середній Sentiment</p>
                <div class="relative flex-shrink-0">
                  <div class="w-3 h-3 sm:w-4 sm:h-4 rounded-full bg-blue-500/30 text-blue-300 flex items-center justify-center text-[8px] sm:text-[10px] font-bold cursor-help">?</div>
                  <div class="absolute right-0 top-5 w-40 sm:w-56 p-2 sm:p-3 bg-slate-900 border border-blue-500/50 text-white text-[10px] sm:text-xs rounded-lg shadow-xl opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 z-50 pointer-events-none">
                    Середня тональність від -1 (дуже негативна) до +1 (дуже позитивна). Показує загальний настрій клієнтів
                  </div>
                </div>
              </div>
              <p class="text-2xl sm:text-3xl font-black text-white mt-1 sm:mt-2"><%= Float.round(@summary.avg_sentiment, 2) %></p>
              <p class="text-[10px] sm:text-xs text-slate-200/70 mt-1 sm:mt-2">Позитивні: <%= Float.round(@summary.positive_share * 100, 1) %>%</p>
            </div>

            <div class="bg-gradient-to-br from-rose-500/20 to-rose-900/20 border border-rose-500/40 rounded-lg sm:rounded-xl p-3 sm:p-4 group relative">
              <div class="flex items-start justify-between gap-1">
                <p class="text-[10px] sm:text-xs uppercase tracking-wide text-slate-200/80 flex-1">Ризикові</p>
                <div class="relative flex-shrink-0">
                  <div class="w-3 h-3 sm:w-4 sm:h-4 rounded-full bg-rose-500/30 text-rose-300 flex items-center justify-center text-[8px] sm:text-[10px] font-bold cursor-help">?</div>
                  <div class="absolute right-0 top-5 w-40 sm:w-56 p-2 sm:p-3 bg-slate-900 border border-rose-500/50 text-white text-[10px] sm:text-xs rounded-lg shadow-xl opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 z-50 pointer-events-none">
                    Фідбеки з високою терміновістю/впливом (>0.7) або сильно негативні (<-0.1). Потребують негайної уваги!
                  </div>
                </div>
              </div>
              <p class="text-2xl sm:text-3xl font-black text-white mt-1 sm:mt-2"><%= @summary.risky_feedbacks %></p>
              <p class="text-[10px] sm:text-xs text-slate-200/70 mt-1 sm:mt-2">Негативні: <%= Float.round(@summary.negative_share * 100, 1) %>%</p>
            </div>

            <div class="bg-gradient-to-br from-amber-500/20 to-amber-900/20 border border-amber-500/40 rounded-lg sm:rounded-xl p-3 sm:p-4 group relative">
              <div class="flex items-start justify-between gap-1">
                <p class="text-[10px] sm:text-xs uppercase tracking-wide text-slate-200/80 flex-1">Urgency / Impact</p>
                <div class="relative flex-shrink-0">
                  <div class="w-3 h-3 sm:w-4 sm:h-4 rounded-full bg-amber-500/30 text-amber-300 flex items-center justify-center text-[8px] sm:text-[10px] font-bold cursor-help">?</div>
                  <div class="absolute right-0 top-5 w-40 sm:w-56 p-2 sm:p-3 bg-slate-900 border border-amber-500/50 text-white text-[10px] sm:text-xs rounded-lg shadow-xl opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 z-50 pointer-events-none">
                    Urgency - наскільки терміново потрібно відреагувати (0-1). Impact - наскільки проблема впливає на бізнес (0-1)
                  </div>
                </div>
              </div>
              <p class="text-xl sm:text-2xl lg:text-3xl font-black text-white mt-1 sm:mt-2"><%= Float.round(@summary.avg_urgency, 2) %> / <%= Float.round(@summary.avg_impact, 2) %></p>
              <p class="text-[10px] sm:text-xs text-slate-200/70 mt-1 sm:mt-2">Середні показники</p>
            </div>
          </div>

          <!-- Top Topics -->
          <div class="bg-slate-900/70 border border-slate-800 rounded-lg sm:rounded-xl p-4 sm:p-6">
            <h2 class="text-lg sm:text-xl font-bold text-white mb-3 sm:mb-4">🔥 Топ теми</h2>
            <%= if length(@top_topics) > 0 do %>
              <div class="grid grid-cols-2 sm:grid-cols-2 lg:grid-cols-4 gap-2 sm:gap-3">
                <%= for topic <- @top_topics do %>
                  <div class="bg-slate-800/50 border border-slate-700 rounded-lg p-2 sm:p-3">
                    <p class="text-xs sm:text-sm text-white font-semibold truncate"><%= topic.topic %></p>
                    <p class="text-xl sm:text-2xl font-black text-emerald-400 mt-0.5 sm:mt-1"><%= topic.count %></p>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-sm text-slate-400">Немає тем для відображення</p>
            <% end %>
          </div>

          <!-- Timeline -->
          <div class="bg-slate-900/70 border border-slate-800 rounded-lg sm:rounded-xl p-4 sm:p-6">
            <h2 class="text-lg sm:text-xl font-bold text-white mb-3 sm:mb-4">📊 Живий потік (останні 20)</h2>
            <%= if length(@timeline_data) > 0 do %>
              <div class="space-y-2 sm:space-y-3 max-h-64 sm:max-h-96 overflow-y-auto">
                <%= for feedback <- @timeline_data do %>
                  <div class="bg-slate-800/50 border border-slate-700 rounded-lg p-3 sm:p-4">
                    <div class="flex items-start justify-between gap-2 sm:gap-3">
                      <div class="flex-1 min-w-0">
                        <p class="text-xs sm:text-sm text-slate-300 line-clamp-2"><%= feedback.summary || "Без резюме" %></p>
                        <%= if feedback.employee do %>
                          <p class="text-[10px] sm:text-xs text-slate-500 mt-1">👤 <%= feedback.employee.name %></p>
                        <% end %>
                      </div>
                      <div class="flex flex-col items-end gap-1 flex-shrink-0">
                        <span class={[
                          "px-1.5 sm:px-2 py-0.5 sm:py-1 rounded text-[10px] sm:text-xs font-bold whitespace-nowrap",
                          case feedback.sentiment_label do
                            "positive" -> "bg-green-500/20 text-green-400"
                            "negative" -> "bg-red-500/20 text-red-400"
                            _ -> "bg-slate-500/20 text-slate-400"
                          end
                        ]}>
                          <%= feedback.sentiment_label || "?" %>
                        </span>
                        <p class="text-[10px] sm:text-xs text-slate-500 whitespace-nowrap">
                          <%= Calendar.strftime(feedback.inserted_at, "%d.%m %H:%M") %>
                        </p>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-sm text-slate-400">Немає фідбеків для відображення</p>
            <% end %>
          </div>

          <!-- Risk Register -->
          <div class="bg-slate-900/70 border border-slate-800 rounded-lg sm:rounded-xl p-4 sm:p-6">
            <h2 class="text-lg sm:text-xl font-bold text-white mb-3 sm:mb-4">⚠️ Реєстр ризиків (топ 10)</h2>
            <%= if length(@risk_register) > 0 do %>
              <div class="space-y-2 sm:space-y-3">
                <%= for risk <- @risk_register do %>
                  <div class="bg-red-900/20 border border-red-500/30 rounded-lg p-3 sm:p-4">
                    <div class="flex items-start justify-between gap-2 sm:gap-3">
                      <div class="flex-1 min-w-0">
                        <p class="text-xs sm:text-sm text-white font-semibold line-clamp-2"><%= risk.summary || "Критичний фідбек" %></p>
                        <%= if risk.employee do %>
                          <p class="text-[10px] sm:text-xs text-slate-400 mt-1">👤 <%= risk.employee.name %></p>
                        <% end %>
                      </div>
                      <div class="flex gap-1.5 sm:gap-2 flex-shrink-0">
                        <div class="text-center">
                          <p class="text-[10px] sm:text-xs text-slate-400">U</p>
                          <p class="text-xs sm:text-sm font-bold text-orange-400"><%= Float.round(risk.urgency_score || 0, 2) %></p>
                        </div>
                        <div class="text-center">
                          <p class="text-[10px] sm:text-xs text-slate-400">I</p>
                          <p class="text-xs sm:text-sm font-bold text-red-400"><%= Float.round(risk.impact_score || 0, 2) %></p>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-sm text-green-400">✅ Ризикових фідбеків не виявлено!</p>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
