defmodule FeedbackBot.Jobs.ManagerSurveyJob do
  @moduledoc """
  Щоп'ятниці о 17:00 відправляє опитувальник на 10 питань
  Після завершення - порівнює з минулим тижнем
  """
  use Oban.Worker, queue: :notifications, max_attempts: 2

  require Logger
  alias FeedbackBot.{Surveys, Feedbacks}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    Logger.info("Sending weekly satisfaction survey to user #{user_id}...")

    # Визначаємо початок тижня
    week_start = get_week_start()

    # Перевіряємо чи вже є survey для цього тижня
    case Surveys.get_survey_for_week(user_id, week_start) do
      nil ->
        # Створюємо новий survey
        {:ok, survey} =
          Surveys.create_survey(%{
            user_id: user_id,
            week_start: week_start
          })

        # Відправляємо перше питання
        send_question(user_id, survey.id, 1)
        {:ok, %{sent_to: user_id, survey_id: survey.id}}

      _existing ->
        Logger.info("Survey already exists for user #{user_id} this week")
        {:ok, %{status: :already_exists}}
    end
  end

  # Overload для всіх користувачів
  def perform(%Oban.Job{args: %{}}) do
    user_ids = get_active_user_ids()

    Enum.each(user_ids, fn user_id ->
      %{user_id: user_id}
      |> __MODULE__.new()
      |> Oban.insert()
    end)

    {:ok, %{users: length(user_ids)}}
  end

  defp send_question(user_id, survey_id, question_num) do
    question_text = get_question_text(question_num)

    keyboard = [
      [
        %{text: "1️⃣", callback_data: "survey:#{survey_id}:q#{question_num}:1"},
        %{text: "2️⃣", callback_data: "survey:#{survey_id}:q#{question_num}:2"},
        %{text: "3️⃣", callback_data: "survey:#{survey_id}:q#{question_num}:3"},
        %{text: "4️⃣", callback_data: "survey:#{survey_id}:q#{question_num}:4"},
        %{text: "5️⃣", callback_data: "survey:#{survey_id}:q#{question_num}:5"}
      ]
    ]

    markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

    message = """
    📋 *ТИЖНЕВИЙ ОПИТУВАЛЬНИК ЗАДОВОЛЕНОСТІ*
    #{if question_num == 1, do: "\nБудь ласка, оцініть минулий тиждень за 10 параметрами.\n", else: ""}
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    *Питання #{question_num}/10:*

    #{question_text}

    _Оберіть оцінку від 1 (дуже погано) до 5 (відмінно)_
    """

    ExGram.send_message(user_id, message, parse_mode: "Markdown", reply_markup: markup)
  end

  defp get_question_text(1), do: "📊 Наскільки ви задоволені загальним *перформансом команди*?"

  defp get_question_text(2),
    do: "💬 Як оцінюєте якість *комунікації* в команді?"

  defp get_question_text(3), do: "🎯 Чи досягнуто *KPI* цього тижня?"
  defp get_question_text(4), do: "🔧 Наскільки ефективно *вирішувались проблеми*?"
  defp get_question_text(5), do: "⚡️ Як оцінюєте рівень *мотивації* команди?"

  defp get_question_text(6),
    do: "⏱ Чи задоволені *швидкістю виконання* задач?"

  defp get_question_text(7),
    do: "🤝 Як оцінюєте рівень *співпраці* між членами команди?"

  defp get_question_text(8), do: "✨ Наскільки *якісно виконується* робота?"

  defp get_question_text(9),
    do: "📈 Чи є *покращення* порівняно з минулим тижнем?"

  defp get_question_text(10), do: "⭐️ *Загальна оцінка* тижня"

  defp get_week_start do
    now = DateTime.utc_now()
    days_since_monday = Date.day_of_week(DateTime.to_date(now)) - 1
    week_start_date = Date.add(DateTime.to_date(now), -days_since_monday)
    DateTime.new!(week_start_date, ~T[00:00:00])
  end

  defp get_active_user_ids do
    # Отримуємо користувачів які залишали feedbacks за останні 2 тижні
    two_weeks_ago = DateTime.utc_now() |> DateTime.add(-14, :day)

    Feedbacks.filter_feedbacks(%{from: two_weeks_ago})
    |> Enum.map(& &1.telegram_user_id)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end
end
