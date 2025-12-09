# Скрипт для очищення feedbacks перед запуском сервісу
# Використання: railway run mix run priv/repo/clear_feedbacks.exs

alias FeedbackBot.Repo
alias FeedbackBot.Feedbacks.Feedback

# Очищуємо всі feedbacks
{count, _} = Repo.delete_all(Feedback)

IO.puts("✅ Видалено #{count} feedbacks")
IO.puts("✅ Співробітники залишені без змін")
IO.puts("✅ База готова до продакшену!")
