defmodule SkyfiMcp.Repo.Migrations.CreateRequestLogs do
  use Ecto.Migration

  def change do
    create table(:request_logs) do
      add :access_key_id, references(:access_keys, on_delete: :delete_all), null: false
      add :tool_name, :string, null: false
      add :success, :boolean, default: true, null: false
      add :error_message, :text

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:request_logs, [:access_key_id])
    create index(:request_logs, [:tool_name])
    create index(:request_logs, [:inserted_at])
  end
end
