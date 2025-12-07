defmodule FeedbackBot.Bot.State do
  @moduledoc """
  Простий модуль для збереження стану користувачів бота.
  Використовує ETS для швидкого доступу.
  """

  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    :ets.new(:bot_state, [:named_table, :public, read_concurrency: true])
    {:ok, %{}}
  end

  @doc """
  Встановлює значення у стані користувача
  """
  def set_state(user_id, key, value) do
    current = get_user_state(user_id)
    new_state = Map.put(current, key, value)
    :ets.insert(:bot_state, {user_id, new_state})
    :ok
  end

  @doc """
  Отримує значення зі стану користувача
  """
  def get_state(user_id, key) do
    user_id
    |> get_user_state()
    |> Map.get(key)
  end

  @doc """
  Отримує весь стан користувача
  """
  def get_user_state(user_id) do
    case :ets.lookup(:bot_state, user_id) do
      [{^user_id, state}] -> state
      [] -> %{}
    end
  end

  @doc """
  Очищує весь стан користувача
  """
  def clear_state(user_id) do
    :ets.delete(:bot_state, user_id)
    :ok
  end
end
