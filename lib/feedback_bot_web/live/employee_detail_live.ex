defmodule FeedbackBotWeb.EmployeeDetailLive do
  use FeedbackBotWeb, :live_view

  alias FeedbackBot.{Employees, Feedbacks}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    employee = Employees.get_employee!(id)
    feedbacks = Feedbacks.list_feedbacks(employee_id: id, limit: 20)

    # Статистика за різні періоди
    stats_30d = Employees.get_employee_stats(id, from: days_ago(30))
    stats_7d = Employees.get_employee_stats(id, from: days_ago(7))
    stats_all = Employees.get_employee_stats(id)

    socket =
      socket
      |> assign(:page_title, "Деталі: #{employee.name}")
      |> assign(:active_nav, "/employees")
      |> assign(:employee, employee)
      |> assign(:feedbacks, feedbacks)
      |> assign(:stats_30d, stats_30d)
      |> assign(:stats_7d, stats_7d)
      |> assign(:stats_all, stats_all)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-50">
      <.top_nav active={@active_nav} />
      <header class="border-b-4 border-black bg-white">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <.link navigate="/employees" class="text-sm font-bold hover:underline mb-2 inline-block">
            ← Назад до списку
          </.link>
          <h1 class="text-5xl font-black uppercase tracking-tight">
            <%= @employee.name %>
          </h1>
          <%= if @employee.email do %>
            <p class="mt-2 text-lg font-bold text-gray-600"><%= @employee.email %></p>
          <% end %>
        </div>
      </header>

      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <!-- Статистика -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <.stats_card title="За 7 днів" stats={@stats_7d} />
          <.stats_card title="За 30 днів" stats={@stats_30d} />
          <.stats_card title="Весь час" stats={@stats_all} />
        </div>

        <!-- Топ проблеми та сильні сторони -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
          <%= if length(@stats_30d.top_issues) > 0 do %>
            <div class="neo-brutal-card">
              <h2 class="text-2xl font-black uppercase mb-4">Топ Проблеми (30 днів)</h2>
              <div class="space-y-2">
                <%= for {{desc, count}, idx} <- Enum.with_index(@stats_30d.top_issues, 1) do %>
                  <div class="flex items-center gap-3">
                    <span class="flex-shrink-0 w-6 h-6 bg-black text-white font-bold text-sm flex items-center justify-center">
                      <%= idx %>
                    </span>
                    <div class="flex-1">
                      <p class="font-medium text-sm"><%= desc %></p>
                    </div>
                    <span class="text-sm font-black"><%= count %>×</span>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <%= if length(@stats_30d.top_strengths) > 0 do %>
            <div class="neo-brutal-card bg-green-50">
              <h2 class="text-2xl font-black uppercase mb-4">Сильні Сторони (30 днів)</h2>
              <div class="space-y-2">
                <%= for {{strength, count}, idx} <- Enum.with_index(@stats_30d.top_strengths, 1) do %>
                  <div class="flex items-center gap-3">
                    <span class="flex-shrink-0 w-6 h-6 bg-green-600 text-white font-bold text-sm flex items-center justify-center">
                      <%= idx %>
                    </span>
                    <div class="flex-1">
                      <p class="font-medium text-sm"><%= strength %></p>
                    </div>
                    <span class="text-sm font-black"><%= count %>×</span>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Останні фідбеки -->
        <div class="neo-brutal-card">
          <h2 class="text-2xl font-black uppercase mb-4">Останні Фідбеки</h2>
          <div class="space-y-4">
            <%= for feedback <- @feedbacks do %>
              <div class="border-2 border-black p-4 bg-white">
                <div class="flex justify-between items-start mb-3">
                  <p class="text-sm text-gray-600">
                    <%= Calendar.strftime(feedback.inserted_at, "%d.%m.%Y о %H:%M") %>
                  </p>
                  <span class={[
                    "px-2 py-1 text-xs font-black uppercase border-2 border-black",
                    case feedback.sentiment_label do
                      "positive" -> "bg-green-300"
                      "negative" -> "bg-red-300"
                      _ -> "bg-gray-300"
                    end
                  ]}>
                    <%= feedback.sentiment_label %>
                  </span>
                </div>
                <p class="text-sm"><%= feedback.summary %></p>
              </div>
            <% end %>
          </div>
        </div>
      </main>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :stats, :map, required: true

  defp stats_card(assigns) do
    ~H"""
    <div class="neo-brutal-card">
      <h3 class="text-sm font-black uppercase text-gray-600"><%= @title %></h3>
      <p class="text-4xl font-black mt-2"><%= @stats.total_feedbacks %></p>
      <p class="text-sm mt-1">фідбеків</p>

      <div class="mt-4 pt-4 border-t-2 border-black">
        <div class="flex justify-between items-center mb-2">
          <span class="text-xs font-bold">Тональність:</span>
          <span class={[
            "text-lg font-black",
            sentiment_color(@stats.avg_sentiment)
          ]}>
            <%= Float.round(@stats.avg_sentiment, 2) %>
          </span>
        </div>

        <%= if map_size(@stats.sentiment_distribution) > 0 do %>
          <div class="space-y-1 mt-3">
            <%= for {label, count} <- @stats.sentiment_distribution do %>
              <div class="flex justify-between text-xs">
                <span class="font-bold capitalize"><%= label %>:</span>
                <span><%= count %></span>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp sentiment_color(sentiment) when sentiment > 0.3, do: "text-green-600"
  defp sentiment_color(sentiment) when sentiment < -0.3, do: "text-red-600"
  defp sentiment_color(_), do: "text-gray-600"

  defp days_ago(days) do
    DateTime.utc_now()
    |> DateTime.add(-days, :day)
  end
end
