defmodule FeedbackBot.Bot.Handler do
  @moduledoc """
  Telegram Bot Handler з продуманим флоу для запису голосового фідбеку.

  Флоу бота:
  1. /start - Вітання та перевірка доступу користувача
  2. Список співробітників у вигляді inline кнопок
  3. Після вибору співробітника - запит аудіо
  4. Обробка аудіо через Kaminskyi VoX
  5. Аналіз через Kaminskyi Epic
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
  command("about")

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
    /about - Детально про продукт
    /cancel - Скасувати поточну дію
    /help - Показати цю довідку
    """)
  end

  def handle({:command, :about, %{from: from}}, context) do
    if authorized?(from.id) do
      send_about_product(context)
    else
      send_unauthorized_message(context)
    end
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

  # Обробка callback query для manager survey
  def handle({:callback_query, %{data: "survey:" <> rest} = query}, _context) do
    [survey_id, question_part, score] = String.split(rest, ":")
    question_num = String.replace(question_part, "q", "") |> String.to_integer()
    score_value = String.to_integer(score)

    ExGram.answer_callback_query(query.id, text: "✅ Оцінка #{score_value} збережена")

    # Оновлюємо survey
    survey = FeedbackBot.Surveys.get_survey(survey_id)

    if survey do
      field_name = String.to_atom("q#{question_num}_#{get_question_field_name(question_num)}")
      {:ok, updated_survey} = FeedbackBot.Surveys.update_survey(survey, %{field_name => score_value})

      # Якщо це останнє питання - завершуємо і показуємо порівняння
      if question_num == 10 do
        complete_survey(updated_survey, query.from.id)
      else
        # Відправляємо наступне питання
        send_next_question(query.from.id, survey_id, question_num + 1)
      end
    else
      ExGram.send_message(query.from.id, "❌ Помилка: опитування не знайдено")
    end
  end

  # Обробка callback query від inline кнопок
  def handle({:callback_query, %{data: "action:start_feedback"} = query}, _context) do
    ExGram.answer_callback_query(query.id, text: "✅ Починаємо запис фідбеку")

    employees = Employees.list_active_employees()

    if Enum.empty?(employees) do
      ExGram.edit_message_text(
        """
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        ❌ *НЕМАЄ СПІВРОБІТНИКІВ*

        Спочатку додайте співробітників через команду /manage

        Або попросіть адміністратора додати їх.
        """,
        chat_id: query.message.chat.id,
        message_id: query.message.message_id,
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
        """
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        *ПРОГРЕС: 1 з 3 кроків* ⬤○○

        🎤 *КРОК 1: ОБЕРІТЬ СПІВРОБІТНИКА*

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        👥 *Про кого ви хочете залишити фідбек?*

        Натисніть на ім'я співробітника зі списку:
        """,
        chat_id: query.message.chat.id,
        message_id: query.message.message_id,
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
      """
      👋 *Вітаю у FeedbackBot!*

      Цей бот допоможе вам швидко записати голосовий фідбек про роботу співробітників.

      ✨ *Що можна зробити?*

      🎤 *Записати фідбек* — оберіть співробітника та надішліть голосове повідомлення
      📊 *Переглянути аналітику* — відкрийте веб-інтерфейс з детальною статистикою

      Оберіть дію нижче:
      """,
      chat_id: query.message.chat.id,
      message_id: query.message.message_id,
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
      """
      ➕ *Додавання нового співробітника*

      *Крок 1 з 2:* Введіть ім'я співробітника

      📝 Приклад: Олена Шевченко

      Надішліть ім'я текстовим повідомленням або /cancel щоб скасувати.
      """,
      chat_id: query.message.chat.id,
      message_id: query.message.message_id,
      parse_mode: "Markdown"
    )
  end

  def handle({:callback_query, %{data: "manage:edit_employee"} = query}, context) do
    ExGram.answer_callback_query(query.id, text: "✏️ Оберіть співробітника")

    ExGram.edit_message_text(
      """
      ✏️ *Редагування співробітника*

      Оберіть співробітника для редагування:
      """,
      chat_id: query.message.chat.id,
      message_id: query.message.message_id,
      parse_mode: "Markdown"
    )

    show_employee_list_for_edit(context, query.message.chat.id, query.message.message_id)
  end

  def handle({:callback_query, %{data: "manage:delete_employee"} = query}, context) do
    ExGram.answer_callback_query(query.id, text: "🗑 Оберіть співробітника")

    ExGram.edit_message_text(
      """
      🗑 *Видалення співробітника*

      ⚠️ Співробітник буде деактивований (не видалений з бази).

      Оберіть співробітника:
      """,
      chat_id: query.message.chat.id,
      message_id: query.message.message_id,
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
      """
      👥 *Всі співробітники*

      #{list_text}

      ✅ — активний | ❌ — деактивований
      """,
      chat_id: query.message.chat.id,
      message_id: query.message.message_id,
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
      """
          ✏️ *Редагування: #{employee.name}*

          Поточні дані:
          📛 Ім'я: *#{employee.name}*
          📧 Email: *#{employee.email}*

          *Крок 1 з 2:* Введіть нове ім'я (або надішліть те саме щоб залишити)

          Надішліть нове ім'я або /cancel
          """,
      chat_id: query.message.chat.id,
      message_id: query.message.message_id,
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
      """
              ✅ *Співробітника деактивовано*

              👤 *#{employee.name}* більше не відображається у списку активних співробітників.

              📊 Всі фідбеки залишились в базі даних для історії.
              """,
      chat_id: query.message.chat.id,
      message_id: query.message.message_id,
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
      """
      ⚙️ *Управління Співробітниками*

      Оберіть дію для управління базою співробітників:

      ➕ *Додати* — створити нового співробітника
      ✏️ *Редагувати* — змінити дані існуючого
      🗑 *Видалити* — деактивувати співробітника
      👥 *Список* — переглянути всіх співробітників

      Оберіть опцію:
      """,
      chat_id: query.message.chat.id,
      message_id: query.message.message_id,
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
          1️⃣ Клацніть на значок 🎤 (мікрофон) внизу
          2️⃣ Почніть записувати голосове
          3️⃣ Натисніть "Відправити" коли закінчите

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
      chat_id: query.message.chat.id,
      message_id: query.message.message_id,
      parse_mode: "Markdown",
          reply_markup: markup
    )
    end
  end

  # Обробка голосових повідомлень
  def handle({:message, %{voice: voice, from: from} = msg}, context) when not is_nil(voice) do
    Logger.info("Voice handler triggered for user #{from.id}, voice: #{inspect(voice)}")
    if authorized?(from.id) do
      Logger.info("User #{from.id} authorized, processing voice")
      handle_voice_message(voice, from, msg, context)
    else
      Logger.warning("User #{from.id} not authorized")
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

    1️⃣ Клацніть на значок 🎤 мікрофона внизу (поряд з полем вводу)
    2️⃣ Дозвольте доступ до мікрофона (якщо потрібно)
    3️⃣ Почніть говорити фідбек
    4️⃣ Натисніть "Зупинити" та "Відправити"

    ⚠️ *ВАЖЛИВО:*
    • Не відпускайте кнопку під час запису на телефоні
    • Переконайтеся що мікрофон увімкнений
    • Говоріть чітко та не дуже швидко

    ✅ *Після відправки* бот автоматично:
    • Розпізнає мову (Kaminskyi VoX)
    • Проаналізує тональність (Kaminskyi Epic)
    • Збереже у базу даних

    ⏱ *Оптимальна тривалість:* 30 сек - 2 хв
    """, parse_mode: "Markdown")
  end

  def handle(update, _context) do
    Logger.warning("Unhandled update: #{inspect(update, limit: :infinity)}")
    :ok
  end

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
    Logger.info("Voice message received from user #{from.id}, employee_id: #{inspect(employee_id)}")

    if employee_id do
      # Отримуємо ім'я співробітника
      employee = Employees.get_employee(employee_id)

      if employee do
        # НЕГАЙНЕ підтвердження отримання
        ExGram.send_message(
          msg.chat.id,
          """
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
          ↳ _Kaminskyi VoX перетворює голос у текст..._

          *Крок 2 з 3:* 🧠 Аналіз тональності
          ↳ _Kaminskyi Epic аналізує фідбек..._

          *Крок 3 з 3:* 💾 Збереження
          ↳ _Додаємо до аналітики..._

          ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          ⏱ *Очікуваний час:* 20-40 секунд

          _Ви отримаєте повідомлення з результатами!_
          _НЕ закривайте чат, зачекайте..._
          """,
          parse_mode: "Markdown"
        )

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
        # Employee не знайдено в базі
        ExGram.send_message(
          msg.chat.id,
          """
          ❌ *Помилка: Співробітника не знайдено*

          Можливо, співробітника було видалено.

          Натисніть /start щоб обрати іншого.
          """,
          parse_mode: "Markdown"
        )
      end
    else
      keyboard = [
        [%{text: "🏠 Повернутись на початок", callback_data: "action:back_to_start"}]
      ]

      markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

      ExGram.send_message(
        msg.chat.id,
        """
        ❌ *Помилка: Співробітника не обрано*

        Спочатку потрібно обрати співробітника.

        Натисніть /start щоб почати спочатку.
        """,
        parse_mode: "Markdown",
        reply_markup: markup
      )
    end
  end

  defp get_question_field_name(1), do: "team_performance"
  defp get_question_field_name(2), do: "communication"
  defp get_question_field_name(3), do: "kpi_achievement"
  defp get_question_field_name(4), do: "problem_solving"
  defp get_question_field_name(5), do: "motivation"
  defp get_question_field_name(6), do: "task_speed"
  defp get_question_field_name(7), do: "collaboration"
  defp get_question_field_name(8), do: "work_quality"
  defp get_question_field_name(9), do: "improvement"
  defp get_question_field_name(10), do: "overall"

  defp send_next_question(user_id, survey_id, question_num) do
    question_text = get_survey_question_text(question_num)

    keyboard = [
      [
        %{text: "1️⃣", callback_data: "survey:#{survey_id}:q#{question_num}:1"},
        %{text: "2️⃣", callback_data: "survey:#{survey_id}:q#{question_num}:2"},
        %{text: "3️⃣", callback_data: "survey:#{survey_id}:q#{question_num}:3"},
        %{text: "4️⃣", callback_data: "survey:#{survey_id}:q#{question_num}:4"},
        %{text: "5️⃣", callback_data: "survey:#{survey_id}:q#{question_num}:5"}
      ]
    ]

    markup = %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: keyboard}

    message = """
    *Питання #{question_num}/10:*

    #{question_text}

    _Оберіть оцінку від 1 (дуже погано) до 5 (відмінно)_
    """

    ExGram.send_message(user_id, message, parse_mode: "Markdown", reply_markup: markup)
  end

  defp get_survey_question_text(1), do: "📊 Наскільки ви задоволені загальним *перформансом команди*?"
  defp get_survey_question_text(2), do: "💬 Як оцінюєте якість *комунікації* в команді?"
  defp get_survey_question_text(3), do: "🎯 Чи досягнуто *KPI* цього тижня?"
  defp get_survey_question_text(4), do: "🔧 Наскільки ефективно *вирішувались проблеми*?"
  defp get_survey_question_text(5), do: "⚡️ Як оцінюєте рівень *мотивації* команди?"
  defp get_survey_question_text(6), do: "⏱ Чи задоволені *швидкістю виконання* задач?"
  defp get_survey_question_text(7), do: "🤝 Як оцінюєте рівень *співпраці* між членами команди?"
  defp get_survey_question_text(8), do: "✨ Наскільки *якісно виконується* робота?"
  defp get_survey_question_text(9), do: "📈 Чи є *покращення* порівняно з минулим тижнем?"
  defp get_survey_question_text(10), do: "⭐️ *Загальна оцінка* тижня"

  defp complete_survey(survey, user_id) do
    # Обчислюємо середній бал
    avg_score = FeedbackBot.ManagerSurvey.calculate_average(survey)

    # Оновлюємо survey з completed_at та average_score
    {:ok, completed_survey} =
      FeedbackBot.Surveys.update_survey(survey, %{
        average_score: avg_score,
        completed_at: DateTime.utc_now()
      })

    # Отримуємо попередній тиждень для порівняння
    previous_survey = FeedbackBot.Surveys.get_previous_week_survey(user_id, survey.week_start)

    # Відправляємо результат
    send_survey_results(user_id, completed_survey, previous_survey)
  end

  defp send_survey_results(user_id, current_survey, previous_survey) do
    comparison = build_comparison_message(current_survey, previous_survey)

    message = """
    ✅ *ОПИТУВАННЯ ЗАВЕРШЕНО!*

    Дякуємо за відповіді! 🙏

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    #{comparison}

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    📅 Наступне опитування: *П'ятниця о 17:00*

    _Ваші відповіді допомагають покращувати роботу команди!_ ✨
    """

    ExGram.send_message(user_id, message, parse_mode: "Markdown")
  end

  defp build_comparison_message(current, nil) do
    """
    📊 *ВАШІ ОЦІНКИ ЦЬОГО ТИЖНЯ*

    Team Performance: #{current.q1_team_performance}/5
    Communication: #{current.q2_communication}/5
    KPI Achievement: #{current.q3_kpi_achievement}/5
    Problem Solving: #{current.q4_problem_solving}/5
    Motivation: #{current.q5_motivation}/5
    Task Speed: #{current.q6_task_speed}/5
    Collaboration: #{current.q7_collaboration}/5
    Work Quality: #{current.q8_work_quality}/5
    Improvement: #{current.q9_improvement}/5
    Overall: #{current.q10_overall}/5

    *СЕРЕДНІЙ БАЛ:* #{Float.round(current.average_score, 2)}/5

    _Це ваш перший опитувальник! Порівняння з'явиться наступного тижня._
    """
  end

  defp build_comparison_message(current, previous) do
    delta = Float.round(current.average_score - previous.average_score, 2)
    trend_emoji = if delta > 0, do: "📈 ✅", else: if(delta < 0, do: "📉 ⚠️", else: "➡️")

    questions = [
      {"Team Performance", current.q1_team_performance, previous.q1_team_performance},
      {"Communication", current.q2_communication, previous.q2_communication},
      {"KPI Achievement", current.q3_kpi_achievement, previous.q3_kpi_achievement},
      {"Problem Solving", current.q4_problem_solving, previous.q4_problem_solving},
      {"Motivation", current.q5_motivation, previous.q5_motivation},
      {"Task Speed", current.q6_task_speed, previous.q6_task_speed},
      {"Collaboration", current.q7_collaboration, previous.q7_collaboration},
      {"Work Quality", current.q8_work_quality, previous.q8_work_quality},
      {"Improvement", current.q9_improvement, previous.q9_improvement},
      {"Overall", current.q10_overall, previous.q10_overall}
    ]

    comparisons =
      Enum.map(questions, fn {name, curr, prev} ->
        change = curr - prev
        emoji = if change > 0, do: "✅", else: if(change < 0, do: "⚠️", else: "➡️")
        sign = if change > 0, do: "+#{change}", else: "#{change}"
        "#{name}: #{prev} → #{curr} #{emoji} (#{sign})"
      end)
      |> Enum.join("\n")

    """
    📊 *ПОРІВНЯННЯ ТИЖНІВ*

    #{comparisons}

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    *СЕРЕДНІЙ БАЛ:*
    #{Float.round(previous.average_score, 2)} → #{Float.round(current.average_score, 2)} #{trend_emoji}
    #{if delta != 0, do: "(#{if delta > 0, do: "+", else: ""}#{delta})", else: "(без змін)"}

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    #{generate_insights(current, previous)}
    """
  end

  defp generate_insights(current, previous) do
    improvements =
      [
        {"Team Performance", current.q1_team_performance - previous.q1_team_performance},
        {"Communication", current.q2_communication - previous.q2_communication},
        {"KPI", current.q3_kpi_achievement - previous.q3_kpi_achievement},
        {"Problem Solving", current.q4_problem_solving - previous.q4_problem_solving},
        {"Motivation", current.q5_motivation - previous.q5_motivation}
      ]
      |> Enum.filter(fn {_, delta} -> delta > 0 end)
      |> Enum.sort_by(fn {_, delta} -> delta end, :desc)
      |> Enum.take(2)

    declines =
      [
        {"Team Performance", current.q1_team_performance - previous.q1_team_performance},
        {"Communication", current.q2_communication - previous.q2_communication},
        {"KPI", current.q3_kpi_achievement - previous.q3_kpi_achievement},
        {"Problem Solving", current.q4_problem_solving - previous.q4_problem_solving},
        {"Motivation", current.q5_motivation - previous.q5_motivation}
      ]
      |> Enum.filter(fn {_, delta} -> delta < 0 end)
      |> Enum.sort_by(fn {_, delta} -> delta end)
      |> Enum.take(2)

    improvements_text =
      if length(improvements) > 0 do
        list = Enum.map_join(improvements, "\n", fn {name, _} -> "• #{name}" end)
        "✨ *Покращення в:*\n#{list}\n\n"
      else
        ""
      end

    declines_text =
      if length(declines) > 0 do
        list = Enum.map_join(declines, "\n", fn {name, _} -> "• #{name}" end)
        "⚠️ *Потребує уваги:*\n#{list}"
      else
        ""
      end

    improvements_text <> declines_text
  end

  defp send_about_product(context) do
    part1 = """
    🤖 *ПРО FEEDBACKBOT*

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    FeedbackBot — інноваційна AI-powered система для збору та аналізу фідбеку про роботу співробітників.

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ✨ *ОСНОВНІ МОЖЛИВОСТІ*

    🎤 *ГОЛОСОВИЙ ФІДБЕК*
    • Записуйте відгуки голосом (30-120 сек)
    • Розпізнавання через Kaminskyi VoX
    • Автоматична транскрипція українською

    🧠 *AI АНАЛІТИКА*
    • Аналіз тональності через Kaminskyi Epic
    • Виявлення проблем та сильних сторін
    • Автоматична категоризація тем
    • Sentiment scoring та mood detection

    📊 *REAL-TIME ДАШБОРД*
    • Live оновлення метрик
    • Графіки трендів тональності
    • Breakdown по співробітниках
    • Топ-теми та проблеми
    """

    part2 = """
    📬 *АВТОМАТИЧНІ РОЗСИЛКИ*

    ⏰ *Щодня о 15:00*
    Нагадування про запис фідбеку

    ⏰ *Щодня о 9:00*
    Follow-up негативних відгуків (через тиждень)

    ⏰ *П'ятниця о 16:00*
    Детальна тижнева статистика

    ⏰ *Понеділок о 10:00* (кожні 2 тижні)
    AI Performance Reviews для співробітників

    ⏰ *1-ше число місяця о 9:00*
    Executive Summary для топ-менеджменту

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🎯 *УНІКАЛЬНІ ФІЧІ*

    ✓ Об'єктивні AI performance reviews
    ✓ Виключення суб'єктивності та bias
    ✓ Predictive analytics
    ✓ Voice emotion analysis
    ✓ Executive summaries з графіками
    """

    part3 = """
    💡 *ЯК КОРИСТУВАТИСЬ*

    1️⃣ Натисніть /start
    2️⃣ Оберіть співробітника зі списку
    3️⃣ Запишіть голосовий відгук
    4️⃣ Дочекайтесь результатів аналізу
    5️⃣ Перегляньте аналітику в веб-апці

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    📱 *КОМАНДИ БОТА*

    /start - Почати роботу з ботом
    /help - Довідка по командах
    /list - Список співробітників
    /analytics - Відкрити веб-аналітику
    /about - Про продукт (ця сторінка)
    /cancel - Скасувати поточну дію

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🌐 *ВЕБ-ДОДАТОК*

    https://feedback-bot-production-5dda.up.railway.app

    • Dashboard з real-time метриками
    • Advanced Analytics з фільтрами
    • Executive Summaries архів
    • Export звітів

    _Згенеровано Kaminskyi VoX & Kaminskyi Epic_ ✨
    """

    answer(context, part1, parse_mode: "Markdown")
    Process.sleep(500)
    answer(context, part2, parse_mode: "Markdown")
    Process.sleep(500)
    answer(context, part3, parse_mode: "Markdown")
  end

end
