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

    socket
    |> assign(:feedbacks, Feedbacks.filter_feedbacks(filters))
    |> assign(:heatmap_data, get_heatmap_data(socket.assigns))
    |> assign(:word_cloud_data, Feedbacks.get_word_frequencies(filters))
    |> assign(:timeline_data, get_timeline_data(socket.assigns))
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

  defp get_heatmap_data(assigns) do
    Feedbacks.get_sentiment_heatmap(assigns.period_start, assigns.period_end, :day)
  end

  defp get_timeline_data(assigns) do
    Feedbacks.get_timeline_data(assigns.period_start, assigns.period_end)
  end

  defp get_comparison_data(assigns) do
    employee_ids = Enum.map(assigns.employees, & &1.id)
    Feedbacks.get_employee_comparison(employee_ids, assigns.period_start, assigns.period_end)
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
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <h1 class="text-3xl font-bold mb-8">📊 Розширена Аналітика</h1>

      <!-- Filters -->
      <div class="bg-white rounded-lg shadow p-6 mb-8">
        <form phx-change="filter">
          <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700">Співробітник</label>
              <select name="employee_id" class="mt-1 block w-full rounded-md border-gray-300">
                <option value="">Всі</option>
                <%= for emp <- @employees do %>
                  <option value={emp.id} selected={emp.id == @selected_employee_id}><%= emp.name %></option>
                <% end %>
              </select>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700">Тональність</label>
              <select name="sentiment" class="mt-1 block w-full rounded-md border-gray-300">
                <option value="all" selected={@sentiment_filter == "all"}>Всі</option>
                <option value="positive" selected={@sentiment_filter == "positive"}>Позитивна</option>
                <option value="neutral" selected={@sentiment_filter == "neutral"}>Нейтральна</option>
                <option value="negative" selected={@sentiment_filter == "negative"}>Негативна</option>
              </select>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700">Пошук</label>
              <input
                type="text"
                name="search"
                value={@search_term}
                placeholder="Пошук по тексту..."
                class="mt-1 block w-full rounded-md border-gray-300"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700">Період</label>
              <select phx-change="set_period" name="days" class="mt-1 block w-full rounded-md border-gray-300">
                <option value="7">7 днів</option>
                <option value="30" selected>30 днів</option>
                <option value="90">90 днів</option>
              </select>
            </div>
          </div>
        </form>
      </div>

      <!-- Stats Cards -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="text-sm font-medium text-gray-500">Всього фідбеків</h3>
          <p class="text-3xl font-bold text-gray-900"><%= length(@feedbacks) %></p>
        </div>
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="text-sm font-medium text-gray-500">Середній Sentiment</h3>
          <p class="text-3xl font-bold text-gray-900">
            <%= format_sentiment_avg(@feedbacks) %>
          </p>
        </div>
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="text-sm font-medium text-gray-500">Середня Терміновість</h3>
          <p class="text-3xl font-bold text-gray-900">
            <%= format_urgency_avg(@feedbacks) %>
          </p>
        </div>
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="text-sm font-medium text-gray-500">Середній Вплив</h3>
          <p class="text-3xl font-bold text-gray-900">
            <%= format_impact_avg(@feedbacks) %>
          </p>
        </div>
      </div>

      <!-- Heatmap -->
      <div class="bg-white rounded-lg shadow p-6 mb-8">
        <h2 class="text-xl font-bold mb-4">🔥 Heatmap: Sentiment по часу</h2>
        <div id="heatmap-chart" phx-hook="HeatmapChart" data-heatmap={Jason.encode!(@heatmap_data)}></div>
      </div>

      <!-- Trend Lines -->
      <%= if @selected_employee_id && length(@trend_data) > 0 do %>
        <div class="bg-white rounded-lg shadow p-6 mb-8">
          <h2 class="text-xl font-bold mb-4">📈 Динаміка змін</h2>
          <div id="trend-chart" phx-hook="TrendChart" data-trend={Jason.encode!(@trend_data)}></div>
        </div>
      <% end %>

      <!-- Comparison Chart -->
      <div class="bg-white rounded-lg shadow p-6 mb-8">
        <h2 class="text-xl font-bold mb-4">⚖️ Порівняння співробітників</h2>
        <div id="comparison-chart" phx-hook="ComparisonChart" data-comparison={Jason.encode!(@comparison_data)}></div>
      </div>

      <!-- Word Cloud -->
      <div class="bg-white rounded-lg shadow p-6 mb-8">
        <h2 class="text-xl font-bold mb-4">☁️ Word Cloud</h2>
        <div id="word-cloud" phx-hook="WordCloud" data-words={Jason.encode!(@word_cloud_data)}></div>
      </div>

      <!-- Timeline -->
      <div class="bg-white rounded-lg shadow p-6">
        <h2 class="text-xl font-bold mb-4">⏱️ Хронологія фідбеків</h2>
        <div class="space-y-4">
          <%= for item <- Enum.take(@timeline_data, 20) do %>
            <div class="border-l-4 pl-4 <%= sentiment_border_color(item.sentiment_label) %>">
              <div class="flex justify-between items-start">
                <div>
                  <p class="font-medium"><%= item.employee_name %></p>
                  <p class="text-sm text-gray-600"><%= Calendar.strftime(item.date, "%d.%m.%Y %H:%M") %></p>
                </div>
                <div class="flex gap-2">
                  <span class="px-2 py-1 text-xs rounded <%= sentiment_badge_color(item.sentiment_label) %>">
                    <%= item.sentiment_label %>
                  </span>
                  <%= if item.urgency_score > 0.7 do %>
                    <span class="px-2 py-1 text-xs rounded bg-red-100 text-red-800">🚨 Терміново</span>
                  <% end %>
                </div>
              </div>
              <p class="text-sm mt-2"><%= item.summary %></p>
              <%= if length(item.topics) > 0 do %>
                <div class="flex gap-1 mt-2">
                  <%= for topic <- item.topics do %>
                    <span class="px-2 py-1 text-xs bg-gray-100 text-gray-700 rounded"><%= topic %></span>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp format_sentiment_avg(feedbacks) when length(feedbacks) > 0 do
    avg = Enum.map(feedbacks, & &1.sentiment_score) |> Enum.sum() |> Kernel./(length(feedbacks))
    Float.round(avg, 2)
  end
  defp format_sentiment_avg(_), do: "N/A"

  defp format_urgency_avg(feedbacks) when length(feedbacks) > 0 do
    avg = Enum.map(feedbacks, & &1.urgency_score) |> Enum.sum() |> Kernel./(length(feedbacks))
    Float.round(avg, 2)
  end
  defp format_urgency_avg(_), do: "N/A"

  defp format_impact_avg(feedbacks) when length(feedbacks) > 0 do
    avg = Enum.map(feedbacks, & &1.impact_score) |> Enum.sum() |> Kernel./(length(feedbacks))
    Float.round(avg, 2)
  end
  defp format_impact_avg(_), do: "N/A"

  defp sentiment_border_color("positive"), do: "border-green-500"
  defp sentiment_border_color("neutral"), do: "border-gray-500"
  defp sentiment_border_color("negative"), do: "border-red-500"

  defp sentiment_badge_color("positive"), do: "bg-green-100 text-green-800"
  defp sentiment_badge_color("neutral"), do: "bg-gray-100 text-gray-800"
  defp sentiment_badge_color("negative"), do: "bg-red-100 text-red-800"
end
