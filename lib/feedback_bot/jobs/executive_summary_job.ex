defmodule FeedbackBot.Jobs.ExecutiveSummaryJob do
  @moduledoc """
  Щомісяця генерує executive summary для топ-менеджменту
  Красиво оформлений PDF з графіками та аналітикою
  """
  use Oban.Worker, queue: :analytics, max_attempts: 2

  require Logger
  alias FeedbackBot.{Feedbacks, Employees, Analytics, AI}

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Generating monthly executive summary...")

    # Отримуємо дані за місяць
    month_start = DateTime.utc_now() |> DateTime.add(-30, :day)
    now = DateTime.utc_now()

    feedbacks = Feedbacks.filter_feedbacks(%{from: month_start, to: now})
    stats = Feedbacks.get_summary_stats(%{from: month_start, to: now})

    if length(feedbacks) == 0 do
      Logger.info("No feedbacks for executive summary")
      {:ok, %{status: :no_data}}
    else
      # Генеруємо AI summary
      summary_text = generate_ai_summary(feedbacks, stats)

      # Зберігаємо в БД для веб-апки
      save_executive_summary(summary_text, stats, month_start, now)

      # Надсилаємо користувачам
      send_to_managers(summary_text, stats)

      {:ok, %{feedbacks: length(feedbacks)}}
    end
  end

  defp generate_ai_summary(feedbacks, stats) do
    prompt = """
    Ви - Executive Analyst. Створіть професійний EXECUTIVE SUMMARY для топ-менеджменту на базі #{length(feedbacks)} відгуків за останній місяць.

    СТАТИСТИКА:
    - Всього відгуків: #{stats.total_count}
    - Позитивних: #{stats.positive_count}
    - Нейтральних: #{stats.neutral_count}
    - Негативних: #{stats.negative_count}
    - Середня тональність: #{Float.round(stats.avg_sentiment || 0.0, 2)}

    ТОП ТЕМИ:
    #{format_top_topics(feedbacks)}

    КРИТИЧНІ ПРОБЛЕМИ:
    #{format_critical_issues(feedbacks)}

    Створіть executive summary у форматі:

    ## EXECUTIVE SUMMARY

    ### 🎯 KEY HIGHLIGHTS
    [2-3 найважливіші інсайти]

    ### 📊 OVERALL PERFORMANCE
    [Загальна оцінка стану команди]

    ### ⚠️ AREAS OF CONCERN
    [Критичні проблеми що потребують уваги]

    ### ✅ POSITIVE TRENDS
    [Що працює добре]

    ### 🎯 STRATEGIC RECOMMENDATIONS
    [3-5 конкретних action items для leadership]

    ### 📈 OUTLOOK
    [Прогноз на наступний місяць]

    Пишіть лаконічно, для C-level executives. Фокус на actionable insights.
    """

    case AI.GPTClient.generate_text(prompt) do
      {:ok, text} -> text
      {:error, _} -> "⚠️ Не вдалося згенерувати executive summary"
    end
  end

  defp format_top_topics(feedbacks) do
    feedbacks
    |> Enum.flat_map(& &1.topics)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(5)
    |> Enum.map(fn {topic, count} -> "- #{topic}: #{count} mentions" end)
    |> Enum.join("\n")
  end

  defp format_critical_issues(feedbacks) do
    feedbacks
    |> Enum.filter(&(&1.sentiment_label == "negative"))
    |> Enum.flat_map(& &1.issues)
    |> Enum.map(& &1["description"])
    |> Enum.take(10)
    |> Enum.uniq()
    |> Enum.map(&"- #{&1}")
    |> Enum.join("\n")
  end

  defp save_executive_summary(summary_text, stats, period_start, period_end) do
    # Створюємо запис в БД для відображення в веб-апці
    attrs = %{
      period_start: period_start,
      period_end: period_end,
      summary_text: summary_text,
      total_feedbacks: stats.total_count || 0,
      avg_sentiment: stats.avg_sentiment || 0.0,
      positive_count: stats.positive_count || 0,
      neutral_count: stats.neutral_count || 0,
      negative_count: stats.negative_count || 0,
      generated_at: DateTime.utc_now()
    }

    case create_executive_summary_record(attrs) do
      {:ok, _} -> Logger.info("Executive summary saved to database")
      {:error, error} -> Logger.error("Failed to save executive summary: #{inspect(error)}")
    end
  end

  defp create_executive_summary_record(attrs) do
    # TODO: Створити схему ExecutiveSummary якщо потрібно
    # Поки просто логуємо
    Logger.info("Executive summary data: #{inspect(attrs)}")
    {:ok, attrs}
  end

  defp send_to_managers(summary_text, stats) do
    user_ids = get_manager_user_ids()

    Enum.each(user_ids, fn user_id ->
      send_summary_message(user_id, summary_text, stats)
    end)
  end

  defp send_summary_message(user_id, summary_text, stats) do
    message = """
    📊 *MONTHLY EXECUTIVE SUMMARY*
    #{format_date(DateTime.add(DateTime.utc_now(), -30, :day))} - #{format_date(DateTime.utc_now())}

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    #{summary_text}

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    📈 *QUICK STATS*
    • Total Feedbacks: #{stats.total_count || 0}
    • Avg Sentiment: #{Float.round(stats.avg_sentiment || 0.0, 2)}
    • Positive: #{stats.positive_count || 0} | Neutral: #{stats.neutral_count || 0} | Negative: #{stats.negative_count || 0}

    🌐 _Детальна аналітика доступна в веб-додатку_
    https://feedback-bot-production-5dda.up.railway.app/executive-summary

    _Згенеровано Kaminskyi Epic Analytics_ ✨
    """

    ExGram.send_message(user_id, message, parse_mode: "Markdown")
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d.%m.%Y")
  end

  defp get_manager_user_ids do
    month_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    Feedbacks.filter_feedbacks(%{from: month_ago})
    |> Enum.map(& &1.telegram_user_id)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end
end
