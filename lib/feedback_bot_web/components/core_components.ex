defmodule FeedbackBotWeb.CoreComponents do
  @moduledoc """
  Базові UI компоненти в необруталістичному стилі
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.
  """
  attr :kind, :atom, values: [:info, :error], required: true
  attr :flash, :map, required: true

  def flash(assigns) do
    ~H"""
    <%= if msg = Phoenix.Flash.get(@flash, @kind) do %>
      <div
        id={"flash-#{@kind}"}
        phx-click={JS.push("lv:clear-flash", value: %{key: @kind})}
        class={[
          "fixed top-4 right-4 z-50 neo-brutal-card max-w-md cursor-pointer",
          @kind == :info && "bg-green-300",
          @kind == :error && "bg-red-300"
        ]}
        role="alert"
      >
        <p class="font-bold flex items-center gap-2">
          <span class="text-2xl">
            <%= if @kind == :info, do: "✓", else: "✕" %>
          </span>
          <span class="flex-1"><%= msg %></span>
        </p>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders a simple form.
  """
  attr :for, :any, required: true
  attr :as, :any, default: nil
  attr :rest, :global, include: ~w(method)
  slot :inner_block, required: true

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <%= render_slot(@inner_block, f) %>
    </.form>
    """
  end

  @doc """
  Відображає header з назвою
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def header(assigns) do
    ~H"""
    <header class={["border-b-4 border-black bg-white", @class]}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <%= render_slot(@inner_block) %>
      </div>
    </header>
    """
  end
end
