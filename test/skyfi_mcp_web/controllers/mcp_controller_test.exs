defmodule SkyfiMcpWeb.McpControllerTest do
  use SkyfiMcpWeb.ConnCase

  test "GET /mcp/sse returns event stream", %{conn: conn} do
    conn = get(conn, ~p"/mcp/sse")
    
    assert get_resp_header(conn, "content-type") == ["text/event-stream"]
    assert conn.status == 200
    # In a real test we might need to verify the chunked response, 
    # but for now we check headers and status.
  end

  test "POST /mcp/message accepts messages", %{conn: conn} do
    conn = post(conn, ~p"/mcp/message", %{jsonrpc: "2.0", method: "test"})
    assert json_response(conn, 200) == %{"status" => "received"}
  end
end
