defmodule SkyfiMcp.McpLogger do
  @moduledoc """
  Conditional logger that respects stdio mode.

  In stdio mode, ALL logging is suppressed to keep stdout clean for JSON-RPC.
  """

  require Logger

  def info(message) do
    unless Application.get_env(:skyfi_mcp, :stdio_mode, false) do
      Logger.info(message)
    end
  end

  def debug(message) do
    unless Application.get_env(:skyfi_mcp, :stdio_mode, false) do
      Logger.debug(message)
    end
  end

  def warning(message) do
    unless Application.get_env(:skyfi_mcp, :stdio_mode, false) do
      Logger.warning(message)
    end
  end

  def error(message) do
    unless Application.get_env(:skyfi_mcp, :stdio_mode, false) do
      Logger.error(message)
    end
  end
end
