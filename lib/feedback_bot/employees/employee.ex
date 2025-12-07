defmodule FeedbackBot.Employees.Employee do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "employees" do
    field :name, :string
    field :email, :string
    field :is_active, :boolean, default: true
    field :metadata, :map, default: %{}

    has_many :feedbacks, FeedbackBot.Feedbacks.Feedback

    timestamps(type: :utc_datetime)
  end

  def changeset(employee, attrs) do
    employee
    |> cast(attrs, [:name, :email, :is_active, :metadata])
    |> validate_required([:name])
    |> unique_constraint(:name)
    |> validate_format(:email, ~r/@/, message: "must be a valid email")
  end
end
