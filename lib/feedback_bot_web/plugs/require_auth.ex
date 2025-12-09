defmodule FeedbackBotWeb.Plugs.RequireAuth do
  @moduledoc """
  Plug для обмеження доступу до веб-апки лише авторизованим користувачам
  Перевіряє чи Telegram user_id в whitelist
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    # Дозволяємо доступ до login сторінки
    if conn.request_path == "/auth/login" or conn.request_path =="/auth/telegram" do
      conn
    else
      user_id = get_session(conn, :telegram_user_id)

      if user_id && authorized?(user_id) do
        conn
      else
        conn
        |> put_flash(:error, "⛔️ Доступ заборонено. Авторизуйтесь через Telegram.")
        |> redirect(to: "/auth/login")
        |> halt()
      end
    end
  end

  defp authorized?(user_id) do
    allowed_ids = get_allowed_user_ids()
    user_id in allowed_ids
  end

  defp get_allowed_user_ids do
    case System.get_env("ALLOWED_USER_IDS") do
      nil ->
        []

      ids_string ->
        ids_string
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(fn id ->
          case Integer.parse(id) do
            {int_id, ""} -> int_id
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
    end
  end
end
