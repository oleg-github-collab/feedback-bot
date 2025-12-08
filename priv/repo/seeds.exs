# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#

alias FeedbackBot.{Repo, Employees}
alias FeedbackBot.Employees.Employee

# Створюємо співробітників зі списку (пропускаємо дублікати)
employees_data = [
  %{name: "Іванна Сакало", email: "ivanna.sakalo@opslab.uk"},
  %{name: "Михайло Іващук", email: "mykhailo.ivashchuk@opslab.uk"},
  %{name: "Вероніка Кухарчук", email: "veronika.kukharchuk@opslab.uk"},
  %{name: "Катерина Петухова", email: "kateryna.petukhova@opslab.uk"},
  %{name: "Марія Василик", email: "mariya.vasylyk@opslab.uk"},
  %{name: "Оксана Клінчаян", email: "oksana.klinchaian@opslab.uk"},
  %{name: "Ірина Мячкова", email: "iryna.miachkova@opslab.uk"}
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
