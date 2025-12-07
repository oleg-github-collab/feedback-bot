# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#

alias FeedbackBot.{Repo, Employees}
alias FeedbackBot.Employees.Employee

# Очищуємо існуючих співробітників (тільки для dev)
if Mix.env() == :dev do
  Repo.delete_all(Employee)
end

# Створюємо співробітників зі списку (замініть на ваших)
employees_data = [
  %{name: "Користувач 1", email: "user1@example.com"},
  %{name: "Користувач 2", email: "user2@example.com"}
]

Enum.each(employees_data, fn employee_data ->
  case Employees.create_employee(employee_data) do
    {:ok, employee} ->
      IO.puts("✓ Створено співробітника: #{employee.name}")

    {:error, changeset} ->
      IO.puts("✗ Помилка створення співробітника: #{inspect(changeset.errors)}")
  end
end)

IO.puts("\n✓ Seeds завершено!")
