defmodule SkyfiMcp.AccessKey do
  @moduledoc """
  Schema for access keys used for multi-user authentication.

  Each access key represents a user's authorization to use the SkyFi MCP server.
  Keys are in the format "sk_mcp_*" and are used for Bearer token authentication.
  """

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
  Creates a changeset for an access key with validations.
  """
  def changeset(access_key, attrs) do
    access_key
    |> cast(attrs, [:key, :user_email, :description, :active, :request_count, :last_used_at])
    |> validate_required([:key])
    |> unique_constraint(:key)
    |> validate_email(:user_email)
  end

  @doc """
  Creates a changeset for a new access key with auto-generated key.
  Generates a key in format "sk_mcp_" followed by 32 random hex characters.
  """
  def create_changeset(attrs) do
    key = "sk_mcp_" <> Base.encode16(:crypto.strong_rand_bytes(32), case: :lower)

    %__MODULE__{}
    |> cast(attrs, [:user_email, :description])
    |> put_change(:key, key)
    |> validate_required([:key])
    |> unique_constraint(:key)
    |> validate_email(:user_email)
  end

  defp validate_email(changeset, field) do
    validate_change(changeset, field, fn _, email ->
      if email && String.contains?(email, "@") do
        []
      else
        [{field, "must be a valid email address"}]
      end
    end)
  end
end
