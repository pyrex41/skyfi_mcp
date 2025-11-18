defmodule SkyfiMcpWeb.McpController do
  use SkyfiMcpWeb, :controller

  @doc """
  Handles SSE connections for MCP.
  GET /mcp/sse
  """
  def sse(conn, _params) do
    conn = conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")

    # In test mode, return immediately without streaming
    if Application.get_env(:skyfi_mcp, :env) == :test do
      send_resp(conn, 200, "")
    else
      conn
      |> send_chunked(200)
      |> stream_events()
    end
  end

  @doc """
  Handles incoming POST messages for an active SSE session.
  POST /mcp/message
  """
  def message(conn, params) do
    # Parse JSON-RPC request
    case SkyfiMcp.McpProtocol.JsonRpc.parse_map(params) do
      {:ok, request} ->
        # TODO: Route to appropriate tool handler based on request.method
        # For now, just acknowledge the request
        response = %{
          jsonrpc: "2.0",
          id: request.id,
          result: %{status: "received", method: request.method}
        }
        json(conn, response)

      {:error, error} ->
        # Return JSON-RPC error response
        json(conn, error)
    end
  end

  defp stream_events(conn) do
    # Send initial connection event
    {:ok, conn} = chunk(conn, "event: connection\ndata: ready\n\n")
    
    # Keep connection open (loop)
    # In a real app, this would listen to a PubSub topic
    receive do
      {:message, msg} ->
        chunk(conn, "event: message\ndata: #{msg}\n\n")
        stream_events(conn)
      :close ->
        conn
    after
      # Keep-alive ping every 15s
      15_000 ->
        chunk(conn, ": keep-alive\n\n")
        stream_events(conn)
    end
  end
end
