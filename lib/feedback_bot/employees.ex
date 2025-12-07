defmodule FeedbackBot.Employees do
  @moduledoc """
  Context для управління співробітниками
  """

  import Ecto.Query, warn: false
  alias FeedbackBot.Repo
  alias FeedbackBot.Employees.Employee

  @doc """
  Повертає список усіх активних співробітників
  """
  def list_active_employees do
    Employee
    |> where([e], e.is_active == true)
    |> order_by([e], e.name)
    |> Repo.all()
  end

  @doc """
  Повертає список усіх співробітників
  """
  def list_employees do
    Employee
    |> order_by([e], e.name)
    |> Repo.all()
  end

  @doc """
  Отримує співробітника за ID
  """
  def get_employee(id) do
    Repo.get(Employee, id)
  end

  @doc """
  Отримує співробітника за ID, викидає помилку якщо не знайдено
  """
  def get_employee!(id) do
    Repo.get!(Employee, id)
  end

  @doc """
  Створює нового співробітника
  """
  def create_employee(attrs \\ %{}) do
    %Employee{}
    |> Employee.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Оновлює співробітника
  """
  def update_employee(%Employee{} = employee, attrs) do
    employee
    |> Employee.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Видаляє співробітника (soft delete - встановлює is_active = false)
  """
  def deactivate_employee(%Employee{} = employee) do
    update_employee(employee, %{is_active: false})
  end

  @doc """
  Активує співробітника
  """
  def activate_employee(%Employee{} = employee) do
    update_employee(employee, %{is_active: true})
  end

  @doc """
  Повністю видаляє співробітника з бази
  """
  def delete_employee(%Employee{} = employee) do
    Repo.delete(employee)
  end

  @doc """
  Повертає статистику по співробітнику
  """
  def get_employee_stats(employee_id, opts \\ []) do
    period_start = Keyword.get(opts, :from)
    period_end = Keyword.get(opts, :to)

    query =
      from f in FeedbackBot.Feedbacks.Feedback,
        where: f.employee_id == ^employee_id and f.processing_status == "completed"

    query =
      if period_start do
        from f in query, where: f.inserted_at >= ^period_start
      else
        query
      end

    query =
      if period_end do
        from f in query, where: f.inserted_at <= ^period_end
      else
        query
      end

    feedbacks = Repo.all(query)

    total_count = length(feedbacks)

    if total_count > 0 do
      avg_sentiment =
        feedbacks
        |> Enum.map(& &1.sentiment_score)
        |> Enum.sum()
        |> Kernel./(total_count)

      sentiment_distribution =
        feedbacks
        |> Enum.group_by(& &1.sentiment_label)
        |> Enum.map(fn {label, list} -> {label, length(list)} end)
        |> Enum.into(%{})

      all_issues =
        feedbacks
        |> Enum.flat_map(& &1.issues)
        |> Enum.frequencies_by(&Map.get(&1, "description"))
        |> Enum.sort_by(fn {_k, v} -> v end, :desc)
        |> Enum.take(10)

      all_strengths =
        feedbacks
        |> Enum.flat_map(& &1.strengths)
        |> Enum.frequencies()
        |> Enum.sort_by(fn {_k, v} -> v end, :desc)
        |> Enum.take(10)

      %{
        total_feedbacks: total_count,
        avg_sentiment: Float.round(avg_sentiment, 3),
        sentiment_distribution: sentiment_distribution,
        top_issues: all_issues,
        top_strengths: all_strengths,
        latest_feedback: List.first(Enum.sort_by(feedbacks, & &1.inserted_at, {:desc, DateTime}))
      }
    else
      %{
        total_feedbacks: 0,
        avg_sentiment: 0.0,
        sentiment_distribution: %{},
        top_issues: [],
        top_strengths: [],
        latest_feedback: nil
      }
    end
  end
end
