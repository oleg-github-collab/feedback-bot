defmodule FeedbackBot.Bot.Handler do
  @moduledoc """
  Telegram Bot Handler з продуманим флоу для запису голосового фідбеку.

  Флоу бота:
  1. /start - Вітання та перевірка доступу користувача
  2. Список співробітників у вигляді inline кнопок
  3. Після вибору співробітника - запит аудіо
  4. Обробка аудіо через Whisper API
  5. Аналіз через GPT-4o mini
  6. Збереження та підтвердження
  """

  use ExGram.Bot,
    name: __MODULE__,
    setup_commands: true

  require Logger
  alias FeedbackBot.{Employees, Feedbacks, AI}
  import ExGram.Dsl.Keyboard

  command("start")
  command("help")
  command("list")
  command("analytics")
  command("cancel")

  middleware(ExGram.Middleware.IgnoreUsername)

  def bot(), do: FeedbackBot.Bot.Handler

  # Встановлюємо Menu Button при старті
  def setup_menu_button do
    token = Application.fetch_env!(:ex_gram, :token)

    # Встановлюємо Web App як menu button для всіх користувачів
    ExGram.set_chat_menu_button(
      menu_button: %{
        type: "web_app",
        text: "📊 Аналітика",
        web_app: %{url: "https://feedback-bot-production-5dda.up.railway.app"}
      },
      token: token
    )
  end

  def handle({:command, :start, %{from: from}}, context) do
    if authorized?(from.id) do
      # Очищуємо стан при старті
      FeedbackBot.Bot.State.clear_state(from.id)

      keyboard = [
        [
          %{text: "🎤 Записати Фідбек", callback_data: "action:start_feedback"}
        ],
        [
          %{
            text: "📊 Переглянути Аналітику",
            web_app: %{url: "https://feedback-bot-production-5dda.up.railway.app"}
          }
        ]
      ]

      markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

      answer(context, """
      👋 *Вітаю у FeedbackBot!*

      Цей бот допоможе вам швидко записати голосовий фідбек про роботу співробітників.

      ✨ *Що можна зробити?*

      🎤 *Записати фідбек* — оберіть співробітника та надішліть голосове повідомлення
      📊 *Переглянути аналітику* — відкрийте веб-інтерфейс з детальною статистикою

      Оберіть дію нижче:
      """, parse_mode: "Markdown", reply_markup: markup)
    else
      answer(context, "⛔️ У вас немає доступу до цього бота.")
    end
  end

  def handle({:command, :help, _msg}, context) do
    answer(context, """
    📖 Як користуватися ботом:

    1️⃣ Натисніть /start або /list
    2️⃣ Оберіть співробітника зі списку
    3️⃣ Запишіть голосове повідомлення з фідбеком
    4️⃣ Надішліть аудіо - бот автоматично обробить його

    ℹ️ Команди:
    /list - Показати список співробітників
    /analytics - Відкрити веб-аналітику
    /cancel - Скасувати поточну дію
    /help - Показати цю довідку
    """)
  end

  def handle({:command, :list, _msg}, context) do
    show_employee_list(context)
  end

  def handle({:command, :analytics, _msg}, context) do
    web_app_button = [
      [
        %{
          text: "📊 Відкрити Веб-Аналітику",
          web_app: %{url: "https://feedback-bot-production-5dda.up.railway.app"}
        }
      ]
    ]

    markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: web_app_button}

    answer(context, """
    📊 *Аналітика та Звіти*

    Натисніть кнопку нижче щоб відкрити веб-інтерфейс з повною аналітикою:

    📈 Доступні розділи:
    • Головна статистика
    • Список співробітників
    • Всі фідбеки
    • Розширена аналітика з графіками
    • Аналіз по періодах

    🔐 Дані доступні тільки авторизованим користувачам.
    """, parse_mode: "Markdown", reply_markup: markup)
  end

  def handle({:command, :cancel, _msg}, context) do
    # Очищуємо стан користувача
    FeedbackBot.Bot.State.clear_state(context.update.message.from.id)
    answer(context, "❌ Скасовано. Натисніть /start щоб почати знову.")
  end

  # Обробка callback query від inline кнопок
  def handle({:callback_query, %{data: "action:start_feedback"} = query}, context) do
    ExGram.answer_callback_query(query.id, text: "✅ Починаємо запис фідбеку")

    edit(context, query.message, """
    🎤 *КРОК 1 з 3: Оберіть співробітника*

    Виберіть співробітника, про якого ви хочете залишити фідбек:
    """, parse_mode: "Markdown")

    show_employee_list_inline(context, query.message.chat.id, query.message.message_id)
  end

  def handle({:callback_query, %{data: "action:back_to_start"} = query}, context) do
    user_id = query.from.id
    FeedbackBot.Bot.State.clear_state(user_id)

    ExGram.answer_callback_query(query.id, text: "🏠 Повернення на початок")

    keyboard = [
      [
        %{text: "🎤 Записати Фідбек", callback_data: "action:start_feedback"}
      ],
      [
        %{
          text: "📊 Переглянути Аналітику",
          web_app: %{url: "https://feedback-bot-production-5dda.up.railway.app"}
        }
      ]
    ]

    markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

    edit(context, query.message, """
    👋 *Вітаю у FeedbackBot!*

    Цей бот допоможе вам швидко записати голосовий фідбек про роботу співробітників.

    ✨ *Що можна зробити?*

    🎤 *Записати фідбек* — оберіть співробітника та надішліть голосове повідомлення
    📊 *Переглянути аналітику* — відкрийте веб-інтерфейс з детальною статистикою

    Оберіть дію нижче:
    """, parse_mode: "Markdown", reply_markup: markup)
  end

  def handle({:callback_query, %{data: "employee:" <> employee_id} = query}, context) do
    user_id = query.from.id

    case Employees.get_employee(employee_id) do
      nil ->
        ExGram.answer_callback_query(query.id, text: "❌ Співробітника не знайдено")

      employee ->
        # Зберігаємо обраного співробітника в стані
        FeedbackBot.Bot.State.set_state(user_id, :selected_employee, employee_id)

        ExGram.answer_callback_query(query.id, text: "✅ Обрано: #{employee.name}")

        keyboard = [
          [%{text: "🏠 Повернутись на початок", callback_data: "action:back_to_start"}]
        ]

        markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

        edit(context, query.message, """
        ✅ *КРОК 2 з 3: Запишіть голосовий фідбек*

        Співробітник: *#{employee.name}*

        🎤 *Як записати фідбек:*
        1. Натисніть на значок мікрофону 🎤 у полі вводу
        2. Запишіть ваш відгук (тримайте кнопку натиснутою)
        3. Відпустіть кнопку та надішліть аудіо

        💡 *Про що розповісти:*
        • Що вдалося добре? Які сильні сторони?
        • Є якісь проблеми чи виклики?
        • Що можна покращити?
        • Загальне враження від співпраці

        ⏱ *Рекомендована тривалість:* 30 секунд - 2 хвилини

        _Після відправки аудіо бот автоматично розпізнає мову та проаналізує тональність_
        """, parse_mode: "Markdown", reply_markup: markup)
    end
  end

  # Обробка голосових повідомлень
  def handle({:message, %{voice: voice, from: from} = msg}, context) do
    if authorized?(from.id) do
      handle_voice_message(voice, from, msg, context)
    else
      answer(context, "⛔️ У вас немає доступу до цього бота.")
    end
  end

  # Обробка аудіофайлів
  def handle({:message, %{audio: audio, from: from} = msg}, context) do
    if authorized?(from.id) do
      handle_voice_message(audio, from, msg, context)
    else
      answer(context, "⛔️ У вас немає доступу до цього бота.")
    end
  end

  # Обробка текстових повідомлень (для випадків коли користувач надсилає текст)
  def handle({:message, %{text: text, from: from}}, context) when not is_nil(text) do
    if authorized?(from.id) do
      case FeedbackBot.Bot.State.get_state(from.id, :selected_employee) do
        nil ->
          answer(context, "👋 Натисніть /start щоб почати")

        _employee_id ->
          answer(context, """
          🎤 Будь ласка, надішліть голосове повідомлення, а не текст.

          Щоб записати голосове повідомлення:
          1. Натисніть на значок мікрофону 🎤
          2. Запишіть ваш фідбек
          3. Надішліть аудіо

          Або натисніть /cancel щоб скасувати.
          """)
      end
    end
  end

  def handle(_update, _context), do: :ok

  # === Приватні функції ===

  defp authorized?(user_id) do
    allowed_ids = get_allowed_user_ids()

    case allowed_ids do
      [] ->
        Logger.warning("ALLOWED_USER_IDS not set - denying access")
        false

      ids ->
        user_id in ids
    end
  end

  defp get_allowed_user_ids do
    # Підтримка як одного ID, так і списку
    case Application.get_env(:feedback_bot, :telegram)[:allowed_user_ids] do
      nil ->
        # Fallback на старий формат ALLOWED_USER_ID
        case Application.get_env(:feedback_bot, :telegram)[:allowed_user_id] do
          nil -> []
          id when is_binary(id) -> [String.to_integer(id)]
          id when is_integer(id) -> [id]
        end

      ids when is_binary(ids) ->
        # Формат: "123456789,987654321"
        ids
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(&String.to_integer/1)

      ids when is_list(ids) ->
        # Формат: [123456789, 987654321]
        Enum.map(ids, fn
          id when is_binary(id) -> String.to_integer(id)
          id when is_integer(id) -> id
        end)
    end
  end

  defp show_employee_list(context) do
    employees = Employees.list_active_employees()

    if Enum.empty?(employees) do
      answer(context, """
      ❌ Немає активних співробітників у системі.

      Додайте співробітників через веб-інтерфейс.
      """)
    else
      keyboard =
        employees
        |> Enum.chunk_every(2)
        |> Enum.map(fn chunk ->
          Enum.map(chunk, fn emp ->
            %{text: emp.name, callback_data: "employee:#{emp.id}"}
          end)
        end)

      markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

      answer(context, "👥 Оберіть співробітника:", reply_markup: markup)
    end
  end

  defp show_employee_list_inline(context, chat_id, message_id) do
    employees = Employees.list_active_employees()

    if Enum.empty?(employees) do
      keyboard = [
        [%{text: "🏠 Повернутись на початок", callback_data: "action:back_to_start"}]
      ]

      markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

      ExGram.edit_message_text(
        """
        ❌ Немає активних співробітників у системі.

        Додайте співробітників через веб-інтерфейс.
        """,
        chat_id: chat_id,
        message_id: message_id,
        reply_markup: markup
      )
    else
      keyboard =
        employees
        |> Enum.chunk_every(2)
        |> Enum.map(fn chunk ->
          Enum.map(chunk, fn emp ->
            %{text: "👤 #{emp.name}", callback_data: "employee:#{emp.id}"}
          end)
        end)

      # Додаємо кнопку назад
      keyboard_with_back = keyboard ++ [[%{text: "🏠 Назад", callback_data: "action:back_to_start"}]]

      markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard_with_back}

      ExGram.edit_message_reply_markup(
        chat_id: chat_id,
        message_id: message_id,
        reply_markup: markup
      )
    end
  end

  defp handle_voice_message(voice, from, msg, context) do
    employee_id = FeedbackBot.Bot.State.get_state(from.id, :selected_employee)

    if employee_id do
      # Отримуємо ім'я співробітника
      employee = Employees.get_employee(employee_id)

      answer(context, """
      ✅ *КРОК 3 з 3: Обробка фідбеку*

      🎧 Отримано аудіо (#{voice.duration} сек)
      👤 Співробітник: *#{employee.name}*

      ⏳ *Обробляю ваш фідбек...*

      _Це займе 10-30 секунд:_
      • 🎯 Розпізнавання мови (Whisper AI)
      • 🧠 Аналіз тональності (GPT-4)
      • 💾 Збереження в базу даних

      Зачекайте, будь ласка...
      """, parse_mode: "Markdown")

      # Запускаємо Oban job для обробки
      %{
        "voice" => %{
          "file_id" => voice.file_id,
          "duration" => voice.duration
        },
        "employee_id" => employee_id,
        "user_id" => from.id,
        "message_id" => msg.message_id,
        "chat_id" => msg.chat.id
      }
      |> FeedbackBot.Jobs.ProcessAudioJob.new()
      |> Oban.insert()
    else
      keyboard = [
        [%{text: "🏠 Повернутись на початок", callback_data: "action:back_to_start"}]
      ]

      markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

      answer(context, """
      ❌ *Помилка: Співробітника не обрано*

      Спочатку потрібно обрати співробітника.

      Натисніть /start щоб почати спочатку.
      """, parse_mode: "Markdown", reply_markup: markup)
    end
  end

end
