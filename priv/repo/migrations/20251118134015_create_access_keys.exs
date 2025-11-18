defmodule SkyfiMcp.Repo.Migrations.CreateAccessKeys do
  use Ecto.Migration

  def change do
    create table(:access_keys) do
      add :key, :string, null: false
      add :user_email, :string
      add :description, :text
      add :active, :boolean, default: true, null: false
      add :request_count, :integer, default: 0, null: false
      add :last_used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:access_keys, [:key])
    create index(:access_keys, [:active])
    create index(:access_keys, [:user_email])
  end
end
