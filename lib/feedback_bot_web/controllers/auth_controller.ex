defmodule FeedbackBotWeb.AuthController do
  use FeedbackBotWeb, :controller

  def login(conn, _params) do
    # Рендеримо просту сторінку з Telegram Login Widget
    html(conn, """
    <!DOCTYPE html>
    <html lang="uk">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Авторизація | FeedbackBot</title>
      <script src="https://cdn.tailwindcss.com"></script>
    </head>
    <body class="bg-gradient-to-br from-violet-50 via-purple-50 to-pink-50 min-h-screen flex items-center justify-center">
      <div class="bg-white shadow-2xl rounded-3xl p-12 max-w-md w-full border-4 border-violet-600">
        <div class="text-center mb-8">
          <h1 class="text-4xl font-black bg-gradient-to-r from-violet-600 to-purple-600 bg-clip-text text-transparent mb-4">
            🔐 FeedbackBot
          </h1>
          <p class="text-gray-600 text-lg font-semibold">
            Авторизація обов'язкова
          </p>
        </div>

        <div class="bg-violet-50 border-2 border-violet-200 rounded-xl p-6 mb-6">
          <p class="text-sm text-gray-700 mb-4">
            ⚠️ <strong>Увага!</strong> Доступ до системи мають лише авторизовані користувачі.
          </p>
          <p class="text-sm text-gray-600">
            Ваш Telegram ID має бути в білому списку системи.
          </p>
        </div>

        <div class="flex justify-center mb-6">
          <script async src="https://telegram.org/js/telegram-widget.js?22"
                  data-telegram-login="#{get_bot_username()}"
                  data-size="large"
                  data-auth-url="#{url(~p"/auth/telegram")}"
                  data-request-access="write"></script>
        </div>

        <div class="text-center text-xs text-gray-500 mt-8">
          <p>🔒 Захищено Telegram Login Widget</p>
          <p class="mt-2">Ваші дані залишаються конфіденційними</p>
        </div>
      </div>
    </body>
    </html>
    """)
  end

  def telegram_callback(conn, params) do
    # Перевіряємо підпис від Telegram
    with {:ok, user_data} <- verify_telegram_auth(params),
         true <- authorized?(user_data["id"]) do
      conn
      |> put_session(:telegram_user_id, user_data["id"])
      |> put_session(:telegram_username, user_data["username"])
      |> put_session(:telegram_first_name, user_data["first_name"])
      |> put_flash(:info, "✅ Авторизація успішна! Вітаємо, #{user_data["first_name"]}!")
      |> redirect(to: "/")
    else
      {:error, :invalid_signature} ->
        conn
        |> put_flash(:error, "⛔️ Невалідний підпис. Спробуйте ще раз.")
        |> redirect(to: "/auth/login")

      false ->
        conn
        |> put_flash(
          :error,
          "⛔️ Ваш Telegram ID не має доступу до системи. Зверніться до адміністратора."
        )
        |> redirect(to: "/auth/login")
    end
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "👋 Ви вийшли з системи")
    |> redirect(to: "/auth/login")
  end

  defp verify_telegram_auth(params) do
    # Telegram відправляє: id, first_name, username, photo_url, auth_date, hash
    bot_token = Application.fetch_env!(:ex_gram, :token)

    # Створюємо data_check_string
    data_check_array =
      params
      |> Map.drop(["hash"])
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.sort()
      |> Enum.join("\n")

    # Генеруємо secret_key = SHA256(bot_token)
    secret_key = :crypto.hash(:sha256, bot_token)

    # Генеруємо hash = HMAC_SHA256(data_check_string, secret_key)
    calculated_hash =
      :crypto.mac(:hmac, :sha256, secret_key, data_check_array)
      |> Base.encode16(case: :lower)

    received_hash = params["hash"]

    if calculated_hash == received_hash do
      {:ok, params}
    else
      {:error, :invalid_signature}
    end
  end

  defp authorized?(user_id) when is_binary(user_id) do
    case Integer.parse(user_id) do
      {int_id, ""} -> authorized?(int_id)
      _ -> false
    end
  end

  defp authorized?(user_id) when is_integer(user_id) do
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

  defp get_bot_username do
    # Отримуємо username бота з env або конфігу
    System.get_env("TELEGRAM_BOT_USERNAME") || "YourBotUsername"
  end
end
