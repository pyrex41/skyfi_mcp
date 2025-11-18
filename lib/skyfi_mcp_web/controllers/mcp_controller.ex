defmodule SkyfiMcpWeb.McpController do
  use SkyfiMcpWeb, :controller

  @doc """
  Handles SSE connections for MCP.
  GET /mcp/sse
  """
  def sse(conn, _params) do
    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> send_chunked(200)

    if Application.get_env(:skyfi_mcp, :env) == :test do
      conn
    else
      stream_events(conn)
    end
  end

  @doc """
  Handles incoming POST messages for an active SSE session.
  POST /mcp/message
  """
  def message(conn, _params) do
    # In a real implementation, we would route this to the specific GenServer
    # associated with the session ID. For now, we'll just echo it back
    # or process it statelessly if possible.
    
    # TODO: Implement full session handling
    json(conn, %{status: "received"})
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
