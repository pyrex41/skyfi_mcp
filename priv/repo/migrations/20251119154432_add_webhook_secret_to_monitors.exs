defmodule SkyfiMcp.Repo.Migrations.AddWebhookSecretToMonitors do
  use Ecto.Migration

  def change do
    alter table(:monitors) do
      add :webhook_secret, :string
    end

    # Generate secrets for existing monitors
    execute(
      "UPDATE monitors SET webhook_secret = lower(hex(randomblob(32))) WHERE webhook_secret IS NULL",
      "ALTER TABLE monitors DROP COLUMN webhook_secret"
    )

    # Make webhook_secret non-nullable after populating existing records
    alter table(:monitors) do
      modify :webhook_secret, :string, null: false
    end
  end
end
