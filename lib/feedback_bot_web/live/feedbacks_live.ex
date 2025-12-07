defmodule FeedbackBotWeb.FeedbacksLive do
  use FeedbackBotWeb, :live_view

  alias FeedbackBot.Feedbacks

  @impl true
  def mount(_params, _session, socket) do
    feedbacks = Feedbacks.list_feedbacks(limit: 50)

    socket =
      socket
      |> assign(:page_title, "Фідбеки")
      |> assign(:feedbacks, feedbacks)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-50">
      <header class="border-b-4 border-black bg-white">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <.link navigate="/" class="text-sm font-bold hover:underline mb-2 inline-block">
            ← Назад
          </.link>
          <h1 class="text-5xl font-black uppercase tracking-tight">
            Фідбеки
          </h1>
        </div>
      </header>

      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="space-y-4">
          <%= for feedback <- @feedbacks do %>
            <div class="neo-brutal-card">
              <div class="flex justify-between items-start mb-4">
                <div class="flex-1">
                  <h3 class="text-xl font-black"><%= feedback.employee.name %></h3>
                  <p class="text-sm text-gray-600">
                    <%= Calendar.strftime(feedback.inserted_at, "%d.%m.%Y о %H:%M") %>
                  </p>
                </div>
                <span class={[
                  "px-3 py-1 text-sm font-black uppercase border-2 border-black",
                  case feedback.sentiment_label do
                    "positive" -> "bg-green-300"
                    "negative" -> "bg-red-300"
                    _ -> "bg-gray-300"
                  end
                ]}>
                  <%= sentiment_emoji(feedback.sentiment_label) %>
                  <%= feedback.sentiment_label %>
                  (<%= Float.round(feedback.sentiment_score, 2) %>)
                </span>
              </div>

              <div class="space-y-3">
                <div>
                  <h4 class="font-black text-sm uppercase mb-2">Резюме:</h4>
                  <p class="text-sm"><%= feedback.summary %></p>
                </div>

                <%= if length(feedback.key_points) > 0 do %>
                  <div>
                    <h4 class="font-black text-sm uppercase mb-2">Ключові моменти:</h4>
                    <ul class="space-y-1">
                      <%= for point <- feedback.key_points do %>
                        <li class="flex items-start gap-2">
                          <span class="text-blue-600 font-black">▸</span>
                          <span class="text-sm"><%= point %></span>
                        </li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>

                <%= if length(feedback.issues) > 0 do %>
                  <div>
                    <h4 class="font-black text-sm uppercase mb-2">Проблеми:</h4>
                    <div class="space-y-2">
                      <%= for issue <- feedback.issues do %>
                        <div class="flex items-start gap-2 p-2 bg-red-50 border-l-4 border-red-500">
                          <div class="flex-1">
                            <p class="text-sm font-bold"><%= Map.get(issue, "description") %></p>
                            <p class="text-xs text-gray-600">
                              Важливість: <%= Map.get(issue, "severity", "medium") %>
                              | Категорія: <%= Map.get(issue, "category", "other") %>
                            </p>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>

                <%= if length(feedback.strengths) > 0 do %>
                  <div>
                    <h4 class="font-black text-sm uppercase mb-2">Сильні сторони:</h4>
                    <ul class="space-y-1">
                      <%= for strength <- feedback.strengths do %>
                        <li class="flex items-start gap-2">
                          <span class="text-green-600 font-black">✓</span>
                          <span class="text-sm"><%= strength %></span>
                        </li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>

                <%= if length(feedback.improvement_areas) > 0 do %>
                  <div>
                    <h4 class="font-black text-sm uppercase mb-2">Сфери покращення:</h4>
                    <ul class="space-y-1">
                      <%= for area <- feedback.improvement_areas do %>
                        <li class="flex items-start gap-2">
                          <span class="text-yellow-600 font-black">→</span>
                          <span class="text-sm"><%= area %></span>
                        </li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </main>
    </div>
    """
  end

  defp sentiment_emoji("positive"), do: "😊"
  defp sentiment_emoji("negative"), do: "😟"
  defp sentiment_emoji(_), do: "😐"
end
