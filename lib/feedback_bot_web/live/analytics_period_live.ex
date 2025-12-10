defmodule FeedbackBotWeb.AnalyticsPeriodLive do
  use FeedbackBotWeb, :live_view
  require Logger

  alias FeedbackBot.Analytics

  @impl true
  def mount(%{"period_type" => period_type}, _session, socket) do
    try do
      latest = Analytics.get_latest_snapshot(period_type)

      socket =
        socket
        |> assign(:page_title, "Аналітика: #{format_period_type(period_type)}")
        |> assign(:active_nav, "/analytics/basic")
        |> assign(:period_type, period_type)
        |> assign(:snapshot, latest)
        |> assign(:error, nil)

      {:ok, socket}
    rescue
      e ->
        Logger.error("AnalyticsPeriodLive mount error: #{inspect(e)}")

        socket =
          socket
          |> assign(:page_title, "Аналітика: Зрізи")
          |> assign(:active_nav, "/analytics/basic")
          |> assign(:period_type, period_type)
          |> assign(:snapshot, nil)
          |> assign(:error, "Помилка: #{Exception.message(e)}")

        {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-950 text-slate-100">
      <.top_nav active={@active_nav} />

      <div class="max-w-7xl mx-auto px-3 sm:px-4 lg:px-8 py-4 sm:py-8">
        <div class="mb-4 sm:mb-6">
          <.link navigate="/analytics/basic" class="text-sm text-emerald-400 hover:text-emerald-300 font-semibold">
            ← Назад до аналітики
          </.link>
        </div>

        <div class="mb-6 sm:mb-8">
          <h1 class="text-3xl sm:text-4xl lg:text-5xl font-black text-white">
            <%= format_period_type(@period_type) %>
          </h1>
          <p class="text-slate-400 mt-2">Детальний зріз по періоду</p>
        </div>

        <%= if @error do %>
          <div class="bg-red-900/30 border border-red-500 rounded-xl p-4 mb-6">
            <h3 class="text-xl font-bold text-red-400">Помилка</h3>
            <p class="text-sm text-red-300 mt-2"><%= @error %></p>
          </div>
        <% end %>

        <%= if @snapshot do %>
          <div class="space-y-4 sm:space-y-6">
            <!-- Period Info -->
            <div class="bg-slate-900/70 border border-slate-800 rounded-xl p-4 sm:p-6">
              <h2 class="text-lg sm:text-xl font-bold text-white mb-3 sm:mb-4">Інформація про період</h2>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-4">
                <div>
                  <p class="text-xs text-slate-400">Початок періоду</p>
                  <p class="text-base sm:text-lg font-bold text-white">
                    <%= Calendar.strftime(@snapshot.period_start, "%d.%m.%Y %H:%M") %>
                  </p>
                </div>
                <div>
                  <p class="text-xs text-slate-400">Кінець періоду</p>
                  <p class="text-base sm:text-lg font-bold text-white">
                    <%= Calendar.strftime(@snapshot.period_end, "%d.%m.%Y %H:%M") %>
                  </p>
                </div>
              </div>
            </div>

            <!-- Summary Stats -->
            <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
              <div class="bg-gradient-to-br from-emerald-500/20 to-emerald-900/20 border border-emerald-500/40 rounded-xl p-3 sm:p-4">
                <p class="text-xs uppercase tracking-wide text-slate-200/80">Всього фідбеків</p>
                <p class="text-2xl sm:text-3xl font-black text-white mt-1 sm:mt-2">
                  <%= @snapshot.data["total_feedbacks"] || 0 %>
                </p>
              </div>

              <div class="bg-gradient-to-br from-blue-500/20 to-blue-900/20 border border-blue-500/40 rounded-xl p-3 sm:p-4">
                <p class="text-xs uppercase tracking-wide text-slate-200/80">Середній Sentiment</p>
                <p class="text-2xl sm:text-3xl font-black text-white mt-1 sm:mt-2">
                  <%= Float.round(@snapshot.data["avg_sentiment"] || 0.0, 2) %>
                </p>
              </div>

              <div class="bg-gradient-to-br from-green-500/20 to-green-900/20 border border-green-500/40 rounded-xl p-3 sm:p-4">
                <p class="text-xs uppercase tracking-wide text-slate-200/80">Позитивні</p>
                <p class="text-2xl sm:text-3xl font-black text-white mt-1 sm:mt-2">
                  <%= @snapshot.data["positive_count"] || 0 %>
                </p>
              </div>

              <div class="bg-gradient-to-br from-red-500/20 to-red-900/20 border border-red-500/40 rounded-xl p-3 sm:p-4">
                <p class="text-xs uppercase tracking-wide text-slate-200/80">Негативні</p>
                <p class="text-2xl sm:text-3xl font-black text-white mt-1 sm:mt-2">
                  <%= @snapshot.data["negative_count"] || 0 %>
                </p>
              </div>
            </div>

            <!-- Top Issues -->
            <%= if @snapshot.data["top_issues"] && length(@snapshot.data["top_issues"]) > 0 do %>
              <div class="bg-slate-900/70 border border-slate-800 rounded-xl p-4 sm:p-6">
                <h2 class="text-lg sm:text-xl font-bold text-white mb-3 sm:mb-4">Топ проблеми</h2>
                <div class="space-y-2 sm:space-y-3">
                  <%= for issue <- Enum.take(@snapshot.data["top_issues"], 5) do %>
                    <div class="bg-slate-800/50 border border-slate-700 rounded-lg p-3">
                      <p class="text-sm sm:text-base text-white font-semibold">
                        <%= issue["description"] %>
                      </p>
                      <p class="text-xs sm:text-sm text-slate-400 mt-1">
                        Згадувань: <span class="text-red-400 font-bold"><%= issue["count"] %></span>
                      </p>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="bg-slate-900/70 border border-slate-800 rounded-xl p-6 text-center">
            <p class="text-xl text-slate-400">Немає даних для цього періоду</p>
            <p class="text-sm text-slate-500 mt-2">
              Спробуйте пізніше або оберіть інший період
            </p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_period_type("daily"), do: "Денний зріз"
  defp format_period_type("weekly"), do: "Тижневий зріз"
  defp format_period_type("monthly"), do: "Місячний зріз"
  defp format_period_type(_), do: "Аналітичний зріз"
end
