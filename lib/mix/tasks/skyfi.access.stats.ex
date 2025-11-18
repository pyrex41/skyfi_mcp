defmodule Mix.Tasks.Skyfi.Access.Stats do
  @moduledoc """
  Shows usage statistics for access keys.

  ## Usage

      mix skyfi.access.stats [access_key]

  ## Examples

      # Show aggregate stats for all keys
      mix skyfi.access.stats

      # Show detailed stats for a specific key
      mix skyfi.access.stats sk_mcp_abc123def456ghi789
  """

  use Mix.Task

  import Ecto.Query
  alias SkyfiMcp.{Repo, AccessKey, RequestLog}

  @shortdoc "Show usage statistics for access keys"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [] ->
        show_aggregate_stats()

      [key] ->
        show_key_stats(key)

      _ ->
        Mix.shell().error("Usage: mix skyfi.access.stats [access_key]")
        Mix.shell().error("")
        Mix.shell().error("Examples:")
        Mix.shell().error("  mix skyfi.access.stats                       # All keys")
        Mix.shell().error("  mix skyfi.access.stats sk_mcp_abc123def456   # Specific key")
    end
  end

  defp show_aggregate_stats do
    total_keys = Repo.aggregate(AccessKey, :count, :id)
    active_keys = Repo.aggregate(from(a in AccessKey, where: a.active), :count, :id)
    total_requests = Repo.aggregate(AccessKey, :sum, :request_count) || 0

    Mix.shell().info("")
    Mix.shell().info("MCP Server Statistics")
    Mix.shell().info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    Mix.shell().info("")
    Mix.shell().info("Access Keys:")
    Mix.shell().info("  • Total:   #{total_keys}")
    Mix.shell().info("  • Active:  #{active_keys}")
    Mix.shell().info("  • Revoked: #{total_keys - active_keys}")
    Mix.shell().info("")
    Mix.shell().info("Requests:")
    Mix.shell().info("  • Total:   #{total_requests}")
    Mix.shell().info("")

    # Tool usage breakdown
    tool_stats =
      from(r in RequestLog,
        group_by: r.tool_name,
        select: {r.tool_name, count(r.id)},
        order_by: [desc: count(r.id)]
      )
      |> Repo.all()

    if Enum.any?(tool_stats) do
      Mix.shell().info("Tool Usage:")

      Enum.each(tool_stats, fn {tool_name, count} ->
        Mix.shell().info("  • #{String.pad_trailing(tool_name, 20)} #{count}")
      end)

      Mix.shell().info("")
    end

    Mix.shell().info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    Mix.shell().info("")
  end

  defp show_key_stats(key) do
    case Repo.get_by(AccessKey, key: key) |> Repo.preload(:request_logs) do
      nil ->
        Mix.shell().error("")
        Mix.shell().error("❌ Access key not found: #{key}")
        Mix.shell().error("")

      access_key ->
        status = if access_key.active, do: "Active", else: "Inactive"

        last_used =
          if access_key.last_used_at do
            Calendar.strftime(access_key.last_used_at, "%Y-%m-%d %H:%M:%S")
          else
            "Never"
          end

        Mix.shell().info("")
        Mix.shell().info("Access Key Details")
        Mix.shell().info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Mix.shell().info("")
        Mix.shell().info("Key Info:")
        Mix.shell().info("  • Email:       #{access_key.user_email}")

        if access_key.description do
          Mix.shell().info("  • Description: #{access_key.description}")
        end

        Mix.shell().info("  • Status:      #{status}")
        Mix.shell().info("  • Key:         #{access_key.key}")
        Mix.shell().info("")
        Mix.shell().info("Usage:")
        Mix.shell().info("  • Total requests: #{access_key.request_count}")
        Mix.shell().info("  • Last used:      #{last_used}")
        Mix.shell().info("")

        # Tool-specific breakdown
        tool_stats =
          from(r in RequestLog,
            where: r.access_key_id == ^access_key.id,
            group_by: r.tool_name,
            select: {r.tool_name, count(r.id)},
            order_by: [desc: count(r.id)]
          )
          |> Repo.all()

        if Enum.any?(tool_stats) do
          Mix.shell().info("Tool Usage Breakdown:")

          Enum.each(tool_stats, fn {tool_name, count} ->
            percentage = Float.round(count / access_key.request_count * 100, 1)
            Mix.shell().info("  • #{String.pad_trailing(tool_name, 20)} #{count} (#{percentage}%)")
          end)

          Mix.shell().info("")
        end

        # Recent requests (last 10)
        recent_logs =
          from(r in RequestLog,
            where: r.access_key_id == ^access_key.id,
            order_by: [desc: r.inserted_at],
            limit: 10
          )
          |> Repo.all()

        if Enum.any?(recent_logs) do
          Mix.shell().info("Recent Requests (last 10):")

          Enum.each(recent_logs, fn log ->
            timestamp = Calendar.strftime(log.inserted_at, "%Y-%m-%d %H:%M:%S")
            status_icon = if log.success, do: "✅", else: "❌"
            Mix.shell().info("  #{status_icon} #{timestamp}  #{log.tool_name}")
          end)

          Mix.shell().info("")
        end

        Mix.shell().info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Mix.shell().info("")
    end
  end
end
