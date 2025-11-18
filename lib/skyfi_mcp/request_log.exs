defmodule SkyfiMcp.RequestLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "request_logs" do
    field :tool_name, :string
    field :success, :boolean, default: true
    field :error_message, :string

    belongs_to :access_key, SkyfiMcp.AccessKey

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(request_log, attrs) do
    request_log
    |> cast(attrs, [:access_key_id, :tool_name, :success, :error_message])
    |> validate_required([:access_key_id, :tool_name])
    |> foreign_key_constraint(:access_key_id)
  end
end
