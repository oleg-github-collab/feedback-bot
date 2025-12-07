defmodule FeedbackBot.AI.Multipart do
  @moduledoc """
  Простий multipart/form-data builder для HTTP запитів
  """

  defstruct parts: [], boundary: nil

  def new do
    %__MODULE__{
      boundary: generate_boundary(),
      parts: []
    }
  end

  def add_part(%__MODULE__{parts: parts} = multipart, part) do
    %{multipart | parts: [part | parts]}
  end

  def content_type(%__MODULE__{boundary: boundary}, base \\ "multipart/form-data") do
    "#{base}; boundary=#{boundary}"
  end

  def content_length(%__MODULE__{} = multipart) do
    multipart
    |> body_binary()
    |> byte_size()
  end

  def body_binary(%__MODULE__{parts: parts, boundary: boundary}) do
    parts
    |> Enum.reverse()
    |> Enum.map(&part_binary(&1, boundary))
    |> Kernel.++([end_boundary(boundary)])
    |> IO.iodata_to_binary()
  end

  defp part_binary(%{name: name, content: content, headers: headers}, boundary) do
    [
      "--#{boundary}\r\n",
      "Content-Disposition: form-data; name=\"#{name}\"",
      extra_headers(headers),
      "\r\n\r\n",
      content,
      "\r\n"
    ]
  end

  defp extra_headers([]), do: ""

  defp extra_headers(headers) do
    headers
    |> Enum.map(fn {key, value} -> "; #{key}=\"#{value}\"" end)
    |> Enum.join("")
  end

  defp end_boundary(boundary), do: "--#{boundary}--\r\n"

  defp generate_boundary do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end

  defmodule Part do
    def text_field(content, name) do
      %{
        name: name,
        content: to_string(content),
        headers: []
      }
    end

    def file_field(path, name) do
      filename = Path.basename(path)
      content = File.read!(path)

      %{
        name: name,
        content: content,
        headers: [filename: filename]
      }
    end

    def file_content(content, name, filename) do
      %{
        name: name,
        content: content,
        headers: [filename: filename]
      }
    end
  end
end
