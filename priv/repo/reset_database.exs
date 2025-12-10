# Скрипт для повного очищення бази даних зі збереженням співробітників
# Script for complete database reset while preserving employees
#
# Використання / Usage: mix run priv/repo/reset_database.exs
#
# ⚠️  УВАГА / WARNING: Цей скрипт видалить ВСІ дані окрім співробітників!
# This script will DELETE ALL data except employees!

alias FeedbackBot.Repo
alias FeedbackBot.Feedbacks.Feedback
alias FeedbackBot.Analytics.Snapshot
alias FeedbackBot.ManagerSurvey

require Logger

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("🔄 СКИДАННЯ БАЗИ ДАНИХ / DATABASE RESET")
IO.puts(String.duplicate("=", 60) <> "\n")

IO.puts("⚠️  Збереження співробітників / Preserving employees...")
employee_count = Repo.aggregate(FeedbackBot.Employees.Employee, :count)
IO.puts("✅ Знайдено співробітників: #{employee_count}\n")

# Видалення feedbacks / Delete feedbacks
IO.puts("🗑️  Видалення відгуків / Deleting feedbacks...")
{feedback_count, _} = Repo.delete_all(Feedback)
IO.puts("✅ Видалено #{feedback_count} відгуків\n")

# Видалення analytics snapshots / Delete analytics snapshots
IO.puts("🗑️  Видалення аналітики / Deleting analytics snapshots...")
{snapshot_count, _} = Repo.delete_all(Snapshot)
IO.puts("✅ Видалено #{snapshot_count} знімків аналітики\n")

# Видалення manager surveys / Delete manager surveys
IO.puts("🗑️  Видалення опитувань менеджерів / Deleting manager surveys...")
{survey_count, _} = Repo.delete_all(ManagerSurvey)
IO.puts("✅ Видалено #{survey_count} опитувань\n")

# Видалення Oban jobs (фонові завдання) / Delete Oban jobs (background jobs)
IO.puts("🗑️  Видалення фонових завдань / Deleting background jobs...")
try do
  {job_count, _} = Repo.delete_all(Oban.Job)
  IO.puts("✅ Видалено #{job_count} фонових завдань\n")
rescue
  e ->
    Logger.warning("⚠️  Не вдалось видалити Oban jobs: #{inspect(e)}")
    IO.puts("⚠️  Пропускаємо видалення фонових завдань\n")
end

# Підсумок / Summary
IO.puts(String.duplicate("=", 60))
IO.puts("✅ БАЗА ДАНИХ УСПІШНО СКИНУТА / DATABASE SUCCESSFULLY RESET")
IO.puts(String.duplicate("=", 60))
IO.puts("\n📊 Підсумок / Summary:")
IO.puts("  • Відгуків видалено / Feedbacks deleted: #{feedback_count}")
IO.puts("  • Аналітики видалено / Analytics deleted: #{snapshot_count}")
IO.puts("  • Опитувань видалено / Surveys deleted: #{survey_count}")
IO.puts("  • Співробітників збережено / Employees preserved: #{employee_count}")
IO.puts("\n✅ База готова до передачі клієнту!")
IO.puts("✅ Database ready for customer handover!\n")
