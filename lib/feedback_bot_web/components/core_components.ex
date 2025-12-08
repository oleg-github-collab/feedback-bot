defmodule FeedbackBotWeb.CoreComponents do
  @moduledoc """
  Базові UI компоненти в необруталістичному стилі
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  # Use verified routes for ~p sigil
  use Phoenix.VerifiedRoutes,
    endpoint: FeedbackBotWeb.Endpoint,
    router: FeedbackBotWeb.Router,
    statics: FeedbackBotWeb.static_paths()

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

  @doc """
  Глобальна навігація по основних екранах.
  """
  attr :active, :string, default: "/"

  def top_nav(assigns) do
    ~H"""
    <div class="sticky top-0 z-50 border-b border-slate-800 bg-slate-950/90 backdrop-blur">
      <div class="max-w-7xl mx-auto flex items-center justify-between px-4 sm:px-6 lg:px-8 py-3">
        <div class="flex items-center gap-4">
          <div class="px-3 py-1 rounded-md bg-slate-900 border border-slate-700 text-xs font-semibold tracking-widest uppercase text-slate-200">
            FeedbackBot
          </div>
          <nav class="flex items-center gap-2 text-sm font-semibold">
            <.nav_link to={~p"/"} label="Dashboard" active={@active} />
            <.nav_link to={~p"/feedbacks"} label="Фідбеки" active={@active} />
            <.nav_link to={~p"/employees"} label="Команда" active={@active} />
            <.nav_link to={~p"/analytics"} label="Аналітика 2.0" active={@active} />
            <.nav_link to={~p"/analytics/basic"} label="Зрізи" active={@active} />
          </nav>
        </div>
        <div class="flex items-center gap-2">
          <span class="hidden sm:inline text-xs text-slate-400">Live AI Insights</span>
          <div class="flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-500/10 border border-emerald-400/40 text-emerald-200 text-xs font-semibold">
            <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
            Онлайн
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :to, :string, required: true
  attr :label, :string, required: true
  attr :active, :string, required: true

  defp nav_link(assigns) do
    ~H"""
    <.link
      navigate={@to}
      class={[
        "px-3 py-2 rounded-lg transition-all border border-transparent",
        nav_class(@active, @to)
      ]}
    >
      <%= @label %>
    </.link>
    """
  end

  defp nav_class(active, target) do
    cond do
      active == target ->
        "bg-slate-800 text-white border-slate-700 shadow-md"

      String.starts_with?(active, target) ->
        "text-slate-200 hover:text-white hover:bg-slate-900"

      true ->
        "text-slate-400 hover:text-white hover:bg-slate-900"
    end
  end
end
