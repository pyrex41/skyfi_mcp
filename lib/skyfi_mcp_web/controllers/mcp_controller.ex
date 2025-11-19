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
    # Get user context from authentication
    access_key = conn.assigns[:access_key]
    user_api_key_hash = :crypto.hash(:sha256, conn.assigns[:skyfi_api_key]) |> Base.encode16(case: :lower)

    conn = conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> put_resp_header("x-accel-buffering", "no")  # Disable nginx buffering

    # In test mode, return immediately without streaming
    if Application.get_env(:skyfi_mcp, :env) == :test do
      send_resp(conn, 200, "")
    else
      # Subscribe to user-specific events
      Phoenix.PubSub.subscribe(SkyfiMcp.PubSub, "user:#{user_api_key_hash}")

      conn
      |> send_chunked(200)
      |> stream_events(user_api_key_hash)
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

  defp stream_events(conn, user_api_key_hash) do
    # Send initial connection event
    case chunk(conn, "event: connection\ndata: {\"status\":\"ready\"}\n\n") do
      {:ok, conn} ->
        stream_loop(conn, user_api_key_hash)

      {:error, reason} ->
        require Logger
        Logger.warning("SSE: Failed to send initial event: #{inspect(reason)}")
        cleanup_subscription(user_api_key_hash)
        conn
    end
  end

  defp stream_loop(conn, user_api_key_hash) do
    receive do
      # Monitor alerts from PubSub
      {:monitor_alert, monitor_id, data} ->
        event_data = Jason.encode!(%{
          type: "monitor_alert",
          monitor_id: monitor_id,
          data: data,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })

        case chunk(conn, "event: monitor_alert\ndata: #{event_data}\n\n") do
          {:ok, conn} -> stream_loop(conn, user_api_key_hash)
          {:error, _reason} ->
            cleanup_subscription(user_api_key_hash)
            conn
        end

      # Order status updates
      {:order_update, order_id, status} ->
        event_data = Jason.encode!(%{
          type: "order_update",
          order_id: order_id,
          status: status,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })

        case chunk(conn, "event: order_update\ndata: #{event_data}\n\n") do
          {:ok, conn} -> stream_loop(conn, user_api_key_hash)
          {:error, _reason} ->
            cleanup_subscription(user_api_key_hash)
            conn
        end

      # Generic notifications
      {:notification, message} ->
        event_data = Jason.encode!(%{
          type: "notification",
          message: message,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })

        case chunk(conn, "event: notification\ndata: #{event_data}\n\n") do
          {:ok, conn} -> stream_loop(conn, user_api_key_hash)
          {:error, _reason} ->
            cleanup_subscription(user_api_key_hash)
            conn
        end

      # Explicit close
      :close ->
        cleanup_subscription(user_api_key_hash)
        conn

    after
      # Keep-alive ping every 15s
      15_000 ->
        case chunk(conn, ": keep-alive\n\n") do
          {:ok, conn} -> stream_loop(conn, user_api_key_hash)
          {:error, _reason} ->
            cleanup_subscription(user_api_key_hash)
            conn
        end
    end
  end

  defp cleanup_subscription(user_api_key_hash) do
    Phoenix.PubSub.unsubscribe(SkyfiMcp.PubSub, "user:#{user_api_key_hash}")
  end
end
