defmodule SkyfiMcp.Repo.Migrations.CreateMonitors do
  use Ecto.Migration

  def change do
    create table(:monitors, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # User context (for multi-tenancy) - hash of API key
      add :user_api_key_hash, :string, null: false

      # AOI definition as GeoJSON Polygon
      add :aoi, :map, null: false

      # Monitoring criteria (cloud_cover_max, sensor_types, resolution_min)
      add :criteria, :map, null: false

      # Webhook configuration
      add :webhook_url, :string, null: false
      add :check_interval, :integer, default: 86400  # seconds (default: daily)

      # State tracking
      add :last_checked_at, :utc_datetime
      add :last_image_id, :string
      add :status, :string, default: "active"  # active | paused | failed

      timestamps(type: :utc_datetime)
    end

    create index(:monitors, [:status])
    create index(:monitors, [:user_api_key_hash])
    create index(:monitors, [:last_checked_at])
    # Composite index for worker queries (active monitors due for checking)
    create index(:monitors, [:status, :last_checked_at])
  end
end
