defmodule FeedbackBotWeb.AdvancedAnalyticsLive do
  use FeedbackBotWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Аналітика 2.0")
      |> assign(:active_nav, "/analytics")
      |> assign(:error, nil)

    {:ok, socket}
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

          <div class="bg-slate-900/70 border border-slate-800 rounded-xl p-6">
            <h2 class="text-2xl font-bold text-white mb-4">Статус</h2>
            <p class="text-green-400">✅ Сторінка завантажилась успішно!</p>
            <p class="text-slate-300 mt-2">Функціонал додається...</p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
