defmodule FeedbackBot.Jobs.PerformanceReviewJob do
  @moduledoc """
  Щодвотижня генерує AI performance review для кожного співробітника
  """
  use Oban.Worker, queue: :analytics, max_attempts: 2

  require Logger
  alias FeedbackBot.{Employees, Feedbacks, AI}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    Logger.info("Generating bi-weekly performance reviews for user #{user_id}...")

    # Отримуємо feedbacks за останні 2 тижні
    two_weeks_ago = DateTime.utc_now() |> DateTime.add(-14, :day)
    now = DateTime.utc_now()

    feedbacks = Feedbacks.filter_feedbacks(%{from: two_weeks_ago, to: now})

    if length(feedbacks) == 0 do
      send_no_data_message(user_id)
      {:ok, %{status: :no_data}}
    else
      # Групуємо по співробітниках
      reviews_by_employee =
        feedbacks
        |> Enum.group_by(& &1.employee_id)
        |> Enum.map(fn {employee_id, employee_feedbacks} ->
          generate_performance_review(employee_id, employee_feedbacks)
        end)

      # Відправляємо summary
      send_performance_reviews(user_id, reviews_by_employee)

      {:ok, %{employees: length(reviews_by_employee), feedbacks: length(feedbacks)}}
    end
  end

  # Overload для всіх користувачів
  def perform(%Oban.Job{args: %{}}) do
    user_ids = get_manager_user_ids()

    Enum.each(user_ids, fn user_id ->
      %{user_id: user_id}
      |> __MODULE__.new()
      |> Oban.insert()
    end)

    {:ok, %{managers: length(user_ids)}}
  end

  defp generate_performance_review(employee_id, feedbacks) do
    employee = Employees.get_employee!(employee_id)

    # Створюємо структурований промпт для GPT
    prompt = """
    На основі наступних #{length(feedbacks)} відгуків за останні 2 тижні, складіть об'єктивний Performance Review для співробітника #{employee.name}.

    FEEDBACKS:
    #{format_feedbacks_for_review(feedbacks)}

    Створіть професійний Performance Review у форматі:

    1. ЗАГАЛЬНА ОЦІНКА (1-5):
    2. КЛЮЧОВІ СИЛЬНІ СТОРОНИ (3-5 пунктів):
    3. СФЕРИ ДЛЯ РОЗВИТКУ (2-4 пункти):
    4. КОНКРЕТНІ ДОСЯГНЕННЯ:
    5. РЕКОМЕНДАЦІЇ ДЛЯ ПОКРАЩЕННЯ:
    6. ЗАГАЛЬНИЙ ВИСНОВОК:

    Будьте конкретними, використовуйте факти з відгуків, уникайте загальних фраз.
    """

    case AI.GPTClient.generate_text(prompt) do
      {:ok, review_text} ->
        %{
          employee: employee,
          review: review_text,
          feedbacks_count: length(feedbacks),
          avg_sentiment: calculate_avg_sentiment(feedbacks),
          period: "#{format_date(DateTime.add(DateTime.utc_now(), -14, :day))} - #{format_date(DateTime.utc_now())}"
        }

      {:error, _} ->
        %{
          employee: employee,
          review: "⚠️ Не вдалося згенерувати review",
          feedbacks_count: length(feedbacks),
          avg_sentiment: calculate_avg_sentiment(feedbacks),
          period: "#{format_date(DateTime.add(DateTime.utc_now(), -14, :day))} - #{format_date(DateTime.utc_now())}"
        }
    end
  end

  defp format_feedbacks_for_review(feedbacks) do
    feedbacks
    |> Enum.with_index(1)
    |> Enum.map(fn {feedback, index} ->
      """
      Відгук #{index}:
      - Дата: #{format_date(feedback.inserted_at)}
      - Тональність: #{feedback.sentiment_label} (#{Float.round(feedback.sentiment_score, 2)})
      - Резюме: #{feedback.summary}
      - Ключові моменти: #{Enum.join(feedback.key_points, ", ")}
      #{if length(feedback.strengths) > 0, do: "- Сильні сторони: #{Enum.join(feedback.strengths, ", ")}", else: ""}
      #{if length(feedback.issues) > 0, do: "- Проблеми: #{Enum.map_join(feedback.issues, ", ", & &1["description"])}", else: ""}
      """
    end)
    |> Enum.join("\n\n")
  end

  defp send_no_data_message(user_id) do
    message = """
    📋 *ДВОТИЖНЕВІ PERFORMANCE REVIEWS*

    За останні 2 тижні не було записано жодного фідбеку.

    Неможливо згенерувати performance reviews без даних.

    _Почніть записувати фідбеки щоб отримувати автоматичні reviews!_ 🎤
    """

    ExGram.send_message(user_id, message, parse_mode: "Markdown")
  end

  defp send_performance_reviews(user_id, reviews) do
    intro = """
    📊 *ДВОТИЖНЕВІ PERFORMANCE REVIEWS*
    #{format_date(DateTime.add(DateTime.utc_now(), -14, :day))} - #{format_date(DateTime.utc_now())}

    🤖 *AI-Generated на базі #{total_feedbacks(reviews)} фідбеків*

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    """

    ExGram.send_message(user_id, intro, parse_mode: "Markdown")

    # Відправляємо кожен review окремим повідомленням
    Enum.each(reviews, fn review ->
      message = format_review_message(review)

      ExGram.send_message(user_id, message, parse_mode: "Markdown")
      # Невелика затримка між повідомленнями
      Process.sleep(500)
    end)

    # Фінальне повідомлення
    outro = """
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    ✅ *REVIEWS COMPLETED*

    Всього проаналізовано: *#{length(reviews)} співробітників*

    💡 Використовуйте ці об'єктивні оцінки для:
    • 1-on-1 зустрічей
    • Планування розвитку
    • Performance discussions
    • Винагород та просувань

    _Згенеровано Kaminskyi Epic_ ✨
    """

    ExGram.send_message(user_id, outro, parse_mode: "Markdown")
  end

  defp format_review_message(review) do
    sentiment_emoji =
      cond do
        review.avg_sentiment >= 0.3 -> "😊"
        review.avg_sentiment >= -0.3 -> "😐"
        true -> "😟"
      end

    """
    👤 *#{review.employee.name}*
    #{String.duplicate("━", 35)}

    📈 Середня тональність: *#{Float.round(review.avg_sentiment, 2)}* #{sentiment_emoji}
    📝 Базується на *#{review.feedbacks_count}* відгуках

    #{review.review}

    #{String.duplicate("━", 35)}
    """
  end

  defp calculate_avg_sentiment(feedbacks) do
    if length(feedbacks) == 0 do
      0.0
    else
      Enum.sum(Enum.map(feedbacks, & &1.sentiment_score)) / length(feedbacks)
    end
  end

  defp total_feedbacks(reviews) do
    Enum.sum(Enum.map(reviews, & &1.feedbacks_count))
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d.%m.%Y")
  end

  defp get_manager_user_ids do
    # Отримуємо користувачів які залишали feedbacks
    month_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    Feedbacks.filter_feedbacks(%{from: month_ago})
    |> Enum.map(& &1.telegram_user_id)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end
end
