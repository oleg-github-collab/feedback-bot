defmodule FeedbackBot.Surveys do
  @moduledoc """
  Context для роботи з manager surveys
  """

  import Ecto.Query
  alias FeedbackBot.Repo
  alias FeedbackBot.ManagerSurvey

  def create_survey(attrs \\ %{}) do
    %ManagerSurvey{}
    |> ManagerSurvey.changeset(attrs)
    |> Repo.insert()
  end

  def update_survey(%ManagerSurvey{} = survey, attrs) do
    survey
    |> ManagerSurvey.changeset(attrs)
    |> Repo.update()
  end

  def get_survey(id), do: Repo.get(ManagerSurvey, id)

  def get_survey_for_week(user_id, week_start) do
    from(s in ManagerSurvey,
      where: s.user_id == ^user_id and s.week_start == ^week_start
    )
    |> Repo.one()
  end

  def get_previous_week_survey(user_id, current_week_start) do
    previous_week = DateTime.add(current_week_start, -7, :day)

    from(s in ManagerSurvey,
      where: s.user_id == ^user_id and s.week_start == ^previous_week,
      where: not is_nil(s.completed_at)
    )
    |> Repo.one()
  end

  def list_surveys_for_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 52)

    from(s in ManagerSurvey,
      where: s.user_id == ^user_id,
      where: not is_nil(s.completed_at),
      order_by: [desc: s.week_start],
      limit: ^limit
    )
    |> Repo.all()
  end

  def get_calendar_data(user_id, from_date, to_date) do
    from(s in ManagerSurvey,
      where: s.user_id == ^user_id,
      where: s.week_start >= ^from_date and s.week_start <= ^to_date,
      where: not is_nil(s.completed_at),
      order_by: [asc: s.week_start]
    )
    |> Repo.all()
  end

  def get_all_users_calendar_data(from_date, to_date) do
    from(s in ManagerSurvey,
      where: s.week_start >= ^from_date and s.week_start <= ^to_date,
      where: not is_nil(s.completed_at),
      order_by: [asc: s.week_start]
    )
    |> Repo.all()
  end
end
