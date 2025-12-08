defmodule FeedbackBot.Cache do
  @moduledoc """
  Redis-backed cache для оптимізації швидкості запитів
  """

  def child_spec(_opts) do
    redis_url = Application.get_env(:feedback_bot, :redis_url, "redis://localhost:6379")

    %{
      id: __MODULE__,
      start: {Redix, :start_link, [redis_url, [name: __MODULE__]]}
    }
  end

  @doc """
  Отримати значення з кешу
  """
  def get(key) do
    case Redix.command(__MODULE__, ["GET", key]) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, value} -> {:ok, Jason.decode!(value)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Зберегти значення в кеш з TTL (у секундах)
  """
  def put(key, value, ttl \\ 300) do
    json_value = Jason.encode!(value)
    Redix.command(__MODULE__, ["SETEX", key, ttl, json_value])
  end

  @doc """
  Видалити ключ з кешу
  """
  def delete(key) do
    Redix.command(__MODULE__, ["DEL", key])
  end

  @doc """
  Видалити всі ключі за патерном
  """
  def delete_pattern(pattern) do
    case Redix.command(__MODULE__, ["KEYS", pattern]) do
      {:ok, keys} when is_list(keys) and length(keys) > 0 ->
        Redix.command(__MODULE__, ["DEL" | keys])

      _ ->
        {:ok, 0}
    end
  end

  @doc """
  Кешований запит з автоматичним fallback
  """
  def fetch(key, ttl \\ 300, fallback_fn) do
    case get(key) do
      {:ok, value} ->
        value

      {:error, :not_found} ->
        value = fallback_fn.()
        put(key, value, ttl)
        value
    end
  end
end
