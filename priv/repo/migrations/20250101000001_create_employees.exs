defmodule FeedbackBot.Repo.Migrations.CreateEmployees do
  use Ecto.Migration

  def change do
    create table(:employees, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :email, :string
      add :is_active, :boolean, default: true, null: false
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:employees, [:name])
    create index(:employees, [:is_active])
  end
end
