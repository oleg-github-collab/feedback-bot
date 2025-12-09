defmodule FeedbackBot.Jobs.NegativeFeedbackFollowupJob do
  @moduledoc """
  Через тиждень після негативного feedback запитує чи покращилась ситуація
  Запускається щодня о 9:00 ранку за часом користувача
  """
  use Oban.Worker, queue: :notifications, max_attempts: 3

  require Logger
  alias FeedbackBot.{Feedbacks, Employees, Repo}

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Running negative feedback follow-up check...")

    # Знаходимо всі негативні feedbacks які були створені рівно тиждень тому
    week_ago = DateTime.utc_now() |> DateTime.add(-7, :day)
    week_ago_start = DateTime.new!(DateTime.to_date(week_ago), ~T[00:00:00])
    week_ago_end = DateTime.new!(DateTime.to_date(week_ago), ~T[23:59:59])

    negative_feedbacks =
      Feedbacks.filter_feedbacks(%{
        from: week_ago_start,
        to: week_ago_end,
        sentiment: "negative"
      })

    Logger.info("Found #{length(negative_feedbacks)} negative feedbacks from a week ago")

    # Групуємо по користувачах
    feedbacks_by_user =
      negative_feedbacks
      |> Enum.group_by(& &1.telegram_user_id)

    # Відправляємо follow-up кожному користувачу
    Enum.each(feedbacks_by_user, fn {user_id, feedbacks} ->
      send_followup_message(user_id, feedbacks)
    end)

    {:ok, %{sent: map_size(feedbacks_by_user), total_feedbacks: length(negative_feedbacks)}}
  end

  defp send_followup_message(user_id, feedbacks) do
    # Завантажуємо інфо про співробітників
    employee_names =
      feedbacks
      |> Enum.map(fn f ->
        employee = Employees.get_employee!(f.employee_id)
        employee.name
      end)
      |> Enum.uniq()

    message = get_random_followup_message(employee_names, length(feedbacks))

    case ExGram.send_message(user_id, message, parse_mode: "Markdown") do
      {:ok, _} ->
        Logger.info("Follow-up sent to user #{user_id}")

      {:error, error} ->
        Logger.error("Failed to send follow-up to user #{user_id}: #{inspect(error)}")
    end
  end

  defp get_random_followup_message(employee_names, count) do
    employee_list = Enum.join(employee_names, ", ")

    messages = [
      """
      🔔 *Привіт! Нагадування від FeedbackBot*

      Тиждень тому ви залишили #{count} #{feedback_word(count)} з негативною тональністю про:
      #{format_employees(employee_names)}

      ❓ *Хотів би дізнатись:*
      Чи покращилась ситуація за цей час?

      Якщо так - чудово! 🎉
      Якщо ні - можливо варто записати оновлення?

      🎤 Просто надішліть голосове повідомлення якщо є що сказати.
      """,
      """
      👋 *Доброго ранку!*

      Минув тиждень відколи ви поділились негативним фідбеком щодо:
      #{format_employees(employee_names)}

      🤔 *Цікаво дізнатись:*
      • Чи змінилась робота цих співробітників?
      • Чи вирішились проблеми які ви відзначали?
      • Може є позитивні зміни?

      Поділіться оновленням якщо є час 🎤
      """,
      """
      ⏰ *Час для check-in!*

      Рівно тиждень тому ви записали #{count} #{feedback_word(count)} про:
      #{format_employees(employee_names)}

      📊 *Як зараз справи?*
      Покращилась чи погіршилась ситуація? Залишилась без змін?

      Ваш відгук допомагає відстежувати реальну динаміку!

      _Якщо є що сказати - просто надішліть голосове_ 🎤
      """,
      """
      🔄 *Follow-up нагадування*

      7 днів тому: #{count} негативних #{feedback_word(count)}
      Співробітники: #{employee_list}

      *Перевірка стану:*
      ✅ Ситуація покращилась?
      ⚠️ Все ще є проблеми?
      📈 Може є прогрес?

      Голосове повідомлення з оновленням буде дуже корисним! 🎤
      """,
      """
      💬 *Один тиждень після вашого feedback*

      Ви відзначали проблеми з роботою:
      #{format_employees(employee_names)}

      🎯 *Давайте подивимось на результат:*
      Чи є покращення? Чи варто звернути більше уваги?

      Ваш досвід важливий для аналітики!

      _Запишіть коротке оновлення якщо маєте вільну хвилину_ 🎤
      """
    ]

    Enum.random(messages)
  end

  defp format_employees(names) do
    names
    |> Enum.map(&"• #{&1}")
    |> Enum.join("\n")
  end

  defp feedback_word(1), do: "фідбек"
  defp feedback_word(count) when count in 2..4, do: "фідбеки"
  defp feedback_word(_), do: "фідбеків"
end
