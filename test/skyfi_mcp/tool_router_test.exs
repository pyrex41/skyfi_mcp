defmodule SkyfiMcp.ToolRouterTest do
  use ExUnit.Case
  import Tesla.Mock

  alias SkyfiMcp.ToolRouter
  alias SkyfiMcp.McpProtocol.JsonRpc

  setup do
    # Configure API key for tests
    Application.put_env(:skyfi_mcp, :skyfi_api_key, "test_api_key")

    mock(fn
      %{method: :get, url: "https://api.skyfi.com/archives"} ->
        json(%{
          "data" => [
            %{
              "id" => "img_test_123",
              "capture_date" => "2023-06-15T14:30:00Z",
              "cloud_cover" => 5,
              "thumbnail_url" => "https://example.com/thumb.jpg",
              "preview_url" => "https://example.com/preview.jpg",
              "resolution" => 0.5,
              "sensor_type" => "optical"
            }
          ]
        })
    end)

    on_exit(fn ->
      Application.delete_env(:skyfi_mcp, :skyfi_api_key)
    end)

    :ok
  end

  describe "initialize" do
    test "returns server info and capabilities" do
      request = %JsonRpc.Request{
        jsonrpc: "2.0",
        method: "initialize",
        params: %{},
        id: 1
      }

      response = ToolRouter.handle_request(request)

      assert response.jsonrpc == "2.0"
      assert response.id == 1
      assert response.result.serverInfo.name == "skyfi-mcp"
      assert response.result.serverInfo.version == "0.1.0"
      assert response.result.protocolVersion == "2024-11-05"
      assert Map.has_key?(response.result.capabilities, :tools)
    end
  end

  describe "tools/list" do
    test "returns list of available tools" do
      request = %JsonRpc.Request{
        jsonrpc: "2.0",
        method: "tools/list",
        params: %{},
        id: 2
      }

      response = ToolRouter.handle_request(request)

      assert response.jsonrpc == "2.0"
      assert response.id == 2
      assert is_list(response.result.tools)
      assert length(response.result.tools) > 0

      search_tool = Enum.find(response.result.tools, fn t -> t.name == "search_archive" end)
      assert search_tool != nil
      assert search_tool.description =~ "Search SkyFi"
      assert Map.has_key?(search_tool, :inputSchema)
    end
  end

  describe "tools/call" do
    test "executes search_archive tool successfully" do
      request = %JsonRpc.Request{
        jsonrpc: "2.0",
        method: "tools/call",
        params: %{
          "name" => "search_archive",
          "arguments" => %{
            "aoi" => [0, 0, 1, 1],
            "start_date" => "2023-01-01T00:00:00Z",
            "end_date" => "2023-12-31T23:59:59Z"
          }
        },
        id: 3
      }

      response = ToolRouter.handle_request(request)

      assert response.jsonrpc == "2.0"
      assert response.id == 3
      assert is_list(response.result.content)
      assert length(response.result.content) > 0

      content = List.first(response.result.content)
      assert content.type == "text"
      assert is_binary(content.text)

      # Parse the JSON result
      result = Jason.decode!(content.text)
      assert is_list(result)
      assert length(result) == 1

      image = List.first(result)
      assert image["id"] == "img_test_123"
      assert image["cloud_cover"] == 5
    end

    test "returns error for unknown tool" do
      request = %JsonRpc.Request{
        jsonrpc: "2.0",
        method: "tools/call",
        params: %{
          "name" => "unknown_tool",
          "arguments" => %{}
        },
        id: 4
      }

      response = ToolRouter.handle_request(request)

      assert response.jsonrpc == "2.0"
      assert response.id == 4
      assert Map.has_key?(response, :error)
      assert response.error.code == -32000
      assert response.error.message =~ "Unknown tool"
    end

    test "returns error for invalid tool arguments" do
      request = %JsonRpc.Request{
        jsonrpc: "2.0",
        method: "tools/call",
        params: %{
          "name" => "search_archive",
          "arguments" => %{
            # Missing required fields
            "aoi" => [0, 0, 1, 1]
          }
        },
        id: 5
      }

      response = ToolRouter.handle_request(request)

      assert response.jsonrpc == "2.0"
      assert response.id == 5
      assert Map.has_key?(response, :error)
    end
  end

  describe "unknown methods" do
    test "returns method not found error" do
      request = %JsonRpc.Request{
        jsonrpc: "2.0",
        method: "unknown/method",
        params: %{},
        id: 6
      }

      response = ToolRouter.handle_request(request)

      assert response.jsonrpc == "2.0"
      assert response.id == 6
      assert Map.has_key?(response, :error)
      assert response.error.code == -32601
      assert response.error.message == "Method not found"
    end
  end

  describe "notifications" do
    test "returns nil for notifications (no id)" do
      request = %JsonRpc.Request{
        jsonrpc: "2.0",
        method: "some/notification",
        params: %{},
        id: nil
      }

      response = ToolRouter.handle_request(request)

      assert response == nil
    end
  end
end
