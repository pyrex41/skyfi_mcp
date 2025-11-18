defmodule SkyfiMcp.SkyfiClientTest do
  use ExUnit.Case
  import Tesla.Mock

  alias SkyfiMcp.SkyfiClient

  # Set test API key to avoid raises
  setup do
    Application.put_env(:skyfi_mcp, :skyfi_api_key, "test-key-123")

    on_exit(fn ->
      Application.delete_env(:skyfi_mcp, :skyfi_api_key)
    end)

    :ok
  end

  describe "search_archive/2" do
    test "makes correct GET request to /archives" do
      mock(fn %{method: :get, url: "https://app.skyfi.com/platform-api/archives"} ->
        json(%{data: [%{id: "img_123", cloud_cover: 5.2}]}, status: 200)
      end)

      assert {:ok, %{"data" => [%{"id" => "img_123"}]}} =
               SkyfiClient.search_archive(%{bbox: [-122.5, 37.7, -122.3, 37.8]})
    end

    test "returns error for 401 unauthorized" do
      mock(fn %{method: :get, url: "https://app.skyfi.com/platform-api/archives"} ->
        json(%{error: "Invalid API key"}, status: 401)
      end)

      assert {:error, :invalid_api_key} = SkyfiClient.search_archive(%{bbox: []})
    end

    test "returns error for 404 not found" do
      mock(fn %{method: :get, url: "https://app.skyfi.com/platform-api/archives"} ->
        json(%{error: "Not found"}, status: 404)
      end)

      assert {:error, :not_found} = SkyfiClient.search_archive(%{bbox: []})
    end

    test "returns error for 429 rate limit" do
      mock(fn %{method: :get, url: "https://app.skyfi.com/platform-api/archives"} ->
        json(%{error: "Too many requests"}, status: 429)
      end)

      assert {:error, {:rate_limit_exceeded, _}} = SkyfiClient.search_archive(%{bbox: []})
    end

    test "returns error for 500 server error" do
      mock(fn %{method: :get, url: "https://app.skyfi.com/platform-api/archives"} ->
        json(%{error: "Internal server error"}, status: 500)
      end)

      assert {:error, {:server_error, 500}} = SkyfiClient.search_archive(%{bbox: []})
    end

    test "returns error for 400 bad request with message parsing" do
      mock(fn %{method: :get, url: "https://app.skyfi.com/platform-api/archives"} ->
        json(%{error: "Invalid bbox format"}, status: 400)
      end)

      assert {:error, {:bad_request, "Invalid bbox format"}} =
               SkyfiClient.search_archive(%{bbox: []})
    end

    test "handles network timeout" do
      mock(fn %{method: :get, url: "https://app.skyfi.com/platform-api/archives"} ->
        {:error, :timeout}
      end)

      assert {:error, :timeout} = SkyfiClient.search_archive(%{bbox: []})
    end

    test "handles connection refused" do
      mock(fn %{method: :get, url: "https://app.skyfi.com/platform-api/archives"} ->
        {:error, :econnrefused}
      end)

      assert {:error, :connection_refused} = SkyfiClient.search_archive(%{bbox: []})
    end
  end

  describe "check_feasibility/2" do
    test "makes correct POST request to /feasibility" do
      mock(fn %{method: :post, url: "https://app.skyfi.com/platform-api/feasibility"} ->
        json(%{probability: 0.85, pass_times: ["2024-02-01T10:00:00Z"]}, status: 200)
      end)

      assert {:ok, %{"probability" => 0.85}} =
               SkyfiClient.check_feasibility(%{aoi: %{type: "Polygon"}})
    end

    test "returns error for invalid request" do
      mock(fn %{method: :post, url: "https://app.skyfi.com/platform-api/feasibility"} ->
        json(%{message: "Invalid AOI geometry"}, status: 400)
      end)

      assert {:error, {:bad_request, "Invalid AOI geometry"}} =
               SkyfiClient.check_feasibility(%{aoi: %{}})
    end
  end

  describe "get_price_estimate/2" do
    test "makes correct POST request to /pricing" do
      mock(fn %{method: :post, url: "https://app.skyfi.com/platform-api/pricing"} ->
        json(%{total: 250.0, currency: "USD", breakdown: %{base: 200, area: 50}}, status: 200)
      end)

      assert {:ok, %{"total" => 250.0}} =
               SkyfiClient.get_price_estimate(%{archive_id: "img_123"})
    end

    test "handles server errors" do
      mock(fn %{method: :post, url: "https://app.skyfi.com/platform-api/pricing"} ->
        json(%{error: "Pricing service unavailable"}, status: 503)
      end)

      assert {:error, {:server_error, 503}} =
               SkyfiClient.get_price_estimate(%{archive_id: "img_123"})
    end
  end

  describe "place_order/2" do
    test "uses /order-archive endpoint for archive orders" do
      mock(fn %{method: :post, url: "https://app.skyfi.com/platform-api/order-archive"} ->
        json(%{id: "ord_456", status: "pending", archive_id: "img_123"}, status: 201)
      end)

      assert {:ok, %{"id" => "ord_456"}} =
               SkyfiClient.place_order(%{archive_id: "img_123", confirm_price: 250.0})
    end

    test "uses /order-tasking endpoint for tasking orders" do
      mock(fn %{method: :post, url: "https://app.skyfi.com/platform-api/order-tasking"} ->
        json(%{id: "ord_789", status: "pending"}, status: 201)
      end)

      assert {:ok, %{"id" => "ord_789"}} =
               SkyfiClient.place_order(%{aoi: %{}, sensor_type: "optical", confirm_price: 500.0})
    end

    test "accepts both 200 and 201 status codes" do
      mock(fn %{method: :post, url: "https://app.skyfi.com/platform-api/order-archive"} ->
        json(%{id: "ord_999"}, status: 200)
      end)

      assert {:ok, %{"id" => "ord_999"}} =
               SkyfiClient.place_order(%{archive_id: "img_123"})
    end

    test "returns error for 403 access denied" do
      mock(fn %{method: :post, url: "https://app.skyfi.com/platform-api/order-archive"} ->
        json(%{error: "Insufficient credits"}, status: 403)
      end)

      assert {:error, :access_denied} = SkyfiClient.place_order(%{archive_id: "img_123"})
    end
  end

  describe "list_orders/2" do
    test "makes correct GET request to /orders" do
      mock(fn %{method: :get, url: "https://app.skyfi.com/platform-api/orders"} ->
        json(
          %{
            orders: [
              %{id: "ord_1", status: "completed"},
              %{id: "ord_2", status: "pending"}
            ]
          },
          status: 200
        )
      end)

      assert {:ok, %{"orders" => orders}} = SkyfiClient.list_orders()
      assert length(orders) == 2
    end

    test "includes query parameters" do
      mock(fn %{method: :get, url: "https://app.skyfi.com/platform-api/orders"} = env ->
        assert env.query == %{status: "pending", limit: 5}
        json(%{orders: []}, status: 200)
      end)

      assert {:ok, %{"orders" => []}} =
               SkyfiClient.list_orders(%{status: "pending", limit: 5})
    end

    test "works with no parameters" do
      mock(fn %{method: :get, url: "https://app.skyfi.com/platform-api/orders"} = env ->
        assert env.query == %{}
        json(%{orders: []}, status: 200)
      end)

      assert {:ok, %{"orders" => []}} = SkyfiClient.list_orders()
    end
  end

  describe "get_order/2" do
    test "makes correct GET request to /orders/:id" do
      mock(fn %{method: :get, url: "https://app.skyfi.com/platform-api/orders/ord_123"} ->
        json(%{id: "ord_123", status: "completed", price: 250.0}, status: 200)
      end)

      assert {:ok, %{"id" => "ord_123", "status" => "completed"}} =
               SkyfiClient.get_order("ord_123")
    end

    test "returns 404 for non-existent order" do
      mock(fn %{method: :get, url: "https://app.skyfi.com/platform-api/orders/ord_999"} ->
        json(%{error: "Order not found"}, status: 404)
      end)

      assert {:error, :not_found} = SkyfiClient.get_order("ord_999")
    end
  end

  describe "client/2" do
    test "accepts explicit API key" do
      client = SkyfiClient.client("explicit-key")
      assert %Tesla.Client{} = client
    end

    test "accepts timeout option" do
      client = SkyfiClient.client("key", timeout: 60_000)
      assert %Tesla.Client{} = client
    end

    test "uses environment variable when no key provided" do
      System.put_env("SKYFI_API_KEY", "env-key")

      on_exit(fn ->
        System.delete_env("SKYFI_API_KEY")
      end)

      client = SkyfiClient.client()
      assert %Tesla.Client{} = client
    end
  end

  describe "error message parsing" do
    test "parses error field from response" do
      mock(fn %{method: :get, url: "https://app.skyfi.com/platform-api/archives"} ->
        json(%{error: "Custom error message"}, status: 400)
      end)

      assert {:error, {:bad_request, "Custom error message"}} =
               SkyfiClient.search_archive(%{})
    end

    test "parses message field from response" do
      mock(fn %{method: :get, url: "https://app.skyfi.com/platform-api/archives"} ->
        json(%{message: "Another error format"}, status: 400)
      end)

      assert {:error, {:bad_request, "Another error format"}} = SkyfiClient.search_archive(%{})
    end

    test "parses errors array from response" do
      mock(fn %{method: :get, url: "https://app.skyfi.com/platform-api/archives"} ->
        json(%{errors: ["Error 1", "Error 2", "Error 3"]}, status: 400)
      end)

      assert {:error, {:bad_request, "Error 1, Error 2, Error 3"}} =
               SkyfiClient.search_archive(%{})
    end

    test "falls back to inspect for unknown format" do
      mock(fn %{method: :get, url: "https://app.skyfi.com/platform-api/archives"} ->
        json(%{unknown_field: "something"}, status: 400)
      end)

      assert {:error, {:bad_request, error_msg}} = SkyfiClient.search_archive(%{})
      assert is_binary(error_msg)
    end
  end

  describe "API key configuration" do
    test "raises helpful error when no API key configured" do
      Application.delete_env(:skyfi_mcp, :skyfi_api_key)
      System.delete_env("SKYFI_API_KEY")

      assert_raise RuntimeError, ~r/SkyFi API key not configured/, fn ->
        SkyfiClient.client()
      end
    end

    test "uses application config when available" do
      Application.put_env(:skyfi_mcp, :skyfi_api_key, "config-key")
      client = SkyfiClient.client()
      assert %Tesla.Client{} = client
    end
  end
end
