defmodule FeedbackBotWeb.Router do
  use FeedbackBotWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FeedbackBotWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FeedbackBotWeb do
    pipe_through :browser

    live "/", DashboardLive
    live "/employees", EmployeesLive
    live "/employees/:id", EmployeeDetailLive
    live "/feedbacks", FeedbacksLive
    live "/analytics", AdvancedAnalyticsLive
    live "/analytics/basic", AnalyticsLive
    live "/analytics/:period_type", AnalyticsPeriodLive
  end

  if Application.compile_env(:feedback_bot, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FeedbackBotWeb.Telemetry
    end
  end
end
