defmodule FeedbackBotWeb.FeedbacksLive do
  use FeedbackBotWeb, :live_view

  alias FeedbackBot.Feedbacks
  alias FeedbackBot.Jobs.UpdateAnalyticsJob
  alias Oban

  @impl true
  def mount(_params, _session, socket) do
    feedbacks = Feedbacks.list_feedbacks(limit: 50)

    socket =
      socket
      |> assign(:page_title, "Фідбеки")
      |> assign(:active_nav, "/feedbacks")
      |> assign(:feedbacks, feedbacks)
      |> assign(:rewrite_target, nil)
      |> assign(:rewrite_text, "")
      |> assign(:delete_target, nil)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(FeedbackBot.PubSub, "feedbacks")
    end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-50">
      <.top_nav active={@active_nav} />
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

              <div class="flex flex-wrap gap-2 mb-4">
                <button
                  type="button"
                  phx-click="start_rewrite"
                  phx-value-id={feedback.id}
                  class="neo-brutal-btn-sm bg-indigo-600 text-white border-black"
                >
                  ✏️ Перезаписати
                </button>
                <button
                  type="button"
                  phx-click="confirm_delete"
                  phx-value-id={feedback.id}
                  class="neo-brutal-btn-sm bg-red-500 text-white border-black"
                >
                  🗑 Видалити
                </button>
              </div>

              <%= if @delete_target == feedback.id do %>
                <div class="border-2 border-red-600 bg-red-50 p-3 rounded-lg mb-4">
                  <p class="text-sm font-semibold text-red-700">
                    Ви впевнені, що хочете видалити цей фідбек?
                  </p>
                  <div class="mt-2 flex gap-2">
                    <button
                      type="button"
                      phx-click="delete_feedback"
                      phx-value-id={feedback.id}
                      class="neo-brutal-btn-sm bg-red-600 text-white border-black"
                      phx-disable-with="Видаляю..."
                    >
                      Так, видалити
                    </button>
                    <button
                      type="button"
                      phx-click="cancel_delete"
                      class="neo-brutal-btn-sm bg-white"
                    >
                      Скасувати
                    </button>
                  </div>
                </div>
              <% end %>

              <%= if @rewrite_target == feedback.id do %>
                <div class="border-2 border-indigo-500 bg-indigo-50 p-3 rounded-lg mb-4">
                  <p class="text-sm font-semibold text-indigo-800">
                    Перезапишіть відгук, якщо потрібно виправити зміст або інтерпретацію.
                  </p>
                  <form phx-submit="save_rewrite" phx-value-id={feedback.id} class="space-y-2 mt-2">
                    <textarea
                      name="transcription"
                      class="w-full h-28 text-sm border-2 border-black p-3 bg-white"
                      placeholder="Вставте правильний текст або коротко опишіть новий фідбек"
                    ><%= @rewrite_text %></textarea>
                    <div class="flex gap-2">
                      <button
                        type="submit"
                        class="neo-brutal-btn-sm bg-indigo-600 text-white border-black"
                        phx-disable-with="Перезаписую..."
                      >
                        Перезаписати
                      </button>
                      <button
                        type="button"
                        phx-click="cancel_rewrite"
                        class="neo-brutal-btn-sm bg-white"
                      >
                        Скасувати
                      </button>
                    </div>
                  </form>
                </div>
              <% end %>

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

  @impl true
  def handle_event("start_rewrite", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.feedbacks, &(&1.id == id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Фідбек не знайдено")}

      feedback ->
        {:noreply,
         socket
         |> assign(:rewrite_target, feedback.id)
         |> assign(:rewrite_text, feedback.transcription || "")
         |> assign(:delete_target, nil)}
    end
  end

  def handle_event("cancel_rewrite", _params, socket) do
    {:noreply, reset_rewrite(socket)}
  end

  def handle_event("save_rewrite", %{"id" => id, "transcription" => transcription}, socket) do
    cleaned = String.trim(to_string(transcription || ""))

    cond do
      cleaned == "" ->
        {:noreply, put_flash(socket, :error, "Введіть нову транскрипцію або текст фідбеку")}

      feedback = Feedbacks.get_feedback(id) ->
        case Feedbacks.reanalyze_feedback(feedback, cleaned) do
          {:ok, updated} ->
            broadcast_feedback(:updated, updated)
            enqueue_analytics_refresh()

            feedbacks = replace_feedback(socket.assigns.feedbacks, updated)

            {:noreply,
             socket
             |> assign(:feedbacks, feedbacks)
             |> reset_rewrite()
             |> put_flash(:info, "Фідбек перезаписано та проаналізовано наново")}

          {:error, :empty_transcription} ->
            {:noreply, put_flash(socket, :error, "Текст фідбеку не може бути порожнім")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Не вдалося перезаписати: #{humanize_error(reason)}")}
        end

      true ->
        {:noreply, put_flash(socket, :error, "Фідбек не знайдено")}
    end
  end

  def handle_event("confirm_delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, :delete_target, id)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :delete_target, nil)}
  end

  def handle_event("delete_feedback", %{"id" => id}, socket) do
    case Feedbacks.get_feedback(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Фідбек не знайдено")}

      feedback ->
        case Feedbacks.delete_feedback(feedback) do
          {:ok, _} ->
            broadcast_feedback(:deleted, feedback)
            enqueue_analytics_refresh()

            feedbacks = Enum.reject(socket.assigns.feedbacks, &(&1.id == feedback.id))

            {:noreply,
             socket
             |> assign(:feedbacks, feedbacks)
             |> assign(:delete_target, nil)
             |> reset_rewrite()
             |> put_flash(:info, "Фідбек видалено")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Не вдалося видалити фідбек")}
        end
    end
  end

  @impl true
  def handle_info({type, _payload}, socket) when type in [:new_feedback, :feedback_updated, :feedback_deleted] do
    {:noreply, refresh_feedbacks(socket)}
  end

  defp sentiment_emoji("positive"), do: "😊"
  defp sentiment_emoji("negative"), do: "😟"
  defp sentiment_emoji(_), do: "😐"

  defp replace_feedback(feedbacks, updated) do
    Enum.map(feedbacks, fn feedback ->
      if feedback.id == updated.id, do: updated, else: feedback
    end)
  end

  defp reset_rewrite(socket) do
    socket
    |> assign(:rewrite_target, nil)
    |> assign(:rewrite_text, "")
  end

  defp refresh_feedbacks(socket) do
    socket
    |> assign(:feedbacks, Feedbacks.list_feedbacks(limit: 50))
    |> assign(:delete_target, nil)
    |> assign(:rewrite_target, nil)
    |> assign(:rewrite_text, "")
  end

  defp broadcast_feedback(:updated, feedback) do
    Phoenix.PubSub.broadcast(FeedbackBot.PubSub, "feedbacks", {:feedback_updated, feedback})
  end

  defp broadcast_feedback(:deleted, feedback) do
    Phoenix.PubSub.broadcast(FeedbackBot.PubSub, "feedbacks", {:feedback_deleted, feedback.id})
  end

  defp enqueue_analytics_refresh do
    %{type: "all"}
    |> UpdateAnalyticsJob.new()
    |> Oban.insert()
  end

  defp humanize_error(:invalid_feedback), do: "Некоректний фідбек"
  defp humanize_error(:empty_transcription), do: "Додайте текст фідбеку"
  defp humanize_error(reason), do: inspect(reason)
end
