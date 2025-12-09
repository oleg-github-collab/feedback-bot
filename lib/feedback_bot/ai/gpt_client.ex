defmodule FeedbackBot.AI.GPTClient do
  @moduledoc """
  Клієнт для OpenAI GPT-4o mini для аналізу фідбеку
  """

  require Logger

  @api_url "https://api.openai.com/v1/chat/completions"

  def analyze_feedback(transcription, employee_id) do
    employee = FeedbackBot.Employees.get_employee!(employee_id)

    api_key = Application.get_env(:feedback_bot, :openai)[:api_key]
    model = Application.get_env(:feedback_bot, :openai)[:gpt_model] || "gpt-4o-mini"

    system_prompt = """
    Ти — експертний AI аналітик фідбеку співробітників з глибоким розумінням психології та управління командами.

    Твоя задача — проаналізувати голосовий фідбек про роботу співробітника та надати ультра-детальний структурований аналіз.

    Аналізуй на українській мові. Будь конкретним, інсайтним та дієвим.

    Твоя відповідь ОБОВ'ЯЗКОВО має бути у форматі JSON з такою структурою:
    {
      "summary": "Короткий зміст фідбеку (2-3 речення)",
      "sentiment_score": число від -1.0 до 1.0,
      "sentiment_label": "positive" | "neutral" | "negative",
      "mood_intensity": число від 0.0 до 1.0 (наскільки емоційно забарвлений фідбек),
      "key_points": ["Ключовий момент 1", "Ключовий момент 2", ...],
      "issues": [
        {
          "description": "Опис проблеми",
          "severity": "low" | "medium" | "high" | "critical",
          "category": "категорія",
          "suggested_solution": "Пропонований варіант вирішення"
        }
      ],
      "strengths": ["Сильна сторона 1", "Сильна сторона 2", ...],
      "improvement_areas": ["Сфера покращення 1", "Сфера покращення 2", ...],
      "topics": ["Тема 1", "Тема 2", ...],
      "action_items": [
        {
          "action": "Конкретна дія",
          "priority": "low" | "medium" | "high" | "urgent",
          "estimated_impact": "Очікуваний вплив",
          "responsible": "Хто повинен виконати"
        }
      ],
      "urgency_score": число від 0.0 до 1.0 (наскільки терміново потрібно реагувати),
      "impact_score": число від 0.0 до 1.0 (наскільки важливий цей фідбек),
      "trend_direction": "improving" | "declining" | "stable" | "unknown",
      "psychological_indicators": {
        "stress_level": "low" | "medium" | "high",
        "motivation": "low" | "medium" | "high",
        "burnout_risk": "low" | "medium" | "high"
      },
      "recommended_follow_up": "Рекомендації щодо подальших дій"
    }

    Sentiment score:
    - 0.7 до 1.0: дуже позитивний
    - 0.3 до 0.7: помірно позитивний
    - -0.3 до 0.3: нейтральний
    - -0.7 до -0.3: помірно негативний
    - -1.0 до -0.7: дуже негативний

    Categories: communication, technical_skills, work_quality, deadlines, teamwork, attitude, workload, leadership, tools, other

    Urgency score базується на:
    - Критичність проблем
    - Емоційний стан
    - Ризик ескалації

    Impact score базується на:
    - Вплив на продуктивність
    - Вплив на команду
    - Стратегічна важливість
    """

    user_prompt = """
    Співробітник: #{employee.name}

    Транскрипція фідбеку:
    #{transcription}

    Проаналізуй цей фідбек та надай структурований JSON аналіз.
    """

    payload = %{
      model: model,
      messages: [
        %{role: "system", content: system_prompt},
        %{role: "user", content: user_prompt}
      ],
      response_format: %{type: "json_object"},
      temperature: 0.3
    }

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.post(@api_url, Jason.encode!(payload), headers, timeout: 60_000, recv_timeout: 60_000) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]}} ->
            case Jason.decode(content) do
              {:ok, analysis} ->
                Logger.info("GPT analysis successful")
                {:ok, normalize_analysis(analysis)}

              {:error, error} ->
                Logger.error("Failed to parse GPT JSON response: #{inspect(error)}")
                Logger.error("Raw content: #{content}")
                {:error, "Failed to parse analysis"}
            end

          {:error, error} ->
            Logger.error("Failed to parse GPT response: #{inspect(error)}")
            {:error, "Failed to parse response"}
        end

      {:ok, %{status_code: status_code, body: body}} ->
        Logger.error("GPT API error #{status_code}: #{body}")
        {:error, "API error: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP error calling GPT API: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  defp normalize_analysis(raw_analysis) do
    %{
      summary: Map.get(raw_analysis, "summary", ""),
      sentiment_score: Map.get(raw_analysis, "sentiment_score", 0.0),
      sentiment_label: Map.get(raw_analysis, "sentiment_label", "neutral"),
      mood_intensity: Map.get(raw_analysis, "mood_intensity", 0.0),
      key_points: Map.get(raw_analysis, "key_points", []),
      issues: Map.get(raw_analysis, "issues", []),
      strengths: Map.get(raw_analysis, "strengths", []),
      improvement_areas: Map.get(raw_analysis, "improvement_areas", []),
      topics: Map.get(raw_analysis, "topics", []),
      action_items: Map.get(raw_analysis, "action_items", []),
      urgency_score: Map.get(raw_analysis, "urgency_score", 0.0),
      impact_score: Map.get(raw_analysis, "impact_score", 0.0),
      trend_direction: Map.get(raw_analysis, "trend_direction", "unknown"),
      psychological_indicators: Map.get(raw_analysis, "psychological_indicators", %{}),
      recommended_follow_up: Map.get(raw_analysis, "recommended_follow_up", ""),
      raw_response: raw_analysis
    }
  end

  @doc """
  Генерує довільний текст через GPT (для performance reviews, summaries, тощо)
  """
  def generate_text(prompt) do
    api_key = Application.get_env(:feedback_bot, :openai)[:api_key]
    model = Application.get_env(:feedback_bot, :openai)[:gpt_model] || "gpt-4o-mini"

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    body =
      Jason.encode!(%{
        model: model,
        messages: [
          %{
            role: "system",
            content:
              "Ти — професійний бізнес-аналітик та HR експерт. Створюй чіткі, структуровані та actionable тексти українською мовою."
          },
          %{role: "user", content: prompt}
        ],
        temperature: 0.7,
        max_tokens: 2000
      })

    case HTTPoison.post(@api_url, body, headers, timeout: 60_000, recv_timeout: 60_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"choices" => [%{"message" => %{"content" => text}} | _]}} ->
            {:ok, text}

          error ->
            Logger.error("Failed to parse GPT response: #{inspect(error)}")
            {:error, "Failed to parse response"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        Logger.error("GPT API error #{status_code}: #{response_body}")
        {:error, "API error: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP error calling GPT API: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end
end
