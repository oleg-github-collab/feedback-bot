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

    headers = [
      {"Authorization", "Bearer #{api_key}"}
    ]

    Logger.info("Building multipart request...")

    multipart =
      Multipart.new()
      |> Multipart.add_part(Multipart.Part.file_field(audio_file_path, :file))
      |> Multipart.add_part(Multipart.Part.text_field(model, :model))
      |> Multipart.add_part(Multipart.Part.text_field("uk", :language))

    content_length = Multipart.content_length(multipart)
    content_type = Multipart.content_type(multipart, "multipart/form-data")

    Logger.info("Content-Length: #{content_length}, Content-Type: #{content_type}")

    headers = headers ++ [{"Content-Type", content_type}, {"Content-Length", to_string(content_length)}]

    body_binary = Multipart.body_binary(multipart)

    Logger.info("Sending POST request to Whisper API...")

    case HTTPoison.post(@api_url, body_binary, headers, timeout: 60_000, recv_timeout: 60_000) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"text" => text}} ->
            Logger.info("Whisper transcription successful")
            {:ok, text}

          {:error, error} ->
            Logger.error("Failed to parse Whisper response: #{inspect(error)}")
            {:error, "Failed to parse response"}
        end

      {:ok, %{status_code: status_code, body: body}} ->
        Logger.error("Whisper API error #{status_code}: #{body}")
        {:error, "API error: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP error calling Whisper API: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end
end
