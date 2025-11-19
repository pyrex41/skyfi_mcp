defmodule SkyfiMcp.SkyfiClient do
  @moduledoc """
  Tesla-based HTTP client for the SkyFi Public API.

  This module provides a wrapper around the SkyFi API with proper error handling,
  timeout management, and response normalization. All functions return either
  `{:ok, data}` or `{:error, reason}` tuples.

  ## Configuration

  The API key can be provided in three ways:
  1. Explicitly passed to each function
  2. Configured in the application environment: `config :skyfi_mcp, :skyfi_api_key, "..."`
  3. Set as an environment variable: `SKYFI_API_KEY`

  ## Example

      # With explicit API key
      {:ok, archives} = SkyfiClient.search_archive("my-api-key", %{
        bbox: [-122.5, 37.7, -122.3, 37.8],
        start_date: "2024-01-01",
        end_date: "2024-01-31"
      })

      # With configured API key
      {:ok, archives} = SkyfiClient.search_archive(%{bbox: [...]})

  ## Error Handling

  All functions handle common HTTP errors:
  - `401` - Invalid API key
  - `403` - Access denied
  - `404` - Resource not found
  - `429` - Rate limit exceeded
  - `500-599` - Server errors
  - `:timeout` - Request timeout
  - Network errors
  """

  use Tesla

  require Logger

  # Base URL for SkyFi API
  @base_url "https://app.skyfi.com/platform-api"
  @default_timeout 30_000  # 30 seconds

  @doc """
  Builds a Tesla client with the given API key and middleware.

  ## Options

  - `:api_key` - SkyFi API key (optional if configured)
  - `:timeout` - Request timeout in milliseconds (default: 30,000)

  ## Examples

      client = SkyfiClient.client("my-api-key")
      client = SkyfiClient.client("my-api-key", timeout: 60_000)
  """
  def client(api_key \\ nil, opts \\ []) do
    key = api_key || get_api_key()
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    middleware = [
      {Tesla.Middleware.BaseUrl, @base_url},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers, [{"x-api-key", key}]},
      {Tesla.Middleware.Timeout, timeout: timeout},
      {Tesla.Middleware.Retry,
       delay: 500,
       max_retries: 3,
       max_delay: 4_000,
       should_retry: fn
         {:ok, %{status: status}} when status in [408, 429, 500, 502, 503, 504] -> true
         {:ok, _} -> false
         {:error, _} -> true
       end}
    ]

    Tesla.client(middleware)
  end

  @doc """
  Search for existing satellite imagery in the archive.

  ## Parameters

  - `params` - Search parameters map with:
    - `:bbox` - Bounding box as [min_lon, min_lat, max_lon, max_lat]
    - `:start_date` - Start date (ISO8601 format)
    - `:end_date` - End date (ISO8601 format)
    - `:cloud_cover_max` - Maximum cloud cover percentage (0-100)
    - `:limit` - Maximum number of results (optional)

  ## Returns

  - `{:ok, archives}` - List of archive imagery
  - `{:error, reason}` - Error tuple

  ## Examples

      {:ok, results} = SkyfiClient.search_archive(%{
        bbox: [-122.5, 37.7, -122.3, 37.8],
        start_date: "2024-01-01",
        end_date: "2024-01-31",
        cloud_cover_max: 20
      })
  """
  def search_archive(api_key \\ nil, params)

  def search_archive(params, _) when is_map(params) do
    # Called with just params, no API key
    search_archive(nil, params)
  end

  def search_archive(api_key, params) when is_binary(api_key) or is_nil(api_key) do
    client = client(api_key)

    case get(client, "/archives", query: params) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        handle_error(status, body)

      {:error, reason} ->
        handle_network_error(reason)
    end
  end

  @doc """
  Check feasibility for capturing new satellite imagery.

  ## Parameters

  - `params` - Feasibility check parameters:
    - `:aoi` - Area of interest as GeoJSON
    - `:start_date` - Earliest capture date
    - `:end_date` - Latest capture date
    - `:sensor_type` - "optical" or "sar"

  ## Returns

  - `{:ok, feasibility}` - Feasibility data with probability and pass times
  - `{:error, reason}` - Error tuple

  ## Examples

      {:ok, feasibility} = SkyfiClient.check_feasibility(%{
        aoi: %{type: "Polygon", coordinates: [...]},
        start_date: "2024-02-01",
        end_date: "2024-02-07",
        sensor_type: "optical"
      })
  """
  def check_feasibility(api_key \\ nil, params)

  def check_feasibility(params, _) when is_map(params) do
    check_feasibility(nil, params)
  end

  def check_feasibility(api_key, params) when is_binary(api_key) or is_nil(api_key) do
    client = client(api_key)

    case post(client, "/feasibility", params) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        handle_error(status, body)

      {:error, reason} ->
        handle_network_error(reason)
    end
  end

  @doc """
  Get a price estimate for an archive download or tasking order.

  ## Parameters

  - `params` - Pricing parameters:
    - For archive: `%{archive_id: "img_123"}`
    - For tasking: `%{aoi: ..., sensor_type: "optical", ...}`

  ## Returns

  - `{:ok, pricing}` - Price estimate with breakdown
  - `{:error, reason}` - Error tuple

  ## Examples

      # Archive pricing
      {:ok, price} = SkyfiClient.get_price_estimate(%{
        archive_id: "img_abc123"
      })

      # Tasking pricing
      {:ok, price} = SkyfiClient.get_price_estimate(%{
        aoi: %{type: "Polygon", coordinates: [...]},
        sensor_type: "optical",
        resolution: 0.5
      })
  """
  def get_price_estimate(api_key \\ nil, params)

  def get_price_estimate(params, _) when is_map(params) do
    get_price_estimate(nil, params)
  end

  def get_price_estimate(api_key, params) when is_binary(api_key) or is_nil(api_key) do
    client = client(api_key)

    case post(client, "/pricing", params) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        handle_error(status, body)

      {:error, reason} ->
        handle_network_error(reason)
    end
  end

  @doc """
  Place an order for archive imagery or tasking.

  ## Parameters

  - `params` - Order parameters:
    - For archive: `%{archive_id: "img_123", ...}`
    - For tasking: `%{aoi: ..., sensor_type: "optical", ...}`
    - `:confirm_price` - Required price confirmation (safety)

  ## Returns

  - `{:ok, order}` - Order details with ID and status
  - `{:error, reason}` - Error tuple

  ## Examples

      {:ok, order} = SkyfiClient.place_order(%{
        archive_id: "img_abc123",
        confirm_price: 250.0
      })
  """
  def place_order(api_key \\ nil, params)

  def place_order(params, _) when is_map(params) do
    place_order(nil, params)
  end

  def place_order(api_key, params) when is_binary(api_key) or is_nil(api_key) do
    client = client(api_key)

    # Determine endpoint based on order type
    endpoint =
      cond do
        Map.has_key?(params, :archive_id) -> "/order-archive"
        true -> "/order-tasking"
      end

    case post(client, endpoint, params) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Tesla.Env{status: 201, body: body}} ->
        {:ok, body}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        handle_error(status, body)

      {:error, reason} ->
        handle_network_error(reason)
    end
  end

  @doc """
  List order history with optional filtering.

  ## Parameters

  - `params` - Optional query parameters:
    - `:status` - Filter by status ("pending", "processing", "completed", "failed")
    - `:limit` - Maximum results (default: 10)
    - `:offset` - Pagination offset

  ## Returns

  - `{:ok, orders}` - List of orders
  - `{:error, reason}` - Error tuple

  ## Examples

      {:ok, orders} = SkyfiClient.list_orders()
      {:ok, orders} = SkyfiClient.list_orders(%{status: "pending"})
      {:ok, orders} = SkyfiClient.list_orders(%{limit: 20, offset: 10})
  """
  def list_orders(api_key \\ nil, params \\ %{})

  def list_orders(params, _) when is_map(params) do
    list_orders(nil, params)
  end

  def list_orders(api_key, params) when is_binary(api_key) or is_nil(api_key) do
    client = client(api_key)

    case get(client, "/orders", query: params) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        handle_error(status, body)

      {:error, reason} ->
        handle_network_error(reason)
    end
  end

  @doc """
  Get details for a specific order by ID.

  ## Parameters

  - `order_id` - The order ID

  ## Returns

  - `{:ok, order}` - Order details
  - `{:error, reason}` - Error tuple
  """
  def get_order(api_key \\ nil, order_id)

  def get_order(order_id, _) when is_binary(order_id) do
    get_order(nil, order_id)
  end

  def get_order(api_key, order_id) when is_binary(api_key) or is_nil(api_key) do
    client = client(api_key)

    case get(client, "/orders/#{order_id}") do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        handle_error(status, body)

      {:error, reason} ->
        handle_network_error(reason)
    end
  end

  # Private helpers

  defp get_api_key do
    Application.get_env(:skyfi_mcp, :skyfi_api_key) ||
      System.get_env("SKYFI_API_KEY") ||
      raise """
      SkyFi API key not configured!

      Please set one of:
      1. Application config: config :skyfi_mcp, :skyfi_api_key, "your-key"
      2. Environment variable: SKYFI_API_KEY=your-key
      3. Pass explicitly: SkyfiClient.search_archive("your-key", params)
      """
  end

  defp handle_error(401, _body) do
    Logger.error("SkyFi API: Invalid API key (401)")
    {:error, :invalid_api_key}
  end

  defp handle_error(403, _body) do
    Logger.error("SkyFi API: Access denied (403)")
    {:error, :access_denied}
  end

  defp handle_error(404, _body) do
    Logger.error("SkyFi API: Resource not found (404)")
    {:error, :not_found}
  end

  defp handle_error(429, body) do
    Logger.warning("SkyFi API: Rate limit exceeded (429)")
    {:error, {:rate_limit_exceeded, body}}
  end

  defp handle_error(400, body) do
    Logger.warning("SkyFi API: Bad request (400): #{inspect(body)}")
    {:error, {:bad_request, parse_error_message(body)}}
  end

  defp handle_error(status, body) when status >= 500 do
    Logger.error("SkyFi API: Server error (#{status}): #{inspect(body)}")
    {:error, {:server_error, status}}
  end

  defp handle_error(status, body) do
    Logger.error("SkyFi API: Unexpected status (#{status}): #{inspect(body)}")
    {:error, {:unexpected_status, status, body}}
  end

  defp handle_network_error(:timeout) do
    Logger.error("SkyFi API: Request timeout")
    {:error, :timeout}
  end

  defp handle_network_error(:econnrefused) do
    Logger.error("SkyFi API: Connection refused")
    {:error, :connection_refused}
  end

  defp handle_network_error(reason) do
    Logger.error("SkyFi API: Network error - #{inspect(reason)}")
    {:error, {:network_error, reason}}
  end

  defp parse_error_message(%{"error" => error}) when is_binary(error), do: error
  defp parse_error_message(%{"message" => message}) when is_binary(message), do: message
  defp parse_error_message(%{"errors" => errors}) when is_list(errors), do: Enum.join(errors, ", ")
  defp parse_error_message(body), do: inspect(body)
end
