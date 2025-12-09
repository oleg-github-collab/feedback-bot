defmodule FeedbackBot.Jobs.WeeklyStatisticsJob do
  @moduledoc """
  Щоп'ятниці о 16:00 відправляє детальну статистику за тиждень
  """
  use Oban.Worker, queue: :notifications, max_attempts: 3

  require Logger
  alias FeedbackBot.{Feedbacks, Employees}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    Logger.info("Sending weekly statistics to user #{user_id}...")

    # Отримуємо дані за тиждень
    now = DateTime.utc_now()
    week_start = DateTime.add(now, -7, :day)

    feedbacks = Feedbacks.filter_feedbacks(%{from: week_start, to: now})
    stats = Feedbacks.get_summary_stats(%{from: week_start, to: now})

    if length(feedbacks) == 0 do
      send_no_data_message(user_id)
    else
      send_statistics_message(user_id, feedbacks, stats)
    end

    {:ok, %{sent_to: user_id, feedbacks_count: length(feedbacks)}}
  end

  # Overload для відправки всім користувачам
  def perform(%Oban.Job{args: %{}}) do
    Logger.info("Sending weekly statistics to all users...")

    # Отримуємо всіх користувачів які залишали feedbacks
    user_ids = get_active_user_ids()

    Enum.each(user_ids, fn user_id ->
      %{user_id: user_id}
      |> __MODULE__.new()
      |> Oban.insert()
    end)

    {:ok, %{users: length(user_ids)}}
  end

  defp send_no_data_message(user_id) do
    message = """
    📊 *ТИЖНЕВА СТАТИСТИКА*

    На жаль, за останній тиждень не було записано жодного фідбеку 📭

    🤔 *Можливо варто поділитись враженнями?*
    Надішліть голосове повідомлення про роботу ваших колег!
    """

    ExGram.send_message(user_id, message, parse_mode: "Markdown")
  end

  defp send_statistics_message(user_id, feedbacks, stats) do
    # Аналізуємо топіки
    topics_analysis = analyze_topics(feedbacks)
    employee_breakdown = analyze_by_employee(feedbacks)
    common_issues = find_common_issues(feedbacks)
    sentiment_breakdown = get_sentiment_breakdown(stats)

    message = build_statistics_message(
      stats,
      topics_analysis,
      employee_breakdown,
      common_issues,
      sentiment_breakdown
    )

    ExGram.send_message(user_id, message, parse_mode: "Markdown")
  end

  defp analyze_topics(feedbacks) do
    feedbacks
    |> Enum.flat_map(& &1.topics)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_topic, count} -> count end, :desc)
    |> Enum.take(5)
  end

  defp analyze_by_employee(feedbacks) do
    feedbacks
    |> Enum.group_by(& &1.employee_id)
    |> Enum.map(fn {employee_id, employee_feedbacks} ->
      employee = Employees.get_employee!(employee_id)
      avg_sentiment = Enum.map(employee_feedbacks, & &1.sentiment_score) |> average()

      %{
        name: employee.name,
        count: length(employee_feedbacks),
        avg_sentiment: avg_sentiment,
        sentiment_label: categorize_sentiment(avg_sentiment)
      }
    end)
    |> Enum.sort_by(& &1.count, :desc)
  end

  defp find_common_issues(feedbacks) do
    feedbacks
    |> Enum.filter(&(&1.sentiment_label == "negative"))
    |> Enum.flat_map(& &1.issues)
    |> Enum.map(&(&1["description"]))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_issue, count} -> count end, :desc)
    |> Enum.take(3)
  end

  defp get_sentiment_breakdown(stats) do
    %{
      positive: stats.positive_count || 0,
      neutral: stats.neutral_count || 0,
      negative: stats.negative_count || 0,
      avg: stats.avg_sentiment || 0.0
    }
  end

  defp build_statistics_message(stats, topics, employees, issues, sentiment) do
    intro = Enum.random([
      "📊 *ТИЖНЕВА СТАТИСТИКА ЗА #{format_date_range()}*\n\n🎉 Ваш персональний звіт готовий!",
      "📈 *ПІДСУМКИ ТИЖНЯ #{format_date_range()}*\n\n✨ Давайте подивимось що відбувалось:",
      "🗓 *АНАЛІТИКА ЗА ТИЖДЕНЬ #{format_date_range()}*\n\n📋 Детальний розбір:",
      "💼 *WEEKLY DIGEST #{format_date_range()}*\n\n🔍 Що показує аналітика:",
      "📊 *ЗВІТ ЗА ТИЖДЕНЬ #{format_date_range()}*\n\n💡 Основні інсайти:"
    ])

    """
    #{intro}

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    📈 *ЗАГАЛЬНА СТАТИСТИКА*

    📝 Всього фідбеків: *#{stats.total_count}*
    😊 Позитивних: #{sentiment.positive}
    😐 Нейтральних: #{sentiment.neutral}
    😟 Негативних: #{sentiment.negative}

    📊 Середня тональність: *#{Float.round(sentiment.avg, 2)}* #{sentiment_emoji(sentiment.avg)}

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    👥 *ПО СПІВРОБІТНИКАХ*

    #{format_employee_breakdown(employees)}

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🏷 *ТОП-5 ТЕМ*

    #{format_topics(topics)}

    #{if length(issues) > 0, do: format_common_issues(issues), else: ""}

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    💬 *ВИСНОВКИ*

    #{generate_conclusion(sentiment, stats, employees)}

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🎤 *ЗАЛИШАЙТЕСЬ НА ЗВ'ЯЗКУ!*

    Гарних вихідних! 🎉
    Побачимось в понеділок з новими інсайтами!

    _Згенеровано Kaminskyi Epic Analytics_ ✨
    """
  end

  defp format_employee_breakdown(employees) do
    employees
    |> Enum.take(10)
    |> Enum.map(fn emp ->
      "• *#{emp.name}*: #{emp.count} відгуків, #{emp.sentiment_label} #{sentiment_emoji_label(emp.sentiment_label)}"
    end)
    |> Enum.join("\n")
  end

  defp format_topics(topics) do
    if length(topics) == 0 do
      "_Недостатньо даних для аналізу тем_"
    else
      topics
      |> Enum.with_index(1)
      |> Enum.map(fn {{topic, count}, index} ->
        "#{index}. *#{topic}* — #{count} #{pluralize(count, "раз", "рази", "разів")}"
      end)
      |> Enum.join("\n")
    end
  end

  defp format_common_issues(issues) do
    """
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ⚠️ *СПІЛЬНІ ПРОБЛЕМИ*

    #{issues |> Enum.map(fn {issue, count} -> "• #{issue} (#{count}x)" end) |> Enum.join("\n")}
    """
  end

  defp generate_conclusion(sentiment, _stats, _employees) do
    cond do
      sentiment.avg >= 0.6 ->
        "✅ Відмінний тиждень! Переважно позитивні відгуки. Команда працює на високому рівні! 🚀"

      sentiment.avg >= 0.2 ->
        "👍 Загалом добрий тиждень з переважно позитивною тональністю. Є що покращити, але напрямок правильний!"

      sentiment.avg >= -0.2 ->
        "⚖️ Змішані результати. Рівна кількість позитивних та негативних моментів. Варто звернути увагу на проблемні зони."

      true ->
        "⚠️ Складний тиждень з переважно негативними відгуками. Рекомендуємо детально проаналізувати проблеми та вжити заходів."
    end
  end

  defp format_date_range do
    now = Date.utc_today()
    week_ago = Date.add(now, -7)
    "#{Calendar.strftime(week_ago, "%d.%m")} - #{Calendar.strftime(now, "%d.%m")}"
  end

  defp sentiment_emoji(score) when score >= 0.5, do: "😊"
  defp sentiment_emoji(score) when score >= 0.0, do: "😐"
  defp sentiment_emoji(_), do: "😟"

  defp sentiment_emoji_label("positive"), do: "😊"
  defp sentiment_emoji_label("neutral"), do: "😐"
  defp sentiment_emoji_label("negative"), do: "😟"

  defp categorize_sentiment(score) when score >= 0.3, do: "позитивна"
  defp categorize_sentiment(score) when score >= -0.3, do: "нейтральна"
  defp categorize_sentiment(_), do: "негативна"

  defp average([]), do: 0.0
  defp average(list), do: Enum.sum(list) / length(list)

  defp pluralize(1, one, _, _), do: one
  defp pluralize(n, _, few, _) when n in 2..4, do: few
  defp pluralize(_, _, _, many), do: many

  defp get_active_user_ids do
    # Отримуємо унікальні user_ids з feedbacks за останній місяць
    month_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    Feedbacks.filter_feedbacks(%{from: month_ago})
    |> Enum.map(& &1.telegram_user_id)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end
end
