defmodule Mix.Tasks.Skyfi.Access.List do
  @moduledoc """
  Lists all access keys with their usage statistics.

  ## Usage

      mix skyfi.access.list [--all]

  ## Options

    • --all - Show inactive keys as well (default: only active keys)

  ## Examples

      mix skyfi.access.list
      mix skyfi.access.list --all
  """

  use Mix.Task

  import Ecto.Query
  alias SkyfiMcp.{Repo, AccessKey}

  @shortdoc "List all MCP access keys"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    show_all = "--all" in args

    query =
      if show_all do
        from a in AccessKey, order_by: [desc: a.inserted_at]
      else
        from a in AccessKey,
          where: a.active == true,
          order_by: [desc: a.inserted_at]
      end

    access_keys = Repo.all(query)

    if Enum.empty?(access_keys) do
      Mix.shell().info("")
      Mix.shell().info("No access keys found.")
      Mix.shell().info("")
      Mix.shell().info("Create one with: mix skyfi.access.create <email> [description]")
      Mix.shell().info("")
    else
      Mix.shell().info("")
      Mix.shell().info("Access Keys:")
      Mix.shell().info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
      Mix.shell().info("")

      Enum.each(access_keys, fn key ->
        status = if key.active, do: "✅ Active", else: "❌ Inactive"
        created = Calendar.strftime(key.inserted_at, "%Y-%m-%d")

        last_used =
          if key.last_used_at do
            Calendar.strftime(key.last_used_at, "%Y-%m-%d %H:%M")
          else
            "Never"
          end

        Mix.shell().info("📧 #{key.user_email}")
        Mix.shell().info("   Status:      #{status}")
        Mix.shell().info("   Key:         #{key.key}")

        if key.description do
          Mix.shell().info("   Description: #{key.description}")
        end

        Mix.shell().info("   Created:     #{created}")
        Mix.shell().info("   Last used:   #{last_used}")
        Mix.shell().info("   Requests:    #{key.request_count}")
        Mix.shell().info("")
      end)

      Mix.shell().info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
      Mix.shell().info("Total: #{length(access_keys)} key(s)")
      Mix.shell().info("")
    end
  end
end
