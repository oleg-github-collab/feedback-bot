defmodule FeedbackBotWeb.SatisfactionCalendarLive do
  use FeedbackBotWeb, :live_view

  alias FeedbackBot.Surveys

  @impl true
  def mount(_params, session, socket) do
    user_id = Map.get(session, "telegram_user_id")

    # Отримуємо дані за останні 3 місяці
    _three_months_ago = DateTime.add(DateTime.utc_now(), -90, :day)
    _now = DateTime.utc_now()

    surveys =
      if user_id do
        Surveys.list_surveys_for_user(user_id, limit: 52)
      else
        []
      end

    calendar_data = prepare_calendar_data(surveys)

    {:ok,
     socket
     |> assign(:page_title, "Team Satisfaction Calendar")
     |> assign(:active_nav, "/satisfaction-calendar")
     |> assign(:surveys, surveys)
     |> assign(:calendar_data, calendar_data)
     |> assign(:selected_survey, nil)}
  end

  @impl true
  def handle_event("select_week", %{"survey_id" => survey_id}, socket) do
    survey = Enum.find(socket.assigns.surveys, &(&1.id == survey_id))
    {:noreply, assign(socket, :selected_survey, survey)}
  end

  def handle_event("close_detail", _, socket) do
    {:noreply, assign(socket, :selected_survey, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-violet-50 via-purple-50 to-pink-50">
      <.top_nav active={@active_nav} />

      <header class="bg-white shadow-lg border-b-4 border-violet-600">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <h1 class="text-4xl font-black bg-gradient-to-r from-violet-600 to-purple-600 bg-clip-text text-transparent">
            📅 Team Satisfaction Calendar
          </h1>
          <p class="mt-2 text-lg text-gray-600">
            Track your team satisfaction trends over time
          </p>
        </div>
      </header>

      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <!-- Calendar Grid -->
          <div class="lg:col-span-2">
            <div class="bg-white rounded-3xl shadow-xl border-4 border-black p-6">
              <h2 class="text-2xl font-black mb-4">Recent Weeks</h2>

              <div class="space-y-2">
                <%= for survey <- @surveys do %>
                  <div
                    class={"cursor-pointer p-4 rounded-xl border-2 transition-all hover:scale-105 #{get_color_class(survey.average_score)}"}
                    phx-click="select_week"
                    phx-value-survey_id={survey.id}
                  >
                    <div class="flex justify-between items-center">
                      <div>
                        <div class="font-bold">Week of {format_date(survey.week_start)}</div>
                        <div class="text-sm text-gray-600">
                          Completed: {format_datetime(survey.completed_at)}
                        </div>
                      </div>
                      <div class="text-3xl font-black">
                        {Float.round(survey.average_score, 1)}/5
                      </div>
                    </div>

                    <!-- Mini bar chart -->
                    <div class="mt-2 flex gap-1">
                      <div class="flex-1 h-2 bg-gray-200 rounded" style={"width: #{survey.q1_team_performance * 20}%"}></div>
                      <div class="flex-1 h-2 bg-gray-200 rounded" style={"width: #{survey.q2_communication * 20}%"}></div>
                      <div class="flex-1 h-2 bg-gray-200 rounded" style={"width: #{survey.q3_kpi_achievement * 20}%"}></div>
                      <div class="flex-1 h-2 bg-gray-200 rounded" style={"width: #{survey.q4_problem_solving * 20}%"}></div>
                      <div class="flex-1 h-2 bg-gray-200 rounded" style={"width: #{survey.q5_motivation * 20}%"}></div>
                    </div>
                  </div>
                <% end %>

                <%= if Enum.empty?(@surveys) do %>
                  <div class="text-center py-12 text-gray-500">
                    <p class="text-xl">📭 No survey data yet</p>
                    <p class="mt-2">Complete your first Friday survey to see data here!</p>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Detail Panel -->
          <div class="lg:col-span-1">
            <%= if @selected_survey do %>
              <div class="bg-white rounded-3xl shadow-xl border-4 border-black p-6 sticky top-4">
                <div class="flex justify-between items-center mb-4">
                  <h3 class="text-xl font-black">Week Details</h3>
                  <button
                    phx-click="close_detail"
                    class="text-gray-500 hover:text-gray-700 text-2xl"
                  >
                    ×
                  </button>
                </div>

                <div class="mb-6">
                  <div class={"text-5xl font-black text-center p-4 rounded-xl #{get_color_class(@selected_survey.average_score)}"}>
                    {Float.round(@selected_survey.average_score, 2)}/5
                  </div>
                </div>

                <div class="space-y-3">
                  <.score_bar label="Team Performance" score={@selected_survey.q1_team_performance} />
                  <.score_bar label="Communication" score={@selected_survey.q2_communication} />
                  <.score_bar label="KPI Achievement" score={@selected_survey.q3_kpi_achievement} />
                  <.score_bar label="Problem Solving" score={@selected_survey.q4_problem_solving} />
                  <.score_bar label="Motivation" score={@selected_survey.q5_motivation} />
                  <.score_bar label="Task Speed" score={@selected_survey.q6_task_speed} />
                  <.score_bar label="Collaboration" score={@selected_survey.q7_collaboration} />
                  <.score_bar label="Work Quality" score={@selected_survey.q8_work_quality} />
                  <.score_bar label="Improvement" score={@selected_survey.q9_improvement} />
                  <.score_bar label="Overall" score={@selected_survey.q10_overall} />
                </div>
              </div>
            <% else %>
              <div class="bg-white rounded-3xl shadow-xl border-4 border-black p-6 sticky top-4">
                <div class="text-center text-gray-500 py-12">
                  <p class="text-xl">👈 Select a week</p>
                  <p class="mt-2">Click on any week to see detailed breakdown</p>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </main>
    </div>
    """
  end

  defp score_bar(assigns) do
    ~H"""
    <div>
      <div class="flex justify-between text-sm mb-1">
        <span class="font-semibold">{@label}</span>
        <span class="font-bold">{@score}/5</span>
      </div>
      <div class="h-3 bg-gray-200 rounded-full overflow-hidden">
        <div class={"h-full rounded-full #{score_color(@score)}"} style={"width: #{@score * 20}%"}></div>
      </div>
    </div>
    """
  end

  defp get_color_class(score) when score >= 4.0, do: "bg-green-100 border-green-400"
  defp get_color_class(score) when score >= 3.0, do: "bg-yellow-100 border-yellow-400"
  defp get_color_class(score) when score >= 2.0, do: "bg-orange-100 border-orange-400"
  defp get_color_class(_), do: "bg-red-100 border-red-400"

  defp score_color(score) when score >= 4, do: "bg-green-500"
  defp score_color(score) when score >= 3, do: "bg-yellow-500"
  defp score_color(score) when score >= 2, do: "bg-orange-500"
  defp score_color(_), do: "bg-red-500"

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d %b %Y")
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%d %b %Y, %H:%M")
  end

  defp prepare_calendar_data(surveys) do
    # Group by month for future use
    Enum.group_by(surveys, fn survey ->
      DateTime.to_date(survey.week_start) |> Date.beginning_of_month()
    end)
  end
end
