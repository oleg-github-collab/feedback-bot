defmodule FeedbackBotWeb.EmployeesLive do
  use FeedbackBotWeb, :live_view

  alias FeedbackBot.Employees
  alias FeedbackBot.Employees.Employee

  @impl true
  def mount(_params, _session, socket) do
    employees = Employees.list_employees()

    socket =
      socket
      |> assign(:page_title, "Управління Співробітниками")
      |> assign(:employees, employees)
      |> assign(:show_form, false)
      |> assign(:form_data, %{})
      |> assign(:editing_id, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("new_employee", _params, socket) do
    {:noreply, assign(socket, show_form: true, form_data: %{}, editing_id: nil)}
  end

  @impl true
  def handle_event("edit_employee", %{"id" => id}, socket) do
    employee = Employees.get_employee!(id)

    form_data = %{
      "name" => employee.name,
      "email" => employee.email || ""
    }

    {:noreply, assign(socket, show_form: true, form_data: form_data, editing_id: id)}
  end

  @impl true
  def handle_event("cancel_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, form_data: %{}, editing_id: nil)}
  end

  @impl true
  def handle_event("save_employee", %{"employee" => params}, socket) do
    case socket.assigns.editing_id do
      nil ->
        case Employees.create_employee(params) do
          {:ok, _employee} ->
            employees = Employees.list_employees()

            {:noreply,
             socket
             |> assign(:employees, employees)
             |> assign(:show_form, false)
             |> assign(:form_data, %{})
             |> put_flash(:info, "Співробітника успішно додано")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Помилка при додаванні співробітника")}
        end

      id ->
        employee = Employees.get_employee!(id)

        case Employees.update_employee(employee, params) do
          {:ok, _employee} ->
            employees = Employees.list_employees()

            {:noreply,
             socket
             |> assign(:employees, employees)
             |> assign(:show_form, false)
             |> assign(:form_data, %{})
             |> assign(:editing_id, nil)
             |> put_flash(:info, "Співробітника успішно оновлено")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Помилка при оновленні співробітника")}
        end
    end
  end

  @impl true
  def handle_event("toggle_active", %{"id" => id}, socket) do
    employee = Employees.get_employee!(id)

    result =
      if employee.is_active do
        Employees.deactivate_employee(employee)
      else
        Employees.activate_employee(employee)
      end

    case result do
      {:ok, _employee} ->
        employees = Employees.list_employees()
        {:noreply, assign(socket, :employees, employees)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Помилка при зміні статусу")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-50">
      <header class="border-b-4 border-black bg-white">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div class="flex justify-between items-center">
            <div>
              <.link navigate="/" class="text-sm font-bold hover:underline mb-2 inline-block">
                ← Назад
              </.link>
              <h1 class="text-5xl font-black uppercase tracking-tight">
                Співробітники
              </h1>
            </div>
            <button
              phx-click="new_employee"
              class="neo-brutal-btn bg-green-300 hover:bg-green-400"
            >
              + Додати Співробітника
            </button>
          </div>
        </div>
      </header>

      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%= if @show_form do %>
          <div class="neo-brutal-card bg-yellow-100 mb-8">
            <h2 class="text-2xl font-black uppercase mb-4">
              <%= if @editing_id, do: "Редагувати Співробітника", else: "Новий Співробітник" %>
            </h2>

            <form phx-submit="save_employee">
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-bold mb-2">Імʼя *</label>
                  <input
                    type="text"
                    name="employee[name]"
                    value={Map.get(@form_data, "name", "")}
                    required
                    class="neo-brutal-input w-full"
                  />
                </div>

                <div>
                  <label class="block text-sm font-bold mb-2">Email</label>
                  <input
                    type="email"
                    name="employee[email]"
                    value={Map.get(@form_data, "email", "")}
                    class="neo-brutal-input w-full"
                  />
                </div>

                <div class="flex gap-3">
                  <button type="submit" class="neo-brutal-btn bg-green-300 hover:bg-green-400">
                    Зберегти
                  </button>
                  <button
                    type="button"
                    phx-click="cancel_form"
                    class="neo-brutal-btn bg-gray-300 hover:bg-gray-400"
                  >
                    Скасувати
                  </button>
                </div>
              </div>
            </form>
          </div>
        <% end %>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <%= for employee <- @employees do %>
            <div class={[
              "neo-brutal-card",
              if(!employee.is_active, do: "opacity-50")
            ]}>
              <div class="flex justify-between items-start mb-3">
                <div class="flex-1">
                  <h3 class="text-xl font-black"><%= employee.name %></h3>
                  <%= if employee.email do %>
                    <p class="text-sm text-gray-600"><%= employee.email %></p>
                  <% end %>
                </div>
                <span class={[
                  "px-2 py-1 text-xs font-black uppercase border-2 border-black",
                  if(employee.is_active, do: "bg-green-300", else: "bg-gray-300")
                ]}>
                  <%= if employee.is_active, do: "Активний", else: "Неактивний" %>
                </span>
              </div>

              <div class="flex gap-2 mt-4">
                <.link
                  navigate={"/employees/#{employee.id}"}
                  class="neo-brutal-btn-sm bg-blue-200 hover:bg-blue-300 flex-1 text-center"
                >
                  Детальніше
                </.link>
                <button
                  phx-click="edit_employee"
                  phx-value-id={employee.id}
                  class="neo-brutal-btn-sm bg-yellow-200 hover:bg-yellow-300"
                >
                  ✎
                </button>
                <button
                  phx-click="toggle_active"
                  phx-value-id={employee.id}
                  class="neo-brutal-btn-sm bg-gray-200 hover:bg-gray-300"
                >
                  <%= if employee.is_active, do: "⏸", else: "▶" %>
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </main>
    </div>
    """
  end
end
