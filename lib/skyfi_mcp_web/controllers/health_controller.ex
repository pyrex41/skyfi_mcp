defmodule SkyfiMcpWeb.HealthController do
  use SkyfiMcpWeb, :controller

  alias SkyfiMcp.Repo

  @doc """
  Health check endpoint for monitoring and deployment readiness.

  Returns:
  - 200: Service is healthy and ready
  - 503: Service is unhealthy

  Response includes:
  - status: "ok" or "error"
  - version: Application version
  - database: Database connection status
  - mcp_protocol: MCP protocol version
  - uptime: Server uptime in seconds
  """
  def check(conn, _params) do
    db_status = check_database()
    uptime = :erlang.statistics(:wall_clock) |> elem(0) |> div(1000)

    response = %{
      status: if(db_status == "connected", do: "ok", else: "error"),
      version: Application.spec(:skyfi_mcp, :vsn) |> to_string(),
      mcp_protocol: "2024-11-05",
      database: db_status,
      uptime_seconds: uptime,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    status_code = if response.status == "ok", do: 200, else: 503

    conn
    |> put_status(status_code)
    |> json(response)
  end

  defp check_database do
    case Ecto.Adapters.SQL.query(Repo, "SELECT 1", []) do
      {:ok, _} -> "connected"
      {:error, _} -> "error"
    end
  end
end
