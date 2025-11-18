defmodule Mix.Tasks.SkyfiMcp.Stdio do
  @moduledoc """
  Starts the SkyFi MCP server in stdio mode for local development.

  This task runs the MCP server using stdio transport, which is compatible
  with Claude Desktop and other MCP clients.

  ## Usage

      $ mix skyfi_mcp.stdio

  The server will read JSON-RPC messages from stdin and write responses to stdout.
  Press Ctrl+C to stop.

  ## Configuration with Claude Desktop

  Add this to your Claude Desktop config:

  ```json
  {
    "mcpServers": {
      "skyfi": {
        "command": "mix",
        "args": ["skyfi_mcp.stdio"],
        "cwd": "/path/to/skyfi_mcp",
        "env": {
          "SKYFI_API_KEY": "your-api-key-here"
        }
      }
    }
  }
  ```
  """

  use Mix.Task

  @shortdoc "Starts the SkyFi MCP server in stdio mode"

  @doc false
  def run(_args) do
    # Start the application
    Mix.Task.run("app.start")

    # Start the stdio transport
    {:ok, _pid} = SkyfiMcp.Transports.Stdio.start_link()

    # Keep the process alive
    :timer.sleep(:infinity)
  end
end
