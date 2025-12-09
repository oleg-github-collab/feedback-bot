defmodule FeedbackBot.AI.WhisperClient do
  @moduledoc """
  Клієнт для OpenAI Whisper API для транскрибації аудіо
  """

  require Logger

  @api_url "https://api.openai.com/v1/audio/transcriptions"

  def transcribe(audio_file_path) do
    Logger.info("Starting Whisper transcription for: #{audio_file_path}")
    Logger.info("File exists? #{File.exists?(audio_file_path)}")
    Logger.info("File size: #{if File.exists?(audio_file_path), do: File.stat!(audio_file_path).size, else: "N/A"} bytes")

    api_key = Application.get_env(:feedback_bot, :openai)[:api_key]
    model = Application.get_env(:feedback_bot, :openai)[:whisper_model] || "whisper-1"

    Logger.info("Using model: #{model}, API key present? #{!is_nil(api_key)}")

    # Використовуємо HTTPoison з ручним multipart/form-data
    Logger.info("Building multipart request...")

    boundary = "----WebKitFormBoundary#{:rand.uniform(1_000_000_000)}"

    file_content = File.read!(audio_file_path)

    body = """
    --#{boundary}\r
    Content-Disposition: form-data; name="file"; filename="audio.ogg"\r
    Content-Type: audio/ogg\r
    \r
    #{file_content}\r
    --#{boundary}\r
    Content-Disposition: form-data; name="model"\r
    \r
    #{model}\r
    --#{boundary}\r
    Content-Disposition: form-data; name="language"\r
    \r
    uk\r
    --#{boundary}--\r
    """

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "multipart/form-data; boundary=#{boundary}"}
    ]

    Logger.info("Sending POST request to Whisper API (body size: #{byte_size(body)} bytes)...")

    case HTTPoison.post(@api_url, body, headers, timeout: 60_000, recv_timeout: 60_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        Logger.info("Got 200 response from Whisper")
        case Jason.decode(response_body) do
          {:ok, %{"text" => text}} ->
            Logger.info("Whisper transcription successful: #{String.slice(text, 0..50)}...")
            {:ok, text}

          {:error, error} ->
            Logger.error("Failed to parse Whisper response: #{inspect(error)}")
            Logger.error("Response body: #{response_body}")
            {:error, "Failed to parse response"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        Logger.error("Whisper API error #{status_code}: #{response_body}")
        {:error, "API error: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP error calling Whisper API: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end
end
