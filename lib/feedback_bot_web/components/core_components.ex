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
  Mobile-first responsive navigation з burger menu.
  """
  attr :active, :string, default: "/"

  def top_nav(assigns) do
    ~H"""
    <div
      class="fixed lg:sticky inset-x-0 top-0 z-[2147480000] border-b border-slate-800 bg-slate-950/95 backdrop-blur-md"
      phx-hook="MobileNav"
      id="mobile-nav-container"
    >
      <div class="max-w-7xl mx-auto flex items-center justify-between px-3 sm:px-6 lg:px-8 py-3">
        <!-- Logo + Desktop Nav -->
        <div class="flex items-center gap-3 sm:gap-4">
          <div class="px-2 sm:px-3 py-1 rounded-md bg-slate-900 border border-slate-700 text-xs font-semibold tracking-widest uppercase text-slate-200">
            FB<span class="hidden sm:inline">Bot</span>
          </div>
          <!-- Desktop Navigation (hidden on mobile) -->
          <nav class="hidden lg:flex items-center gap-2 text-sm font-semibold">
            <.nav_link to={~p"/"} label="Dashboard" active={@active} />
            <.nav_link to={~p"/feedbacks"} label="Фідбеки" active={@active} />
            <.nav_link to={~p"/employees"} label="Команда" active={@active} />
            <.nav_link to={~p"/analytics"} label="Аналітика 2.0" active={@active} />
            <.nav_link to={~p"/analytics/basic"} label="Зрізи" active={@active} />
          </nav>
        </div>
        <!-- Status + Burger -->
        <div class="flex items-center gap-3">
          <div class="hidden sm:flex items-center gap-2 px-2 sm:px-3 py-1 rounded-full bg-emerald-500/10 border border-emerald-400/40 text-emerald-200 text-xs font-semibold">
            <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
            <span>Онлайн</span>
          </div>
          <!-- Burger Button (only on mobile) -->
          <button
            type="button"
            data-burger
            class="lg:hidden flex flex-col justify-center items-center w-10 h-10 rounded-lg bg-slate-900 border border-slate-700 hover:bg-slate-800 transition-colors touch-manipulation relative z-[101]"
            aria-label="Toggle menu"
          >
            <span class="w-5 h-0.5 bg-slate-200 rounded-full transition-all duration-300 mb-1"></span>
            <span class="w-5 h-0.5 bg-slate-200 rounded-full transition-all duration-300 mb-1"></span>
            <span class="w-5 h-0.5 bg-slate-200 rounded-full transition-all duration-300"></span>
          </button>
        </div>
      </div>
      <!-- Mobile Menu Backdrop -->
      <div
        data-backdrop
        class="fixed inset-0 bg-black/60 backdrop-blur-sm opacity-0 pointer-events-none transition-opacity duration-300 lg:hidden"
      >
      </div>
      <!-- Mobile Menu Drawer -->
      <nav
        data-mobile-menu
        class="fixed top-0 right-0 h-[100dvh] max-h-[100dvh] w-[min(360px,90vw)] bg-slate-950 border-l border-slate-800 shadow-2xl transform translate-x-full transition-transform duration-300 ease-out lg:hidden overflow-y-auto"
      >
        <div class="p-6">
          <!-- Header -->
          <div class="flex items-center justify-between mb-8">
            <div class="text-lg font-black text-white">Menu</div>
            <button
              type="button"
              data-burger
              class="text-slate-400 hover:text-white w-10 h-10 flex items-center justify-center touch-manipulation"
            >
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>
          <!-- Nav Links -->
          <div class="space-y-2">
            <.mobile_nav_link to={~p"/"} label="📊 Dashboard" active={@active} />
            <.mobile_nav_link to={~p"/feedbacks"} label="💬 Фідбеки" active={@active} />
            <.mobile_nav_link to={~p"/employees"} label="👥 Команда" active={@active} />
            <.mobile_nav_link to={~p"/analytics"} label="📈 Аналітика 2.0" active={@active} />
            <.mobile_nav_link to={~p"/analytics/basic"} label="📉 Зрізи" active={@active} />
          </div>
          <!-- Status Indicator -->
          <div class="mt-8 pt-8 border-t border-slate-800">
            <div class="flex items-center gap-3 px-4 py-3 rounded-lg bg-emerald-500/10 border border-emerald-400/40">
              <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
              <div>
                <div class="text-xs font-semibold text-emerald-200">Система активна</div>
                <div class="text-[10px] text-slate-400">Live AI Insights</div>
              </div>
            </div>
          </div>
        </div>
      </nav>
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

  defp mobile_nav_link(assigns) do
    ~H"""
    <.link
      navigate={@to}
      data-mobile-link
      class={[
        "block px-4 py-3 rounded-lg transition-all border-2 text-base font-semibold touch-manipulation min-h-[48px] flex items-center",
        mobile_nav_class(@active, @to)
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

      String.starts_with?(active, target) && target != "/" ->
        "text-slate-200 hover:text-white hover:bg-slate-900"

      true ->
        "text-slate-400 hover:text-white hover:bg-slate-900"
    end
  end

  defp mobile_nav_class(active, target) do
    cond do
      active == target ->
        "bg-violet-600 text-white border-violet-500 shadow-lg"

      String.starts_with?(active, target) && target != "/" ->
        "bg-slate-800 text-slate-200 border-slate-700"

      true ->
        "bg-slate-900 text-slate-400 border-slate-800 hover:bg-slate-800 hover:text-white hover:border-slate-700"
    end
  end
end
