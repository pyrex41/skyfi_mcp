defmodule SkyfiMcp.AccessKey do
  use Ecto.Schema
  import Ecto.Changeset

  schema "access_keys" do
    field :key, :string
    field :user_email, :string
    field :description, :string
    field :active, :boolean, default: true
    field :request_count, :integer, default: 0
    field :last_used_at, :utc_datetime

    has_many :request_logs, SkyfiMcp.RequestLog

    timestamps(type: :utc_datetime)
  end

  @doc """
  Generates a new access key with the format: sk_mcp_<random>
  """
  def generate_key do
    random_part =
      :crypto.strong_rand_bytes(16)
      |> Base.encode16(case: :lower)
      |> binary_part(0, 24)

    "sk_mcp_#{random_part}"
  end

  @doc false
  def changeset(access_key, attrs) do
    access_key
    |> cast(attrs, [:key, :user_email, :description, :active, :request_count, :last_used_at])
    |> validate_required([:key])
    |> unique_constraint(:key)
    |> validate_format(:key, ~r/^sk_mcp_[a-f0-9]{24}$/)
  end

  @doc """
  Creates a changeset for a new access key with auto-generated key
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:user_email, :description])
    |> put_change(:key, generate_key())
    |> validate_required([:key])
    |> unique_constraint(:key)
  end
end
