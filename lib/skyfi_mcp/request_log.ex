defmodule SkyfiMcp.RequestLog do
  @moduledoc """
  Schema for logging tool execution requests per access key.

  Tracks usage statistics and provides audit trail for debugging and
  monitoring purposes. Each log entry records which tool was called,
  whether it succeeded, and any error details.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "request_logs" do
    belongs_to :access_key, SkyfiMcp.AccessKey
    field :tool_name, :string
    field :success, :boolean, default: true
    field :error_message, :string

    # Only has inserted_at (no updated_at for logs)
    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Creates a changeset for a request log with validations.
  """
  def changeset(request_log, attrs) do
    request_log
    |> cast(attrs, [:access_key_id, :tool_name, :success, :error_message])
    |> validate_required([:access_key_id, :tool_name, :success])
    |> foreign_key_constraint(:access_key_id)
  end
end
