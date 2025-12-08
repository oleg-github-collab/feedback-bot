defmodule FeedbackBotWeb.RecordFeedbackLive do
  use FeedbackBotWeb, :live_view

  alias FeedbackBot.{Employees, Feedbacks, AI}

  @impl true
  def mount(_params, _session, socket) do
    employees = Employees.list_active_employees()

    {:ok,
     socket
     |> assign(:page_title, "Записати Фідбек")
     |> assign(:employees, employees)
     |> assign(:selected_employee, nil)
     |> assign(:step, :select_employee)
     |> assign(:recording, false)
     |> assign(:processing, false)
     |> assign(:transcription, nil)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("select_employee", %{"employee_id" => employee_id}, socket) do
    employee = Employees.get_employee(employee_id)

    {:noreply,
     socket
     |> assign(:selected_employee, employee)
     |> assign(:step, :record_audio)}
  end

  @impl true
  def handle_event("back_to_select", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_employee, nil)
     |> assign(:step, :select_employee)
     |> assign(:transcription, nil)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("start_recording", _params, socket) do
    {:noreply, assign(socket, :recording, true)}
  end

  @impl true
  def handle_event("stop_recording", _params, socket) do
    {:noreply, assign(socket, :recording, false)}
  end

  @impl true
  def handle_event("audio_uploaded", %{"audio_data" => audio_data}, socket) do
    # Декодуємо base64 аудіо
    case Base.decode64(audio_data) do
      {:ok, audio_binary} ->
        # Зберігаємо тимчасово
        temp_path = Path.join(System.tmp_dir!(), "recording_#{:erlang.unique_integer([:positive])}.webm")
        File.write!(temp_path, audio_binary)

        # Обробляємо аудіо
        socket =
          socket
          |> assign(:processing, true)
          |> assign(:error, nil)

        # Запускаємо обробку асинхронно
        send(self(), {:process_audio, temp_path})

        {:noreply, socket}

      {:error, _} ->
        {:noreply, assign(socket, :error, "Помилка декодування аудіо")}
    end
  end

  @impl true
  def handle_info({:process_audio, audio_path}, socket) do
    employee = socket.assigns.selected_employee

    case process_feedback(audio_path, employee.id) do
      {:ok, feedback} ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> assign(:step, :success)
         |> assign(:feedback, feedback)
         |> put_flash(:info, "Фідбек успішно збережено!")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> assign(:error, "Помилка обробки: #{inspect(reason)}")}
    end
  end

  defp process_feedback(audio_path, employee_id) do
    with {:ok, transcription} <- AI.WhisperClient.transcribe(audio_path),
         {:ok, analysis} <- AI.GPTClient.analyze_feedback(transcription, employee_id) do
      # Отримуємо розмір файлу для duration (приблизно)
      file_stat = File.stat!(audio_path)
      duration = div(file_stat.size, 16000)  # Приблизна оцінка

      feedback_attrs = %{
        employee_id: employee_id,
        audio_file_path: audio_path,
        duration_seconds: duration,
        transcription: transcription,
        summary: analysis.summary,
        sentiment_score: analysis.sentiment_score,
        sentiment_label: analysis.sentiment_label,
        mood_intensity: analysis.mood_intensity,
        key_points: analysis.key_points,
        issues: analysis.issues,
        strengths: analysis.strengths,
        improvement_areas: analysis.improvement_areas,
        topics: analysis.topics,
        action_items: analysis.action_items,
        urgency_score: analysis.urgency_score,
        impact_score: analysis.impact_score,
        trend_direction: analysis.trend_direction,
        raw_ai_response: analysis.raw_response,
        processing_status: "completed"
      }

      Feedbacks.create_feedback(feedback_attrs)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-violet-50 via-purple-50 to-pink-50">
      <!-- Header -->
      <header class="bg-white shadow-lg border-b-4 border-violet-600">
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <h1 class="text-4xl font-black bg-gradient-to-r from-violet-600 to-purple-600 bg-clip-text text-transparent">
            🎤 Записати Фідбек
          </h1>
          <p class="mt-2 text-gray-600 font-semibold">Голосовий відгук про співробітника</p>
        </div>
      </header>

      <main class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%= if @step == :select_employee do %>
          <.select_employee_step employees={@employees} />
        <% end %>

        <%= if @step == :record_audio do %>
          <.record_audio_step
            employee={@selected_employee}
            recording={@recording}
            processing={@processing}
            error={@error}
          />
        <% end %>

        <%= if @step == :success do %>
          <.success_step feedback={@feedback} employee={@selected_employee} />
        <% end %>
      </main>
    </div>
    """
  end

  defp select_employee_step(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl shadow-2xl border-4 border-violet-200 p-8">
      <div class="text-center mb-8">
        <div class="inline-block bg-violet-100 rounded-full p-4 mb-4">
          <span class="text-5xl">👥</span>
        </div>
        <h2 class="text-3xl font-black text-gray-800">Крок 1: Оберіть співробітника</h2>
        <p class="mt-2 text-gray-600">Про кого ви хочете залишити фідбек?</p>
      </div>

      <%= if Enum.empty?(@employees) do %>
        <div class="text-center py-12">
          <p class="text-xl text-gray-500">Немає активних співробітників</p>
        </div>
      <% else %>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <%= for employee <- @employees do %>
            <button
              phx-click="select_employee"
              phx-value-employee_id={employee.id}
              class="group relative overflow-hidden bg-gradient-to-br from-violet-50 to-purple-50 hover:from-violet-100 hover:to-purple-100 border-2 border-violet-300 hover:border-violet-500 rounded-xl p-6 transition-all duration-300 transform hover:-translate-y-1 hover:shadow-xl"
            >
              <div class="flex items-center gap-4">
                <div class="flex-shrink-0 w-16 h-16 bg-gradient-to-br from-violet-500 to-purple-500 rounded-full flex items-center justify-center text-white text-2xl font-black">
                  <%= String.first(employee.name) %>
                </div>
                <div class="flex-1 text-left">
                  <h3 class="text-lg font-bold text-gray-800 group-hover:text-violet-600 transition-colors">
                    <%= employee.name %>
                  </h3>
                  <p class="text-sm text-gray-600"><%= employee.email %></p>
                </div>
                <div class="text-violet-600 group-hover:translate-x-1 transition-transform">
                  →
                </div>
              </div>
            </button>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp record_audio_step(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Progress indicator -->
      <div class="bg-white rounded-xl shadow-lg border-2 border-violet-200 p-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 bg-green-500 rounded-full flex items-center justify-center text-white font-bold">
              ✓
            </div>
            <div>
              <p class="font-bold text-gray-800">Крок 1: Співробітник обрано</p>
              <p class="text-sm text-gray-600"><%= @employee.name %></p>
            </div>
          </div>
          <button
            phx-click="back_to_select"
            class="px-4 py-2 text-sm font-semibold text-violet-600 hover:bg-violet-50 rounded-lg transition-colors"
          >
            Змінити
          </button>
        </div>
      </div>

      <!-- Recording interface -->
      <div class="bg-white rounded-2xl shadow-2xl border-4 border-violet-200 p-8">
        <div class="text-center mb-8">
          <div class="inline-block bg-red-100 rounded-full p-4 mb-4">
            <span class="text-5xl">🎤</span>
          </div>
          <h2 class="text-3xl font-black text-gray-800">Крок 2: Запишіть аудіо</h2>
          <p class="mt-2 text-gray-600">Натисніть кнопку і почніть говорити</p>
        </div>

        <%= if @processing do %>
          <div class="text-center py-12">
            <div class="inline-block animate-spin rounded-full h-16 w-16 border-4 border-violet-200 border-t-violet-600 mb-4">
            </div>
            <p class="text-xl font-bold text-gray-800">Обробка фідбеку...</p>
            <p class="text-gray-600 mt-2">Розпізнавання мови та аналіз тональності</p>
          </div>
        <% else %>
          <div class="space-y-6">
            <!-- Recording button -->
            <div class="flex justify-center">
              <button
                id="record-button"
                phx-hook="AudioRecorder"
                class={[
                  "w-32 h-32 rounded-full flex items-center justify-center text-4xl transition-all duration-300 transform hover:scale-110 shadow-2xl",
                  if(@recording,
                    do: "bg-red-500 animate-pulse",
                    else: "bg-gradient-to-br from-violet-500 to-purple-500 hover:from-violet-600 hover:to-purple-600"
                  )
                ]}
              >
                <%= if @recording do %>
                  ⏹
                <% else %>
                  🎤
                <% end %>
              </button>
            </div>

            <%= if @recording do %>
              <div class="text-center">
                <p class="text-xl font-bold text-red-600 animate-pulse">● REC</p>
                <p class="text-gray-600">Запис...Натисніть ще раз щоб зупинити</p>
              </div>
            <% else %>
              <div class="text-center">
                <p class="text-lg font-semibold text-gray-700">
                  Натисніть кнопку мікрофону щоб почати запис
                </p>
              </div>
            <% end %>

            <%= if @error do %>
              <div class="bg-red-50 border-2 border-red-300 rounded-xl p-4 text-center">
                <p class="text-red-600 font-semibold"><%= @error %></p>
              </div>
            <% end %>

            <!-- Instructions -->
            <div class="bg-violet-50 border-2 border-violet-200 rounded-xl p-6">
              <h3 class="font-bold text-lg text-gray-800 mb-3">💡 Підказки для запису:</h3>
              <ul class="space-y-2 text-gray-700">
                <li class="flex items-start gap-2">
                  <span class="text-violet-600 font-bold">•</span>
                  <span>Говоріть чітко та не дуже швидко</span>
                </li>
                <li class="flex items-start gap-2">
                  <span class="text-violet-600 font-bold">•</span>
                  <span>Розкажіть про сильні сторони співробітника</span>
                </li>
                <li class="flex items-start gap-2">
                  <span class="text-violet-600 font-bold">•</span>
                  <span>Опишіть можливі проблеми чи виклики</span>
                </li>
                <li class="flex items-start gap-2">
                  <span class="text-violet-600 font-bold">•</span>
                  <span>Запропонуйте сфери для покращення</span>
                </li>
              </ul>
              <p class="mt-4 text-sm text-gray-600">
                ⏱ Рекомендована тривалість: 30 секунд - 2 хвилини
              </p>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp success_step(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl shadow-2xl border-4 border-green-200 p-8">
      <div class="text-center">
        <div class="inline-block bg-green-100 rounded-full p-6 mb-6">
          <span class="text-7xl">🎉</span>
        </div>
        <h2 class="text-4xl font-black text-gray-800 mb-4">Фідбек збережено!</h2>
        <p class="text-xl text-gray-600 mb-8">
          Дякуємо за ваш відгук про <span class="font-bold"><%= @employee.name %></span>
        </p>

        <div class="bg-gradient-to-br from-violet-50 to-purple-50 border-2 border-violet-200 rounded-xl p-6 mb-8">
          <div class="grid grid-cols-2 gap-4 text-left">
            <div>
              <p class="text-sm text-gray-600 font-semibold">Тональність</p>
              <p class="text-2xl font-black text-violet-600">
                <%= format_sentiment(@feedback.sentiment_label) %>
              </p>
            </div>
            <div>
              <p class="text-sm text-gray-600 font-semibold">Важливість</p>
              <p class="text-2xl font-black text-purple-600">
                <%= format_urgency(@feedback.urgency_score) %>
              </p>
            </div>
          </div>
        </div>

        <div class="flex gap-4 justify-center">
          <.link
            navigate={~p"/"}
            class="px-8 py-4 bg-gradient-to-r from-violet-600 to-purple-600 text-white font-bold rounded-xl hover:from-violet-700 hover:to-purple-700 transition-all shadow-lg hover:shadow-xl transform hover:-translate-y-0.5"
          >
            📊 До Dashboard
          </.link>
          <button
            phx-click="back_to_select"
            class="px-8 py-4 bg-white text-violet-600 font-bold border-2 border-violet-600 rounded-xl hover:bg-violet-50 transition-all"
          >
            🎤 Записати ще один
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp format_sentiment("positive"), do: "😊 Позитивна"
  defp format_sentiment("neutral"), do: "😐 Нейтральна"
  defp format_sentiment("negative"), do: "😟 Негативна"
  defp format_sentiment(_), do: "—"

  defp format_urgency(score) when score >= 0.8, do: "🔴 Висока"
  defp format_urgency(score) when score >= 0.5, do: "🟡 Середня"
  defp format_urgency(_), do: "🟢 Низька"
end
