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
  command("manage")
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

  def handle({:command, :list, %{from: from}}, context) do
    if authorized?(from.id) do
      employees = Employees.list_active_employees()

      if Enum.empty?(employees) do
        answer(context, """
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        ❌ *НЕМАЄ АКТИВНИХ СПІВРОБІТНИКІВ*

        Додайте співробітників через /manage
        """, parse_mode: "Markdown")
      else
        keyboard =
          employees
          |> Enum.chunk_every(2)
          |> Enum.map(fn chunk ->
            Enum.map(chunk, fn emp ->
              %{text: "👤 #{emp.name}", callback_data: "employee:#{emp.id}"}
            end)
          end)

        keyboard_with_back = keyboard ++ [[%{text: "🏠 На початок", callback_data: "action:back_to_start"}]]
        markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard_with_back}

        answer(context, """
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        *ПРОГРЕС: 1 з 3 кроків* ⬤○○

        🎤 *КРОК 1: ОБЕРІТЬ СПІВРОБІТНИКА*

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        👥 *Про кого ви хочете залишити фідбек?*

        Натисніть на ім'я співробітника зі списку:
        """, parse_mode: "Markdown", reply_markup: markup)
      end
    else
      answer(context, "⛔️ У вас немає доступу до цього бота.")
    end
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

  def handle({:command, :manage, %{from: from}}, context) do
    if authorized?(from.id) do
      keyboard = [
        [
          %{text: "➕ Додати співробітника", callback_data: "manage:add_employee"}
        ],
        [
          %{text: "✏️ Редагувати співробітника", callback_data: "manage:edit_employee"}
        ],
        [
          %{text: "🗑 Видалити співробітника", callback_data: "manage:delete_employee"}
        ],
        [
          %{text: "👥 Список всіх співробітників", callback_data: "manage:list_all"}
        ],
        [
          %{text: "🏠 Повернутись на початок", callback_data: "action:back_to_start"}
        ]
      ]

      markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

      answer(context, """
      ⚙️ *Управління Співробітниками*

      Оберіть дію для управління базою співробітників:

      ➕ *Додати* — створити нового співробітника
      ✏️ *Редагувати* — змінити дані існуючого
      🗑 *Видалити* — деактивувати співробітника
      👥 *Список* — переглянути всіх співробітників

      Оберіть опцію:
      """, parse_mode: "Markdown", reply_markup: markup)
    else
      answer(context, "⛔️ У вас немає доступу до цього бота.")
    end
  end

  def handle({:command, :cancel, _msg}, context) do
    # Очищуємо стан користувача
    FeedbackBot.Bot.State.clear_state(context.update.message.from.id)
    answer(context, "❌ Скасовано. Натисніть /start щоб почати знову.")
  end

  # Обробка callback query від inline кнопок
  def handle({:callback_query, %{data: "action:start_feedback"} = query}, _context) do
    ExGram.answer_callback_query(query.id, text: "✅ Починаємо запис фідбеку")

    employees = Employees.list_active_employees()

    if Enum.empty?(employees) do
      ExGram.edit_message_text(
        query.message.chat.id,
        query.message.message_id,
        """
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        ❌ *НЕМАЄ СПІВРОБІТНИКІВ*

        Спочатку додайте співробітників через команду /manage

        Або попросіть адміністратора додати їх.
        """,
        parse_mode: "Markdown"
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

      keyboard_with_back = keyboard ++ [[%{text: "🏠 Повернутись на початок", callback_data: "action:back_to_start"}]]
      markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard_with_back}

      ExGram.edit_message_text(
        query.message.chat.id,
        query.message.message_id,
        """
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        *ПРОГРЕС: 1 з 3 кроків* ⬤○○

        🎤 *КРОК 1: ОБЕРІТЬ СПІВРОБІТНИКА*

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        👥 *Про кого ви хочете залишити фідбек?*

        Натисніть на ім'я співробітника зі списку:
        """,
        parse_mode: "Markdown",
        reply_markup: markup
      )
    end
  end

  def handle({:callback_query, %{data: "action:back_to_start"} = query}, _context) do
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

    ExGram.edit_message_text(
      query.message.chat.id,
      query.message.message_id,
      """
      👋 *Вітаю у FeedbackBot!*

      Цей бот допоможе вам швидко записати голосовий фідбек про роботу співробітників.

      ✨ *Що можна зробити?*

      🎤 *Записати фідбек* — оберіть співробітника та надішліть голосове повідомлення
      📊 *Переглянути аналітику* — відкрийте веб-інтерфейс з детальною статистикою

      Оберіть дію нижче:
      """,
      parse_mode: "Markdown",
      reply_markup: markup
    )
  end

  # Обробка управління співробітниками
  def handle({:callback_query, %{data: "manage:add_employee"} = query}, _context) do
    user_id = query.from.id
    FeedbackBot.Bot.State.set_state(user_id, :awaiting_action, "add_employee_name")

    ExGram.answer_callback_query(query.id, text: "✅ Режим додавання")

    ExGram.edit_message_text(
      query.message.chat.id,
      query.message.message_id,
      """
      ➕ *Додавання нового співробітника*

      *Крок 1 з 2:* Введіть ім'я співробітника

      📝 Приклад: Олена Шевченко

      Надішліть ім'я текстовим повідомленням або /cancel щоб скасувати.
      """,
      parse_mode: "Markdown"
    )
  end

  def handle({:callback_query, %{data: "manage:edit_employee"} = query}, context) do
    ExGram.answer_callback_query(query.id, text: "✏️ Оберіть співробітника")

    ExGram.edit_message_text(
      query.message.chat.id,
      query.message.message_id,
      """
      ✏️ *Редагування співробітника*

      Оберіть співробітника для редагування:
      """,
      parse_mode: "Markdown"
    )

    show_employee_list_for_edit(context, query.message.chat.id, query.message.message_id)
  end

  def handle({:callback_query, %{data: "manage:delete_employee"} = query}, context) do
    ExGram.answer_callback_query(query.id, text: "🗑 Оберіть співробітника")

    ExGram.edit_message_text(
      query.message.chat.id,
      query.message.message_id,
      """
      🗑 *Видалення співробітника*

      ⚠️ Співробітник буде деактивований (не видалений з бази).

      Оберіть співробітника:
      """,
      parse_mode: "Markdown"
    )

    show_employee_list_for_delete(context, query.message.chat.id, query.message.message_id)
  end

  def handle({:callback_query, %{data: "manage:list_all"} = query}, _context) do
    employees = Employees.list_all_employees()

    ExGram.answer_callback_query(query.id, text: "👥 Список співробітників")

    list_text =
      if Enum.empty?(employees) do
        "Немає співробітників у системі."
      else
        Enum.map_join(employees, "\n", fn emp ->
          status = if emp.is_active, do: "✅", else: "❌"
          "#{status} *#{emp.name}* (#{emp.email})"
        end)
      end

    keyboard = [
      [%{text: "🏠 Назад", callback_data: "action:back_to_start"}]
    ]

    markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

    ExGram.edit_message_text(
      query.message.chat.id,
      query.message.message_id,
      """
      👥 *Всі співробітники*

      #{list_text}

      ✅ — активний | ❌ — деактивований
      """,
      parse_mode: "Markdown",
      reply_markup: markup
    )
  end

  def handle({:callback_query, %{data: "edit_emp:" <> employee_id} = query}, _context) do
    user_id = query.from.id

    case Employees.get_employee(employee_id) do
      nil ->
        ExGram.answer_callback_query(query.id, text: "❌ Співробітника не знайдено")

      employee ->
        FeedbackBot.Bot.State.set_state(user_id, :awaiting_action, "edit_employee_name")
        FeedbackBot.Bot.State.set_state(user_id, :editing_employee_id, employee_id)

        ExGram.answer_callback_query(query.id, text: "✏️ Редагуємо #{employee.name}")

        keyboard = [
          [%{text: "❌ Скасувати", callback_data: "action:back_to_start"}]
        ]

        markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

        ExGram.edit_message_text(
          query.message.chat.id,
          query.message.message_id,
          """
          ✏️ *Редагування: #{employee.name}*

          Поточні дані:
          📛 Ім'я: *#{employee.name}*
          📧 Email: *#{employee.email}*

          *Крок 1 з 2:* Введіть нове ім'я (або надішліть те саме щоб залишити)

          Надішліть нове ім'я або /cancel
          """,
          parse_mode: "Markdown",
          reply_markup: markup
        )
    end
  end

  def handle({:callback_query, %{data: "delete_emp:" <> employee_id} = query}, _context) do
    case Employees.get_employee(employee_id) do
      nil ->
        ExGram.answer_callback_query(query.id, text: "❌ Співробітника не знайдено")

      employee ->
        case Employees.update_employee(employee, %{is_active: false}) do
          {:ok, _updated} ->
            ExGram.answer_callback_query(query.id, text: "✅ Видалено: #{employee.name}")

            keyboard = [
              [%{text: "🏠 На початок", callback_data: "action:back_to_start"}],
              [%{text: "⚙️ Управління", callback_data: "action:manage_menu"}]
            ]

            markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

            ExGram.edit_message_text(
              query.message.chat.id,
              query.message.message_id,
              """
              ✅ *Співробітника деактивовано*

              👤 *#{employee.name}* більше не відображається у списку активних співробітників.

              📊 Всі фідбеки залишились в базі даних для історії.
              """,
              parse_mode: "Markdown",
              reply_markup: markup
            )

          {:error, _changeset} ->
            ExGram.answer_callback_query(query.id, text: "❌ Помилка при видаленні")
        end
    end
  end

  def handle({:callback_query, %{data: "action:manage_menu"} = query}, _context) do
    ExGram.answer_callback_query(query.id, text: "⚙️ Меню управління")

    keyboard = [
      [
        %{text: "➕ Додати співробітника", callback_data: "manage:add_employee"}
      ],
      [
        %{text: "✏️ Редагувати співробітника", callback_data: "manage:edit_employee"}
      ],
      [
        %{text: "🗑 Видалити співробітника", callback_data: "manage:delete_employee"}
      ],
      [
        %{text: "👥 Список всіх співробітників", callback_data: "manage:list_all"}
      ],
      [
        %{text: "🏠 Повернутись на початок", callback_data: "action:back_to_start"}
      ]
    ]

    markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

    ExGram.edit_message_text(
      query.message.chat.id,
      query.message.message_id,
      """
      ⚙️ *Управління Співробітниками*

      Оберіть дію для управління базою співробітників:

      ➕ *Додати* — створити нового співробітника
      ✏️ *Редагувати* — змінити дані існуючого
      🗑 *Видалити* — деактивувати співробітника
      👥 *Список* — переглянути всіх співробітників

      Оберіть опцію:
      """,
      parse_mode: "Markdown",
      reply_markup: markup
    )
  end

  def handle({:callback_query, %{data: "employee:" <> employee_id} = query}, _context) do
    user_id = query.from.id

    case Employees.get_employee(employee_id) do
      nil ->
        ExGram.answer_callback_query(query.id, text: "❌ Співробітника не знайдено")

      employee ->
        # Зберігаємо обраного співробітника в стані
        FeedbackBot.Bot.State.set_state(user_id, :selected_employee, employee_id)

        ExGram.answer_callback_query(query.id, text: "✅ Обрано: #{employee.name}")

        keyboard = [
          [%{text: "🎤 Детальна інструкція", callback_data: "help:voice_recording"}],
          [%{text: "🏠 Повернутись на початок", callback_data: "action:back_to_start"}]
        ]

        markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

        ExGram.edit_message_text(
          query.message.chat.id,
          query.message.message_id,
          """
          ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          *ПРОГРЕС: 2 з 3 кроків* ⬤⬤○

          ✅ *КРОК 1:* Обрано співробітника
          👤 *#{employee.name}*

          ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          🎤 *КРОК 2: ЗАПИШІТЬ ГОЛОСОВЕ*

          *📱 НА ТЕЛЕФОНІ (найпростіше):*
          1️⃣ Знайдіть значок 🎤 праворуч внизу
          2️⃣ *НАТИСНІТЬ І ТРИМАЙТЕ* палець на 🎤
          3️⃣ Говоріть свій фідбек
          4️⃣ *ВІДПУСТІТЬ* — готово! ✅

          *💻 НА КОМП'ЮТЕРІ:*
          1️⃣ Клацніть 📎 (скріпка)
          2️⃣ Оберіть "Записати голосове"
          3️⃣ Запишіть та натисніть "Відправити"

          ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          💡 *ПРО ЩО ГОВОРИТИ:*
          ✓ Сильні сторони та досягнення
          ✓ Проблеми або складнощі
          ✓ Що покращити
          ✓ Загальне враження

          ⏱ *Тривалість:* 30 сек - 2 хв (оптимально)

          ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          ⚡ *ЩО СТАНЕТЬСЯ ДАЛІ:*
          1. Ви надішлете голосове ✅
          2. Бот підтвердить отримання ✅
          3. AI розпізнає мову (10-20 сек) 🎯
          4. AI проаналізує тональність (10-20 сек) 🧠
          5. Отримаєте результат! 🎉

          ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          ℹ️ Натисніть кнопку нижче для детальної інструкції
          """,
          parse_mode: "Markdown",
          reply_markup: markup
        )
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
      awaiting_action = FeedbackBot.Bot.State.get_state(from.id, :awaiting_action)

      case awaiting_action do
        "add_employee_name" ->
          FeedbackBot.Bot.State.set_state(from.id, :new_employee_name, text)
          FeedbackBot.Bot.State.set_state(from.id, :awaiting_action, "add_employee_email")

          answer(context, """
          ✅ Ім'я збережено: *#{text}*

          *Крок 2 з 2:* Введіть email співробітника

          📧 Приклад: olena.shevchenko@company.com

          Надішліть email або /cancel
          """, parse_mode: "Markdown")

        "add_employee_email" ->
          name = FeedbackBot.Bot.State.get_state(from.id, :new_employee_name)

          case Employees.create_employee(%{name: name, email: text}) do
            {:ok, employee} ->
              FeedbackBot.Bot.State.clear_state(from.id)

              keyboard = [
                [%{text: "🏠 На початок", callback_data: "action:back_to_start"}],
                [%{text: "⚙️ Управління", callback_data: "action:manage_menu"}]
              ]

              markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

              answer(context, """
              🎉 *Співробітника успішно додано!*

              👤 *Ім'я:* #{employee.name}
              📧 *Email:* #{employee.email}
              ✅ *Статус:* Активний

              Співробітник тепер доступний для фідбеків!
              """, parse_mode: "Markdown", reply_markup: markup)

            {:error, changeset} ->
              errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
              error_text = inspect(errors)

              answer(context, """
              ❌ *Помилка при створенні співробітника*

              #{error_text}

              Спробуйте ще раз або натисніть /cancel
              """, parse_mode: "Markdown")
          end

        "edit_employee_name" ->
          FeedbackBot.Bot.State.set_state(from.id, :new_employee_name, text)
          FeedbackBot.Bot.State.set_state(from.id, :awaiting_action, "edit_employee_email")

          answer(context, """
          ✅ Нове ім'я збережено: *#{text}*

          *Крок 2 з 2:* Введіть новий email

          Надішліть email або /cancel
          """, parse_mode: "Markdown")

        "edit_employee_email" ->
          employee_id = FeedbackBot.Bot.State.get_state(from.id, :editing_employee_id)
          name = FeedbackBot.Bot.State.get_state(from.id, :new_employee_name)

          case Employees.get_employee(employee_id) do
            nil ->
              answer(context, "❌ Співробітника не знайдено")

            employee ->
              case Employees.update_employee(employee, %{name: name, email: text}) do
                {:ok, updated} ->
                  FeedbackBot.Bot.State.clear_state(from.id)

                  keyboard = [
                    [%{text: "🏠 На початок", callback_data: "action:back_to_start"}],
                    [%{text: "⚙️ Управління", callback_data: "action:manage_menu"}]
                  ]

                  markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

                  answer(context, """
                  ✅ *Дані оновлено!*

                  👤 *Ім'я:* #{updated.name}
                  📧 *Email:* #{updated.email}
                  """, parse_mode: "Markdown", reply_markup: markup)

                {:error, _changeset} ->
                  answer(context, "❌ Помилка при оновленні. Спробуйте ще раз.")
              end
          end

        _ ->
          case FeedbackBot.Bot.State.get_state(from.id, :selected_employee) do
            nil ->
              answer(context, "👋 Натисніть /start щоб почати")

            _employee_id ->
              keyboard = [
                [
                  %{
                    text: "🎤 Як записати голосове?",
                    callback_data: "help:voice_recording"
                  }
                ],
                [%{text: "❌ Скасувати", callback_data: "action:back_to_start"}]
              ]

              markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

              answer(context, """
              ⚠️ *Потрібне голосове повідомлення, а не текст!*

              📱 *Як записати голосове в Telegram:*

              *На телефоні:*
              1. Знайдіть значок 🎤 мікрофона праворуч від поля вводу
              2. Натисніть і *тримайте* кнопку мікрофона
              3. Говоріть ваш фідбек
              4. Відпустіть кнопку — аудіо автоматично відправиться

              *На комп'ютері:*
              1. Натисніть на скріпку 📎
              2. Оберіть "Аудіо" або записати голосове
              3. Запишіть та надішліть

              ⏱ *Рекомендовано:* 30 секунд - 2 хвилини

              Або натисніть /cancel щоб скасувати.
              """, parse_mode: "Markdown", reply_markup: markup)
          end
      end
    end
  end

  def handle({:callback_query, %{data: "help:voice_recording"} = query}, context) do
    ExGram.answer_callback_query(query.id, text: "ℹ️ Інструкція")

    # Відправляємо GIF-інструкцію як окреме повідомлення
    answer(context, """
    🎤 *ДЕТАЛЬНА ІНСТРУКЦІЯ: Як записати голосове*

    📱 *ANDROID / iOS:*

    1️⃣ Відкрийте цей чат
    2️⃣ Знайдіть поле вводу повідомлень внизу
    3️⃣ Праворуч від поля побачите значок 🎤 мікрофона
    4️⃣ *НАТИСНІТЬ І ТРИМАЙТЕ* кнопку мікрофона
    5️⃣ Почніть говорити свій фідбек
    6️⃣ Коли закінчите — *ВІДПУСТІТЬ* палець
    7️⃣ Голосове автоматично відправиться!

    💻 *НА КОМП'ЮТЕРІ (Desktop/Web):*

    1️⃣ Натисніть на значок 📎 скріпки
    2️⃣ У меню оберіть "Записати голосове"
    3️⃣ Дозвольте доступ до мікрофона
    4️⃣ Натисніть кнопку запису
    5️⃣ Говоріть фідбек
    6️⃣ Натисніть "Зупинити" та "Відправити"

    ⚠️ *ВАЖЛИВО:*
    • Не відпускайте кнопку під час запису на телефоні
    • Переконайтеся що мікрофон увімкнений
    • Говоріть чітко та не дуже швидко

    ✅ *Після відправки* бот автоматично:
    • Розпізнає мову (Whisper AI)
    • Проаналізує тональність (GPT-4o mini)
    • Збереже у базу даних

    ⏱ *Оптимальна тривалість:* 30 сек - 2 хв
    """, parse_mode: "Markdown")
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



  defp show_employee_list_for_edit(_context, chat_id, message_id) do
    employees = Employees.list_all_employees()

    if Enum.empty?(employees) do
      keyboard = [
        [%{text: "🏠 Назад", callback_data: "action:manage_menu"}]
      ]

      markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

      ExGram.edit_message_reply_markup(
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
            %{text: "✏️ #{emp.name}", callback_data: "edit_emp:#{emp.id}"}
          end)
        end)

      keyboard_with_back = keyboard ++ [[%{text: "🏠 Назад", callback_data: "action:manage_menu"}]]

      markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard_with_back}

      ExGram.edit_message_reply_markup(
        chat_id: chat_id,
        message_id: message_id,
        reply_markup: markup
      )
    end
  end

  defp show_employee_list_for_delete(_context, chat_id, message_id) do
    employees = Employees.list_active_employees()

    if Enum.empty?(employees) do
      keyboard = [
        [%{text: "🏠 Назад", callback_data: "action:manage_menu"}]
      ]

      markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

      ExGram.edit_message_reply_markup(
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
            %{text: "🗑 #{emp.name}", callback_data: "delete_emp:#{emp.id}"}
          end)
        end)

      keyboard_with_back =
        keyboard ++ [[%{text: "🏠 Назад", callback_data: "action:manage_menu"}]]

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

      # НЕГАЙНЕ підтвердження отримання
      answer(context, """
      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      *ПРОГРЕС: 3 з 3 кроків* ⬤⬤⬤

      ✅ *АУДІО ОТРИМАНО!*

      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      📊 *ІНФОРМАЦІЯ:*
      👤 Співробітник: *#{employee.name}*
      ⏱ Тривалість: *#{voice.duration} секунд*
      🎤 Формат: Голосове повідомлення

      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      ⏳ *ЗАРАЗ ОБРОБЛЯЄТЬСЯ...*

      *Крок 1 з 3:* 🎯 Розпізнавання мови
      ↳ _Whisper AI перетворює голос у текст..._

      *Крок 2 з 3:* 🧠 Аналіз тональності
      ↳ _GPT-4o mini аналізує фідбек..._

      *Крок 3 з 3:* 💾 Збереження
      ↳ _Додаємо до аналітики..._

      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      ⏱ *Очікуваний час:* 20-40 секунд

      _Ви отримаєте повідомлення з результатами!_
      _НЕ закривайте чат, зачекайте..._
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
