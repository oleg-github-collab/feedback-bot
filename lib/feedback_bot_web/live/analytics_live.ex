defmodule FeedbackBotWeb.AnalyticsLive do
  use FeedbackBotWeb, :live_view
  require Logger

  alias FeedbackBot.Analytics

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("AnalyticsLive: Mount started")

    # Безпечне завантаження даних
    {daily, weekly, monthly} =
      try do
        d = Analytics.list_snapshots("daily", limit: 30) || []
        w = Analytics.list_snapshots("weekly", limit: 12) || []
        m = Analytics.list_snapshots("monthly", limit: 6) || []
        Logger.info("Loaded snapshots: daily=#{length(d)}, weekly=#{length(w)}, monthly=#{length(m)}")
        {d, w, m}
      rescue
        e ->
          Logger.error("Error loading snapshots: #{inspect(e)}")
          {[], [], []}
      end

    socket =
      socket
      |> assign(:page_title, "Аналітика - Зрізи")
      |> assign(:active_nav, "/analytics/basic")
      |> assign(:daily_snapshots, daily)
      |> assign(:weekly_snapshots, weekly)
      |> assign(:monthly_snapshots, monthly)
      |> assign(:selected_period, "weekly")
      |> assign(:error, nil)

    Logger.info("AnalyticsLive: Mount completed")
    {:ok, socket}
  end

  @impl true
  def handle_event("select_period", %{"period" => period}, socket) do
    {:noreply, assign(socket, :selected_period, period)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-950 text-slate-100">
      <.top_nav active={@active_nav} />

      <div class="max-w-7xl mx-auto px-3 sm:px-4 lg:px-8 py-4 sm:py-6 lg:py-8">
        <div class="mb-4 sm:mb-6">
          <.link navigate="/" class="text-sm text-emerald-400 hover:text-emerald-300 font-semibold">
            ← Назад до дашборду
          </.link>
        </div>

        <div class="mb-6 sm:mb-8">
          <h1 class="text-3xl sm:text-4xl lg:text-5xl font-black text-white">Аналітичні зрізи</h1>
          <p class="text-xs sm:text-sm text-slate-400 mt-2">Історичні snapshot'и по періодах</p>
        </div>

        <%= if @error do %>
          <div class="bg-red-900/30 border border-red-500 rounded-xl p-4 mb-6">
            <h3 class="text-xl font-bold text-red-400">Помилка</h3>
            <p class="text-sm text-red-300 mt-2"><%= @error %></p>
          </div>
        <% end %>
          <!-- Period Selector -->
          <div class="flex flex-wrap gap-2 sm:gap-3 mb-6 sm:mb-8">
            <button
              phx-click="select_period"
              phx-value-period="daily"
              class={[
                "px-4 sm:px-6 py-2 sm:py-3 rounded-lg font-bold text-sm sm:text-base border-2 transition-all",
                if(@selected_period == "daily",
                  do: "bg-emerald-500 border-emerald-400 text-white shadow-lg",
                  else: "bg-slate-800 border-slate-700 text-slate-300 hover:border-emerald-500"
                )
              ]}
            >
              📅 Щоденна
            </button>
            <button
              phx-click="select_period"
              phx-value-period="weekly"
              class={[
                "px-4 sm:px-6 py-2 sm:py-3 rounded-lg font-bold text-sm sm:text-base border-2 transition-all",
                if(@selected_period == "weekly",
                  do: "bg-emerald-500 border-emerald-400 text-white shadow-lg",
                  else: "bg-slate-800 border-slate-700 text-slate-300 hover:border-emerald-500"
                )
              ]}
            >
              📊 Тижнева
            </button>
            <button
              phx-click="select_period"
              phx-value-period="monthly"
              class={[
                "px-4 sm:px-6 py-2 sm:py-3 rounded-lg font-bold text-sm sm:text-base border-2 transition-all",
                if(@selected_period == "monthly",
                  do: "bg-emerald-500 border-emerald-400 text-white shadow-lg",
                  else: "bg-slate-800 border-slate-700 text-slate-300 hover:border-emerald-500"
                )
              ]}
            >
              📈 Місячна
            </button>
          </div>

          <!-- Snapshots Display -->
          <%= if @selected_period == "daily" do %>
            <.snapshots_section snapshots={@daily_snapshots} period_name="Щоденні зрізи" />
          <% end %>

          <%= if @selected_period == "weekly" do %>
            <.snapshots_section snapshots={@weekly_snapshots} period_name="Тижневі зрізи" />
          <% end %>

          <%= if @selected_period == "monthly" do %>
            <.snapshots_section snapshots={@monthly_snapshots} period_name="Місячні зрізи" />
          <% end %>
      </div>
    </div>
    """
  end

  defp snapshots_section(assigns) do
    ~H"""
    <div class="space-y-4 sm:space-y-6">
      <h2 class="text-xl sm:text-2xl font-bold text-white"><%= @period_name %></h2>

      <%= if length(@snapshots) > 0 do %>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6">
          <%= for snapshot <- @snapshots do %>
            <.snapshot_card snapshot={snapshot} />
          <% end %>
        </div>
      <% else %>
        <div class="bg-slate-900/70 border border-slate-800 rounded-xl p-8 text-center">
          <p class="text-xl text-slate-400">Немає даних для цього періоду</p>
          <p class="text-sm text-slate-500 mt-2">
            Snapshot'и створюються автоматично через певний час
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  defp snapshot_card(assigns) do
    ~H"""
    <div class="bg-slate-900/70 border border-slate-800 rounded-lg sm:rounded-xl p-4 sm:p-6 hover:border-emerald-500/50 transition-all">
      <!-- Period Header -->
      <div class="mb-4">
        <p class="text-xs text-slate-400">Період</p>
        <p class="text-sm sm:text-base font-bold text-white">
          <%= Calendar.strftime(@snapshot.period_start, "%d.%m.%Y") %> -
          <%= Calendar.strftime(@snapshot.period_end, "%d.%m.%Y") %>
        </p>
      </div>

      <!-- Stats Grid -->
      <div class="grid grid-cols-2 gap-3 sm:gap-4 mb-4">
        <div class="bg-slate-800/50 rounded-lg p-3">
          <p class="text-xs text-slate-400">Всього фідбеків</p>
          <p class="text-xl sm:text-2xl font-black text-emerald-400">
            <%= @snapshot.total_feedbacks || 0 %>
          </p>
        </div>

        <div class="bg-slate-800/50 rounded-lg p-3">
          <p class="text-xs text-slate-400">Середній Sentiment</p>
          <p class="text-xl sm:text-2xl font-black text-blue-400">
            <%= if @snapshot.avg_sentiment, do: Float.round(@snapshot.avg_sentiment, 2), else: 0.0 %>
          </p>
        </div>

        <div class="bg-slate-800/50 rounded-lg p-3">
          <p class="text-xs text-slate-400">Позитивні</p>
          <p class="text-xl sm:text-2xl font-black text-green-400">
            <%= @snapshot.positive_count || 0 %>
          </p>
        </div>

        <div class="bg-slate-800/50 rounded-lg p-3">
          <p class="text-xs text-slate-400">Негативні</p>
          <p class="text-xl sm:text-2xl font-black text-red-400">
            <%= @snapshot.negative_count || 0 %>
          </p>
        </div>
      </div>

      <!-- View Details Link -->
      <.link
        navigate={~p"/analytics/#{@snapshot.period_type}"}
        class="inline-block w-full text-center px-4 py-2 bg-emerald-500 hover:bg-emerald-600 text-white font-bold rounded-lg transition-colors text-sm"
      >
        Переглянути деталі →
      </.link>
    </div>
    """
  end
end
