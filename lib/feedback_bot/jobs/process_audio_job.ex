defmodule FeedbackBot.Jobs.ProcessAudioJob do
  @moduledoc """
  Oban job для асинхронної обробки аудіо фідбеку
  """
  use Oban.Worker, queue: :audio_processing, max_attempts: 3

  alias FeedbackBot.{AI, Employees, Feedbacks}
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "voice" => voice,
          "employee_id" => employee_id,
          "user_id" => user_id,
          "message_id" => message_id,
          "chat_id" => chat_id
        }
      }) do
    Logger.info("Processing audio feedback for employee #{employee_id}")
    Logger.info("Starting download for file_id: #{voice["file_id"]}")

    with {:ok, file_path} <- download_audio(voice["file_id"]),
         _ = Logger.info("Download successful: #{file_path}"),
         {:ok, transcription} <- AI.WhisperClient.transcribe(file_path),
         _ = Logger.info("Transcription successful: #{String.slice(transcription, 0..50)}..."),
         {:ok, analysis} <- AI.GPTClient.analyze_feedback(transcription, employee_id),
         _ = Logger.info("Analysis successful") do
      # Зберігаємо фідбек у базі
      feedback_attrs = %{
        employee_id: employee_id,
        audio_file_id: voice["file_id"],
        audio_file_path: file_path,
        duration_seconds: voice["duration"],
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
        telegram_message_id: message_id,
        telegram_user_id: user_id,
        raw_ai_response: analysis.raw_response,
        processing_status: "completed"
      }

      case Feedbacks.create_feedback(feedback_attrs) do
        {:ok, feedback} ->
          # Відправляємо результат в Telegram
          send_success_message(chat_id, feedback, analysis)

          # Очищуємо стан користувача
          FeedbackBot.Bot.State.clear_state(user_id)

          # Broadcast для real-time оновлення dashboard
          Phoenix.PubSub.broadcast(
            FeedbackBot.PubSub,
            "feedbacks",
            {:new_feedback, feedback}
          )

          :ok

        {:error, changeset} ->
          Logger.error("Failed to save feedback: #{inspect(changeset)}")
          send_error_message(chat_id, "Помилка при збереженні фідбеку")
          {:error, changeset}
      end
    else
      {:error, reason} ->
        Logger.error("Failed to process audio: #{inspect(reason, pretty: true, limit: :infinity)}")
        send_error_message(chat_id, "Помилка при обробці аудіо: #{format_error(reason)}")
        {:error, reason}

      other ->
        Logger.error("Unexpected result in with clause: #{inspect(other, pretty: true, limit: :infinity)}")
        send_error_message(chat_id, "Неочікувана помилка при обробці")
        {:error, :unexpected_result}
    end
  end

  defp download_audio(file_id) do
    with {:ok, file} <- ExGram.get_file(file_id),
         _ = Logger.info("Got file info: #{inspect(file)}"),
         file_path = file.file_path,
         _ = Logger.info("File path: #{file_path}"),
         {:ok, response} <- ExGram.download_file(file_path),
         _ = Logger.info("Downloaded file, size: #{byte_size(response.body)} bytes") do
      # Зберігаємо файл локально
      local_path = Path.join([System.tmp_dir!(), "#{file_id}.ogg"])
      File.write!(local_path, response.body)
      Logger.info("Saved to: #{local_path}")

      {:ok, local_path}
    else
      error ->
        Logger.error("Download failed: #{inspect(error, pretty: true, limit: :infinity)}")
        {:error, "Failed to download audio: #{inspect(error)}"}
    end
  end

  defp send_success_message(chat_id, feedback, analysis) do
    employee = Employees.get_employee!(feedback.employee_id)

    message = """
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ✅ *ВСЕ ГОТОВО! ФІДБЕК ОБРОБЛЕНО*
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    🎉 *Ваш голосовий фідбек успішно:*
    ✓ Розпізнано за допомогою Whisper AI
    ✓ Проаналізовано через GPT-4o mini
    ✓ Збережено в базу даних
    ✓ Додано до аналітики

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    📊 *РЕЗУЛЬТАТИ АНАЛІЗУ:*

    👤 *Співробітник:* #{employee.name}
    ⏱ *Тривалість аудіо:* #{feedback.duration_seconds} сек
    📊 *Тональність:* #{format_sentiment(analysis.sentiment_label, analysis.sentiment_score)}
    🎯 *Важливість:* #{format_urgency(analysis.urgency_score)}

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    📝 *РЕЗЮМЕ ФІДБЕКУ:*
    _#{analysis.summary}_

    #{format_analysis_details(analysis)}

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ✅ *ПІДТВЕРДЖЕННЯ:*

    Ваш фідбек було успішно збережено та проаналізовано. Тепер він доступний в аналітиці для перегляду та звітності.

    Дані вже враховані в:
    • Загальній статистиці команди
    • Профілі співробітника
    • Трендах та графіках
    • AI рекомендаціях

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🎯 *НАСТУПНІ КРОКИ:*

    📊 Перегляньте аналітику щоб побачити результати
    🎤 Або запишіть фідбек про іншого співробітника

    _Дякуємо за ваш внесок!_ 🙏
    """

    keyboard = [
      [
        %{text: "🎤 Записати ще один фідбек", callback_data: "action:start_feedback"}
      ],
      [
        %{
          text: "📊 Відкрити Аналітику",
          web_app: %{url: "https://feedback-bot-production-5dda.up.railway.app"}
        }
      ]
    ]

    markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

    ExGram.send_message(chat_id, message, parse_mode: "Markdown", reply_markup: markup)
  end

  defp send_error_message(chat_id, error_text) do
    message = """
    ❌ #{error_text}

    Спробуйте ще раз або натисніть /cancel
    """

    ExGram.send_message(chat_id, message)
  end

  defp format_sentiment("positive", score), do: "😊 Позитивна (#{Float.round(score, 2)})"
  defp format_sentiment("neutral", score), do: "😐 Нейтральна (#{Float.round(score, 2)})"
  defp format_sentiment("negative", score), do: "😟 Негативна (#{Float.round(score, 2)})"

  defp format_urgency(score) when score >= 0.8, do: "🔴 Висока"
  defp format_urgency(score) when score >= 0.5, do: "🟡 Середня"
  defp format_urgency(_score), do: "🟢 Низька"

  defp format_analysis_details(analysis) do
    parts = []

    parts =
      if length(analysis.key_points) > 0 do
        [
          """
          🔑 *Ключові моменти:*
          #{Enum.map_join(analysis.key_points, "\n", &"• #{&1}")}
          """
          | parts
        ]
      else
        parts
      end

    parts =
      if length(analysis.strengths) > 0 do
        [
          """
          ✨ *Сильні сторони:*
          #{Enum.map_join(analysis.strengths, "\n", &"• #{&1}")}
          """
          | parts
        ]
      else
        parts
      end

    parts =
      if length(analysis.issues) > 0 do
        issue_text =
          Enum.map_join(analysis.issues, "\n", fn issue ->
            "• #{issue["description"]} (важливість: #{issue["severity"]})"
          end)

        [
          """
          ⚠️ *Проблеми:*
          #{issue_text}
          """
          | parts
        ]
      else
        parts
      end

    parts =
      if length(analysis.improvement_areas) > 0 do
        [
          """
          💡 *Сфери для покращення:*
          #{Enum.map_join(analysis.improvement_areas, "\n", &"• #{&1}")}
          """
          | parts
        ]
      else
        parts
      end

    Enum.join(Enum.reverse(parts), "\n")
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)
end
