defmodule FeedbackBotWeb.AnalyticsPeriodLive do
  use FeedbackBotWeb, :live_view

  alias FeedbackBot.Analytics

  @impl true
  def mount(%{"period_type" => period_type}, _session, socket) do
    latest = Analytics.get_latest_snapshot(period_type)

    comparison =
      if latest do
        Analytics.compare_periods(latest.id)
      else
        nil
      end

    socket =
      socket
      |> assign(:page_title, "Аналітика: #{format_period_type(period_type)}")
      |> assign(:active_nav, "/analytics/basic")
      |> assign(:period_type, period_type)
      |> assign(:snapshot, latest)
      |> assign(:comparison, comparison)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-50">
      <.top_nav active={@active_nav} />
      <header class="border-b-4 border-black bg-white">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <.link navigate="/analytics" class="text-sm font-bold hover:underline mb-2 inline-block">
            ← Назад
          </.link>
          <h1 class="text-5xl font-black uppercase tracking-tight">
            <%= format_period_type(@period_type) %>
          </h1>
        </div>
      </header>

      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%= if @snapshot do %>
          <div class="space-y-6">
            <!-- Comparison with previous period -->
            <%= if @comparison do %>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div class="neo-brutal-card">
                  <h2 class="text-lg font-black uppercase mb-4">Поточний Період</h2>
                  <.period_card snapshot={@comparison.current} />
                </div>
                <%= if @comparison.previous do %>
                  <div class="neo-brutal-card bg-gray-50">
                    <h2 class="text-lg font-black uppercase mb-4">Попередній Період</h2>
                    <.period_card snapshot={@comparison.previous} />
                  </div>
                <% end %>
              </div>

              <!-- Changes -->
              <div class="neo-brutal-card bg-blue-50">
                <h2 class="text-2xl font-black uppercase mb-4">Зміни</h2>
                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <p class="text-sm font-bold">Зміна тональності</p>
                    <p class={[
                      "text-3xl font-black",
                      if(@comparison.sentiment_change > 0,
                        do: "text-green-600",
                        else: "text-red-600"
                      )
                    ]}>
                      <%= if @comparison.sentiment_change > 0, do: "+", else: "" %><%= Float.round(
                        @comparison.sentiment_change,
                        2
                      ) %>
                    </p>
                  </div>
                  <div>
                    <p class="text-sm font-bold">Зміна кількості фідбеків</p>
                    <p class={[
                      "text-3xl font-black",
                      if(@comparison.feedback_count_change > 0,
                        do: "text-blue-600",
                        else: "text-gray-600"
                      )
                    ]}>
                      <%= if @comparison.feedback_count_change > 0, do: "+", else: "" %><%= @comparison.feedback_count_change %>
                    </p>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="neo-brutal-card text-center bg-yellow-100">
            <p class="text-xl font-black">Немає даних для цього періоду</p>
            <p class="mt-2">Дані зʼявляться після першого аналізу</p>
          </div>
        <% end %>
      </main>
    </div>
    """
  end

  attr :snapshot, :map, required: true

  defp period_card(assigns) do
    ~H"""
    <div class="space-y-3">
      <div>
        <p class="text-sm text-gray-600">Всього фідбеків</p>
        <p class="text-3xl font-black"><%= @snapshot.total_feedbacks %></p>
      </div>
      <div>
        <p class="text-sm text-gray-600">Середня тональність</p>
        <p class="text-3xl font-black"><%= Float.round(@snapshot.avg_sentiment, 2) %></p>
      </div>
      <div class="grid grid-cols-3 gap-2">
        <div class="p-2 bg-green-100 border-2 border-black text-center">
          <p class="text-xs font-bold">+</p>
          <p class="text-lg font-black"><%= @snapshot.positive_count %></p>
        </div>
        <div class="p-2 bg-gray-100 border-2 border-black text-center">
          <p class="text-xs font-bold">~</p>
          <p class="text-lg font-black"><%= @snapshot.neutral_count %></p>
        </div>
        <div class="p-2 bg-red-100 border-2 border-black text-center">
          <p class="text-xs font-bold">-</p>
          <p class="text-lg font-black"><%= @snapshot.negative_count %></p>
        </div>
      </div>
    </div>
    """
  end

  defp format_period_type("daily"), do: "Щоденна Аналітика"
  defp format_period_type("weekly"), do: "Тижнева Аналітика"
  defp format_period_type("monthly"), do: "Місячна Аналітика"
  defp format_period_type(_), do: "Аналітика"
end
