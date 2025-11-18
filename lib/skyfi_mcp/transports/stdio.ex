defmodule SkyfiMcp.Transports.Stdio do
  @moduledoc """
  stdio transport for MCP (Model Context Protocol).

  Reads newline-delimited JSON-RPC 2.0 messages from stdin,
  processes them, and writes responses to stdout.

  This transport is used for local development with Claude Desktop.
  """

  require Logger
  alias SkyfiMcp.McpProtocol.JsonRpc
  alias SkyfiMcp.ToolRouter

  @doc """
  Starts the stdio transport loop.

  Reads from stdin, processes JSON-RPC messages, writes to stdout.
  Runs indefinitely until the process is killed or stdin closes.
  """
  def start_link(_opts \\ []) do
    # Start the stdio loop (no logging - interferes with JSON output)
    Task.start_link(fn -> stdio_loop() end)
  end

  @doc """
  Main stdio processing loop.

  Reads line-by-line from stdin, processes each JSON-RPC message,
  and writes responses to stdout.
  """
  def stdio_loop do
    IO.stream(:stdio, :line)
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Stream.each(&process_message/1)
    |> Stream.run()
  end

  defp process_message(line) do
    case JsonRpc.parse(line) do
      {:ok, request} ->
        # Route the request to appropriate handler
        response = ToolRouter.handle_request(request)

        # Only send response if not nil (notifications return nil)
        if response do
          send_response(response)
        end

      {:error, error_response} ->
        send_response(error_response)
    end
  end

  defp send_response(response) do
    json = Jason.encode!(response)
    IO.puts(json)
  end
end
