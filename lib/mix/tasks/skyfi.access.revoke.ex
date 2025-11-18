defmodule Mix.Tasks.Skyfi.Access.Revoke do
  @moduledoc """
  Revokes (deactivates) an access key.

  ## Usage

      mix skyfi.access.revoke <access_key>

  ## Examples

      mix skyfi.access.revoke sk_mcp_abc123def456ghi789

  The key will be marked as inactive and can no longer be used to authenticate.
  The key record is preserved for audit purposes.
  """

  use Mix.Task

  alias SkyfiMcp.{Repo, AccessKey}

  @shortdoc "Revoke an MCP access key"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [key] ->
        revoke_access_key(key)

      _ ->
        Mix.shell().error("Usage: mix skyfi.access.revoke <access_key>")
        Mix.shell().error("")
        Mix.shell().error("Example:")
        Mix.shell().error("  mix skyfi.access.revoke sk_mcp_abc123def456")
    end
  end

  defp revoke_access_key(key) do
    case Repo.get_by(AccessKey, key: key) do
      nil ->
        Mix.shell().error("")
        Mix.shell().error("❌ Access key not found: #{key}")
        Mix.shell().error("")

      access_key ->
        if access_key.active do
          access_key
          |> Ecto.Changeset.change(active: false)
          |> Repo.update!()

          Mix.shell().info("")
          Mix.shell().info("✅ Access key revoked successfully!")
          Mix.shell().info("")
          Mix.shell().info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
          Mix.shell().info("📧 Email:       #{access_key.user_email}")
          Mix.shell().info("🔑 Key:         #{access_key.key}")

          if access_key.description do
            Mix.shell().info("📝 Description: #{access_key.description}")
          end

          Mix.shell().info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
          Mix.shell().info("")
          Mix.shell().info("This key can no longer be used to authenticate.")
          Mix.shell().info("")
        else
          Mix.shell().info("")
          Mix.shell().info("ℹ️  This key is already inactive.")
          Mix.shell().info("")
        end
    end
  end
end
