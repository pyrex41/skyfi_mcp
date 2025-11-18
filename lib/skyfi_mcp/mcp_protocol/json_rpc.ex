defmodule SkyfiMcp.McpProtocol.JsonRpc do
  @moduledoc """
  Handles JSON-RPC 2.0 parsing, validation, and response formatting for MCP.
  """

  @jsonrpc_version "2.0"

  # Error Codes
  @parse_error -32700
  @invalid_request -32600
  @method_not_found -32601
  @invalid_params -32602
  @internal_error -32603

  defmodule Request do
    @derive Jason.Encoder
    defstruct [:jsonrpc, :method, :params, :id]
  end

  defmodule Response do
    @derive Jason.Encoder
    defstruct [:jsonrpc, :result, :error, :id]
  end

  defmodule Error do
    @derive Jason.Encoder
    defstruct [:code, :message, :data]
  end

  @doc """
  Parses a raw JSON string into a Request struct or returns an error.
  """
  def parse(raw_json) do
    case Jason.decode(raw_json) do
      {:ok, decoded} -> validate_request(decoded)
      {:error, _} -> {:error, error_response(nil, @parse_error, "Parse error")}
    end
  end

  @doc """
  Parses an already-decoded map (from Phoenix params) into a Request struct or returns an error.
  """
  def parse_map(params) when is_map(params) do
    validate_request(params)
  end

  defp validate_request(%{"jsonrpc" => @jsonrpc_version, "method" => method, "id" => id} = params)
       when is_binary(method) do
    {:ok,
     %Request{
       jsonrpc: @jsonrpc_version,
       method: method,
       params: Map.get(params, "params"),
       id: id
     }}
  end

  defp validate_request(%{"jsonrpc" => @jsonrpc_version, "method" => method} = params)
       when is_binary(method) do
    # Notification (no id)
    {:ok,
     %Request{
       jsonrpc: @jsonrpc_version,
       method: method,
       params: Map.get(params, "params"),
       id: nil
     }}
  end

  defp validate_request(_invalid) do
    {:error, error_response(nil, @invalid_request, "Invalid Request")}
  end

  @doc """
  Formats a success response.
  """
  def success_response(id, result) do
    %Response{
      jsonrpc: @jsonrpc_version,
      id: id,
      result: result
    }
  end

  @doc """
  Formats an error response.
  """
  def error_response(id, code, message, data \\ nil) do
    %Response{
      jsonrpc: @jsonrpc_version,
      id: id,
      error: %Error{
        code: code,
        message: message,
        data: data
      }
    }
  end

  # Helper accessors for standard error codes
  def parse_error(id \\ nil), do: error_response(id, @parse_error, "Parse error")
  def invalid_request(id \\ nil), do: error_response(id, @invalid_request, "Invalid Request")
  def method_not_found(id), do: error_response(id, @method_not_found, "Method not found")
  def invalid_params(id), do: error_response(id, @invalid_params, "Invalid params")
  def internal_error(id), do: error_response(id, @internal_error, "Internal error")
end
