defmodule SkyfiMcpWeb.McpController do
  use SkyfiMcpWeb, :controller

  alias SkyfiMcp.{Repo, RequestLog}

  # Apply authentication to MCP endpoints
  plug SkyfiMcpWeb.Plugs.AccessKeyAuth when action in [:sse, :message]

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
    # Extract the user's SkyFi API key from assigns (set by AccessKeyAuth plug)
    skyfi_api_key = conn.assigns[:skyfi_api_key]
    access_key = conn.assigns[:access_key]

    # Parse JSON-RPC request
    case SkyfiMcp.McpProtocol.JsonRpc.parse_map(params) do
      {:ok, request} ->
        # Check if this is a notification (id is nil) - notifications don't get responses
        if request.id == nil do
          # Log the notification
          log_request(access_key, request, nil)
          # Return 204 No Content for notifications
          send_resp(conn, 204, "")
        else
          # Route request to tool router with user's API key
          opts = [skyfi_api_key: skyfi_api_key]
          response = SkyfiMcp.ToolRouter.handle_request(request, opts)

          # Log the request
          log_request(access_key, request, response)

          # Send response
          json(conn, response)
        end

      {:error, error} ->
        # Return JSON-RPC error response
        json(conn, error)
    end
  end

  defp log_request(access_key, request, response) do
    tool_name = request.params["name"]
    success = match?(%{result: _}, response)

    error_message =
      case response do
        %{error: error} -> inspect(error)
        _ -> nil
      end

    Task.start(fn ->
      %RequestLog{}
      |> RequestLog.changeset(%{
        access_key_id: access_key.id,
        tool_name: tool_name,
        success: success,
        error_message: error_message
      })
      |> Repo.insert()
    end)
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
