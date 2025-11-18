defmodule SkyfiMcp.McpProtocol.JsonRpcTest do
  use ExUnit.Case
  alias SkyfiMcp.McpProtocol.JsonRpc

  test "parses valid request with id" do
    json = ~s({"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "test"}, "id": 1})
    assert {:ok, %JsonRpc.Request{method: "tools/call", id: 1}} = JsonRpc.parse(json)
  end

  test "parses valid notification (no id)" do
    json = ~s({"jsonrpc": "2.0", "method": "notifications/initialized"})
    assert {:ok, %JsonRpc.Request{method: "notifications/initialized", id: nil}} = JsonRpc.parse(json)
  end

  test "returns parse error for invalid JSON" do
    json = ~s({"jsonrpc": "2.0", "method": )
    assert {:error, %JsonRpc.Response{error: %JsonRpc.Error{code: -32700}}} = JsonRpc.parse(json)
  end

  test "returns invalid request for missing version" do
    json = ~s({"method": "test", "id": 1})
    assert {:error, %JsonRpc.Response{error: %JsonRpc.Error{code: -32600}}} = JsonRpc.parse(json)
  end

  test "returns invalid request for missing method" do
    json = ~s({"jsonrpc": "2.0", "id": 1})
    assert {:error, %JsonRpc.Response{error: %JsonRpc.Error{code: -32600}}} = JsonRpc.parse(json)
  end

  test "formats success response" do
    response = JsonRpc.success_response(1, %{status: "ok"})
    assert response.jsonrpc == "2.0"
    assert response.id == 1
    assert response.result == %{status: "ok"}
    assert response.error == nil
  end

  test "formats error response" do
    response = JsonRpc.error_response(1, -32601, "Method not found")
    assert response.jsonrpc == "2.0"
    assert response.id == 1
    assert response.error.code == -32601
    assert response.error.message == "Method not found"
    assert response.result == nil
  end
end
