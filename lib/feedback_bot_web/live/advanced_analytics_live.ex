defmodule FeedbackBotWeb.AdvancedAnalyticsLive do
  use FeedbackBotWeb, :live_view

  alias FeedbackBot.{Feedbacks, Employees}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(FeedbackBot.PubSub, "feedbacks")
    end

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
      |> assign(:employees, Employees.list_active_employees())
      |> load_analytics_data()

    {:ok, socket}
  end

  @impl true
  def handle_event("filter", %{"employee_id" => employee_id, "sentiment" => sentiment, "search" => search}, socket) do
    socket =
      socket
      |> assign(:selected_employee_id, parse_employee_id(employee_id))
      |> assign(:sentiment_filter, sentiment)
      |> assign(:search_term, search)
      |> load_analytics_data()

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
      |> load_analytics_data()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_feedback, _feedback}, socket) do
    {:noreply, load_analytics_data(socket)}
  end

  defp load_analytics_data(socket) do
    filters = build_filters(socket.assigns)
    feedbacks =
      filters
      |> Feedbacks.filter_feedbacks()
      |> filter_by_search(socket.assigns.search_term)
    summary = summarize_feedbacks(feedbacks)
    topic_pareto = topic_pareto(feedbacks)
    volume_sentiment = volume_sentiment(feedbacks)
    sentiment_distribution = sentiment_distribution(feedbacks)
    urgency_distribution = score_distribution(feedbacks, :urgency_score)
    impact_distribution = score_distribution(feedbacks, :impact_score)
    risk_register = risk_register(feedbacks)
    timeline_data = timeline_from_feedbacks(feedbacks)

    socket
    |> assign(:feedbacks, feedbacks)
    |> assign(:summary, summary)
    |> assign(:volume_sentiment, volume_sentiment)
    |> assign(:topic_pareto, topic_pareto)
    |> assign(:sentiment_distribution, sentiment_distribution)
    |> assign(:urgency_distribution, urgency_distribution)
    |> assign(:impact_distribution, impact_distribution)
    |> assign(:risk_register, risk_register)
    |> assign(:heatmap_data, get_heatmap_data(socket.assigns))
    |> assign(:word_cloud_data, Feedbacks.get_word_frequencies(feedbacks))
    |> assign(:timeline_data, timeline_data)
    |> assign(:comparison_data, get_comparison_data(socket.assigns))
    |> assign(:trend_data, get_trend_data(socket.assigns))
  end

  defp build_filters(assigns) do
    filters = %{
      from: assigns.period_start,
      to: assigns.period_end
    }

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

  defp parse_employee_id(""), do: nil
  defp parse_employee_id(id), do: id

  defp filter_by_search(feedbacks, ""), do: feedbacks

  defp filter_by_search(feedbacks, nil), do: feedbacks

  defp filter_by_search(feedbacks, term) do
    normalized = String.downcase(term)

    Enum.filter(feedbacks, fn f ->
      summary_match =
        f.summary && String.contains?(String.downcase(f.summary), normalized)

      transcription_match =
        f.transcription && String.contains?(String.downcase(f.transcription), normalized)

      topic_match =
        (f.topics || [])
        |> Enum.filter(&is_binary/1)
        |> Enum.any?(fn topic -> String.contains?(String.downcase(topic), normalized) end)

      summary_match || transcription_match || topic_match
    end)
  end

  defp get_heatmap_data(assigns) do
    Feedbacks.get_sentiment_heatmap(assigns.period_start, assigns.period_end, :day)
  end

  defp get_comparison_data(assigns) do
    employee_ids = Enum.map(assigns.employees, & &1.id)
    if Enum.empty?(employee_ids) do
      []
    else
      Feedbacks.get_employee_comparison(employee_ids, assigns.period_start, assigns.period_end)
    end
  end

  defp get_trend_data(assigns) do
    if assigns.selected_employee_id do
      Feedbacks.get_sentiment_trend(assigns.selected_employee_id, 30)
    else
      []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-950 text-slate-100">
      <.top_nav active={@active_nav} />

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-8">
        <div class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div>
            <p class="text-xs uppercase tracking-[0.2em] text-slate-400">Deep insight workspace</p>
            <h1 class="text-4xl md:text-5xl font-black tracking-tight text-white">Аналітика 2.0</h1>
            <p class="mt-2 text-slate-400">
              Глибокі тренди, ризики та перемоги команди в одному екрані.
            </p>
          </div>
          <div class="flex gap-3">
            <a href="#heatmap" class="px-4 py-2 rounded-lg border border-slate-700 bg-slate-900 hover:bg-slate-800 text-sm font-semibold">
              Перейти до Heatmap
            </a>
            <a href="#timeline" class="px-4 py-2 rounded-lg bg-emerald-500 text-slate-950 font-bold shadow-lg hover:bg-emerald-400">
              Живий потік
            </a>
          </div>
        </div>

        <!-- Filters -->
        <div class="bg-slate-900/70 border border-slate-800 rounded-2xl p-4">
          <form phx-change="filter">
            <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div>
                <label class="block text-xs uppercase tracking-wide text-slate-400">Співробітник</label>
                <select name="employee_id" class="mt-1 block w-full rounded-lg border border-slate-800 bg-slate-900 text-white focus:border-emerald-500 focus:ring-emerald-500">
                  <option value="">Всі</option>
                  <%= for emp <- @employees do %>
                    <option value={emp.id} selected={emp.id == @selected_employee_id}><%= emp.name %></option>
                  <% end %>
                </select>
              </div>

              <div>
                <label class="block text-xs uppercase tracking-wide text-slate-400">Тональність</label>
                <select name="sentiment" class="mt-1 block w-full rounded-lg border border-slate-800 bg-slate-900 text-white focus:border-emerald-500 focus:ring-emerald-500">
                  <option value="all" selected={@sentiment_filter == "all"}>Всі</option>
                  <option value="positive" selected={@sentiment_filter == "positive"}>Позитивна</option>
                  <option value="neutral" selected={@sentiment_filter == "neutral"}>Нейтральна</option>
                  <option value="negative" selected={@sentiment_filter == "negative"}>Негативна</option>
                </select>
              </div>

              <div>
                <label class="block text-xs uppercase tracking-wide text-slate-400">Пошук</label>
                <input
                  type="text"
                  name="search"
                  value={@search_term}
                  placeholder="Пошук по тексту..."
                  class="mt-1 block w-full rounded-lg border border-slate-800 bg-slate-900 text-white focus:border-emerald-500 focus:ring-emerald-500"
                />
              </div>

              <div>
                <label class="block text-xs uppercase tracking-wide text-slate-400">Період</label>
                <select phx-change="set_period" name="days" class="mt-1 block w-full rounded-lg border border-slate-800 bg-slate-900 text-white focus:border-emerald-500 focus:ring-emerald-500">
                  <option value="7">7 днів</option>
                  <option value="30" selected>30 днів</option>
                  <option value="90">90 днів</option>
                </select>
              </div>
            </div>
          </form>
        </div>

        <!-- KPI Cards -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
          <.kpi_card title="Всього фідбеків" value={@summary.total_feedbacks} accent="emerald" footer="Live processed" />
          <.kpi_card
            title="Середній Sentiment"
            value={format_float(@summary.avg_sentiment)}
            accent="blue"
            footer={"Позитивні: #{format_percent(@summary.positive_share)}"}
          />
          <.kpi_card
            title="Ризики"
            value={@summary.risky_feedbacks}
            accent="red"
            footer={"Негативні: #{format_percent(@summary.negative_share)}"}
          />
          <.kpi_card
            title="Терміновість / Вплив"
            value={"#{format_float(@summary.avg_urgency)} / #{format_float(@summary.avg_impact)}"}
            accent="amber"
            footer="Середні значення 0–1"
          />
        </div>

        <!-- Deep dive layout -->
        <div class="grid grid-cols-1 xl:grid-cols-3 gap-6">
          <div class="xl:col-span-2 space-y-6">
            <div class="bg-slate-900/70 border border-slate-800 rounded-2xl p-6">
              <div class="flex items-center justify-between mb-4">
                <div>
                  <p class="text-xs uppercase tracking-wide text-slate-400">Обʼєм + настрій</p>
                  <h2 class="text-2xl font-black text-white">Pulse за період</h2>
                </div>
                <span class="text-xs text-slate-400">Комбінований графік</span>
              </div>
              <div id="volume-sentiment" class="h-80" phx-hook="VolumeSentimentChart" data-volume-sentiment={Jason.encode!(@volume_sentiment)}></div>
            </div>

            <div id="heatmap" class="bg-slate-900/70 border border-slate-800 rounded-2xl p-6">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-2xl font-black text-white">Heatmap тональності</h2>
                <span class="text-xs text-slate-400">По днях та співробітниках</span>
              </div>
              <div id="heatmap-chart" phx-hook="HeatmapChart" data-heatmap={Jason.encode!(@heatmap_data)}></div>
            </div>

            <%= if @selected_employee_id && length(@trend_data) > 0 do %>
              <div class="bg-slate-900/70 border border-slate-800 rounded-2xl p-6">
                <div class="flex items-center justify-between mb-4">
                  <h2 class="text-2xl font-black text-white">Динаміка обраного</h2>
                  <span class="text-xs text-slate-400">Sentiment / Urgency / Impact</span>
                </div>
                <div id="trend-chart" phx-hook="TrendChart" data-trend={Jason.encode!(@trend_data)}></div>
              </div>
            <% end %>

            <div class="bg-slate-900/70 border border-slate-800 rounded-2xl p-6" id="timeline">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-2xl font-black text-white">Живий потік</h2>
                <span class="text-xs text-slate-400">Останні 20</span>
              </div>
              <div class="space-y-4">
                <%= for item <- Enum.take(@timeline_data, 20) do %>
                  <div class={"border-l-4 pl-4 #{sentiment_border_color(item.sentiment_label)}"}>
                    <div class="flex justify-between items-start">
                      <div>
                        <p class="font-semibold text-white"><%= item.employee_name %></p>
                        <p class="text-xs text-slate-400"><%= Calendar.strftime(item.date, "%d.%m.%Y %H:%M") %></p>
                      </div>
                      <div class="flex gap-2">
                        <span class={"px-2 py-1 text-[11px] rounded #{sentiment_badge_color(item.sentiment_label)}"}>
                          <%= item.sentiment_label %>
                        </span>
                        <%= if item.urgency_score > 0.7 do %>
                          <span class="px-2 py-1 text-[11px] rounded bg-red-500/20 text-red-200 border border-red-500/40">🚨 Терміново</span>
                        <% end %>
                      </div>
                    </div>
                    <p class="text-sm text-slate-200 mt-2"><%= item.summary %></p>
                    <%= if length(item.topics) > 0 do %>
                      <div class="flex flex-wrap gap-1 mt-2">
                        <%= for topic <- item.topics do %>
                          <span class="px-2 py-1 text-[11px] bg-slate-800 border border-slate-700 text-slate-200 rounded-full"><%= topic %></span>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <div class="space-y-6">
            <div class="bg-slate-900/70 border border-slate-800 rounded-2xl p-6">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-xl font-black text-white">Розподіли</h2>
                <span class="text-xs text-slate-400">Стан періоду</span>
              </div>
              <div class="space-y-6">
                <div id="sentiment-distribution-chart" class="h-40" phx-hook="DistributionChart" data-title="Тональність" data-distribution={Jason.encode!(@sentiment_distribution)}></div>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div id="urgency-distribution-chart" class="h-40" phx-hook="DistributionChart" data-title="Терміновість" data-distribution={Jason.encode!(@urgency_distribution)}></div>
                  <div id="impact-distribution-chart" class="h-40" phx-hook="DistributionChart" data-title="Вплив" data-distribution={Jason.encode!(@impact_distribution)}></div>
                </div>
              </div>
            </div>

            <div class="bg-slate-900/70 border border-slate-800 rounded-2xl p-6">
              <div class="flex items-center justify-between mb-3">
                <h2 class="text-xl font-black text-white">Теми та інсайти</h2>
                <span class="text-xs text-slate-400">Top 8</span>
              </div>
              <div id="topic-bar-chart" class="h-60" phx-hook="TopicBarChart" data-topics={Jason.encode!(@topic_pareto)}></div>
              <div class="mt-4">
                <div id="word-cloud" phx-hook="WordCloud" data-words={Jason.encode!(@word_cloud_data)}></div>
              </div>
            </div>

            <div class="bg-slate-900/70 border border-slate-800 rounded-2xl p-6">
              <div class="flex items-center justify-between mb-3">
                <h2 class="text-xl font-black text-white">Ризики</h2>
                <span class="text-xs text-slate-400">Фокус дій</span>
              </div>
              <div class="space-y-3">
                <%= for risk <- @risk_register do %>
                  <div class="flex items-start gap-3 p-3 bg-red-500/10 border border-red-500/30 rounded-lg">
                    <div class="w-2 h-2 mt-1 rounded-full bg-red-400 animate-pulse"></div>
                    <div class="flex-1">
                      <p class="font-semibold text-white"><%= risk.employee %></p>
                      <p class="text-sm text-slate-200"><%= risk.summary %></p>
                      <div class="flex gap-2 mt-2 text-xs text-slate-300">
                        <span class="px-2 py-1 rounded bg-slate-800 border border-slate-700">Urgency: <%= format_float(risk.urgency) %></span>
                        <span class="px-2 py-1 rounded bg-slate-800 border border-slate-700">Impact: <%= format_float(risk.impact) %></span>
                        <span class="px-2 py-1 rounded bg-slate-800 border border-slate-700">Sentiment: <%= format_float(risk.sentiment) %></span>
                      </div>
                    </div>
                  </div>
                <% end %>
                <%= if length(@risk_register) == 0 do %>
                  <p class="text-sm text-slate-400">Ризикових фідбеків не виявлено у вибраному періоді.</p>
                <% end %>
              </div>
            </div>

            <div class="bg-slate-900/70 border border-slate-800 rounded-2xl p-6">
              <h2 class="text-xl font-black text-white mb-3">Порівняння співробітників</h2>
              <div id="comparison-chart" phx-hook="ComparisonChart" data-comparison={Jason.encode!(@comparison_data)}></div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp summarize_feedbacks(feedbacks) do
    total = length(feedbacks)

    {sentiment_sum, urgency_sum, impact_sum, positive, negative} =
      Enum.reduce(feedbacks, {0.0, 0.0, 0.0, 0, 0}, fn f, {s_sum, u_sum, i_sum, pos, neg} ->
        {
          s_sum + (f.sentiment_score || 0.0),
          u_sum + (f.urgency_score || 0.0),
          i_sum + (f.impact_score || 0.0),
          pos + if(f.sentiment_label == "positive", do: 1, else: 0),
          neg + if(f.sentiment_label == "negative", do: 1, else: 0)
        }
      end)

    risky_feedbacks =
      Enum.count(feedbacks, fn f ->
        (f.sentiment_label == "negative" && f.sentiment_score && f.sentiment_score < -0.1) ||
          (f.urgency_score || 0) > 0.7 ||
          (f.impact_score || 0) > 0.7
      end)

    %{
      total_feedbacks: total,
      avg_sentiment: safe_avg(sentiment_sum, total),
      avg_urgency: safe_avg(urgency_sum, total),
      avg_impact: safe_avg(impact_sum, total),
      positive_share: safe_avg(positive, total),
      negative_share: safe_avg(negative, total),
      risky_feedbacks: risky_feedbacks
    }
  end

  defp sentiment_distribution(feedbacks) do
    counts =
      Enum.frequencies_by(feedbacks, fn f -> f.sentiment_label || "unknown" end)

    [
      %{label: "Позитивні", value: Map.get(counts, "positive", 0), color: "#22c55e"},
      %{label: "Нейтральні", value: Map.get(counts, "neutral", 0), color: "#cbd5e1"},
      %{label: "Негативні", value: Map.get(counts, "negative", 0), color: "#ef4444"}
    ]
  end

  defp score_distribution(feedbacks, field) do
    buckets = [
      %{label: "0-0.25", min: 0.0, max: 0.25},
      %{label: "0.25-0.5", min: 0.25, max: 0.5},
      %{label: "0.5-0.75", min: 0.5, max: 0.75},
      %{label: "0.75-1", min: 0.75, max: 1.0}
    ]

    Enum.map(buckets, fn bucket ->
      value =
        Enum.count(feedbacks, fn f ->
          score = Map.get(f, field) || 0.0
          score >= bucket.min && score < bucket.max + 0.00001
        end)

      Map.put(bucket, :value, value)
    end)
  end

  defp topic_pareto(feedbacks) do
    feedbacks
    |> Enum.flat_map(&(&1.topics || []))
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_topic, count} -> count end, :desc)
    |> Enum.take(8)
    |> Enum.map(fn {topic, count} -> %{label: topic, value: count} end)
  end

  defp volume_sentiment(feedbacks) do
    feedbacks
    |> Enum.group_by(fn f -> DateTime.to_date(f.inserted_at) end)
    |> Enum.map(fn {date, list} ->
      count = length(list)
      sentiment_sum = Enum.reduce(list, 0.0, fn f, acc -> acc + (f.sentiment_score || 0.0) end)
      avg_sentiment = safe_avg(sentiment_sum, count)

      %{
        date: date,
        count: count,
        avg_sentiment: avg_sentiment
      }
    end)
    |> Enum.sort_by(& &1.date)
  end

  defp risk_register(feedbacks) do
    feedbacks
    |> Enum.filter(fn f ->
      (f.sentiment_label == "negative" && (f.sentiment_score || 0) < -0.05) ||
        (f.urgency_score || 0) > 0.7 ||
        (f.impact_score || 0) > 0.7
    end)
    |> Enum.sort_by(fn f ->
      -(abs(f.sentiment_score || 0) + (f.urgency_score || 0) * 1.2 + (f.impact_score || 0) * 1.2)
    end)
    |> Enum.take(5)
    |> Enum.map(fn f ->
      %{
        employee: if(f.employee, do: f.employee.name, else: "Невідомо"),
        summary: f.summary || "Без резюме",
        sentiment: f.sentiment_score || 0.0,
        urgency: f.urgency_score || 0.0,
        impact: f.impact_score || 0.0
      }
    end)
  end

  defp timeline_from_feedbacks(feedbacks) do
    feedbacks
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
    |> Enum.map(fn f ->
      %{
        id: f.id,
        date: f.inserted_at,
        employee_name: if(f.employee, do: f.employee.name, else: "Невідомо"),
        employee_id: f.employee_id,
        sentiment_score: f.sentiment_score,
        sentiment_label: f.sentiment_label,
        urgency_score: f.urgency_score,
        impact_score: f.impact_score,
        summary: f.summary,
        topics: f.topics || []
      }
    end)
  end

  defp format_float(value) when is_float(value), do: Float.round(value, 2)
  defp format_float(value) when is_integer(value), do: value
  defp format_float(_), do: 0

  defp format_percent(value) when is_number(value), do: "#{Float.round(value * 100, 1)}%"
  defp format_percent(_), do: "0%"

  defp safe_avg(_sum, 0), do: 0.0
  defp safe_avg(sum, total), do: sum / total

  defp sentiment_border_color("positive"), do: "border-green-500"
  defp sentiment_border_color("neutral"), do: "border-gray-500"
  defp sentiment_border_color("negative"), do: "border-red-500"

  defp sentiment_badge_color("positive"), do: "bg-green-100 text-green-800"
  defp sentiment_badge_color("neutral"), do: "bg-gray-100 text-gray-800"
  defp sentiment_badge_color("negative"), do: "bg-red-100 text-red-800"

  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :footer, :string, default: nil
  attr :accent, :string, default: "emerald"

  defp kpi_card(assigns) do
    colors = %{
      "emerald" => "from-emerald-400/20 via-emerald-500/10 to-emerald-900/20 border-emerald-500/40 text-emerald-100",
      "blue" => "from-sky-400/20 via-sky-500/10 to-sky-900/20 border-sky-500/40 text-sky-100",
      "red" => "from-rose-400/20 via-rose-500/10 to-rose-900/20 border-rose-500/40 text-rose-100",
      "amber" => "from-amber-400/20 via-amber-500/10 to-amber-900/20 border-amber-500/40 text-amber-100"
    }

    assigns = assign(assigns, :accent_classes, Map.get(colors, assigns.accent, colors["emerald"]))

    ~H"""
    <div class={["rounded-2xl border p-4 bg-gradient-to-br", @accent_classes]}>
      <p class="text-xs uppercase tracking-wide text-slate-200/80"><%= @title %></p>
      <p class="text-3xl font-black text-white mt-2 leading-none"><%= @value %></p>
      <%= if @footer do %>
        <p class="text-xs text-slate-200/70 mt-2"><%= @footer %></p>
      <% end %>
    </div>
    """
  end
end
