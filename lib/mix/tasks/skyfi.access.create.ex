defmodule Mix.Tasks.Skyfi.Access.Create do
  @moduledoc """
  Creates a new access key for MCP server authentication.

  ## Usage

      mix skyfi.access.create <email> <description>

  ## Examples

      mix skyfi.access.create john@example.com "Conference demo user"
      mix skyfi.access.create alice@company.com "Internal beta tester"

  The generated access key will be printed and can be shared with the user.
  """

  use Mix.Task

  alias SkyfiMcp.{Repo, AccessKey}

  @shortdoc "Create a new MCP access key"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [email, description] ->
        create_access_key(email, description)

      [email] ->
        create_access_key(email, nil)

      _ ->
        Mix.shell().error("Usage: mix skyfi.access.create <email> [description]")
        Mix.shell().error("")
        Mix.shell().error("Example:")
        Mix.shell().error(~s|  mix skyfi.access.create john@example.com "Demo user"|)
    end
  end

  defp create_access_key(email, description) do
    changeset =
      AccessKey.create_changeset(%{
        user_email: email,
        description: description
      })

    case Repo.insert(changeset) do
      {:ok, access_key} ->
        Mix.shell().info("")
        Mix.shell().info("✅ Access key created successfully!")
        Mix.shell().info("")
        Mix.shell().info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Mix.shell().info("📧 Email:       #{access_key.user_email}")

        if access_key.description do
          Mix.shell().info("📝 Description: #{access_key.description}")
        end

        Mix.shell().info("🔑 Access Key:  #{access_key.key}")
        Mix.shell().info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Mix.shell().info("")
        Mix.shell().info("Share this key with the user. They will need to provide it when")
        Mix.shell().info("connecting to the MCP server.")
        Mix.shell().info("")

      {:error, changeset} ->
        Mix.shell().error("❌ Failed to create access key:")
        Mix.shell().error("")

        Enum.each(changeset.errors, fn {field, {message, _}} ->
          Mix.shell().error("  • #{field}: #{message}")
        end)
    end
  end
end
