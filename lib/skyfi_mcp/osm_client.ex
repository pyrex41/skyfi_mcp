defmodule SkyfiMcp.OsmClient do
  @moduledoc """
  HTTP client for OpenStreetMap Nominatim geocoding API.

  Provides geocoding (location name → coordinates) and reverse geocoding
  (coordinates → location name) using the free Nominatim service.

  ## Rate Limiting

  Per Nominatim Usage Policy, this client enforces a 1 request/second rate limit.
  See: https://operations.osmfoundation.org/policies/nominatim/

  ## Caching

  Responses are cached in ETS to avoid redundant API calls for repeated queries.
  Cache entries expire after 24 hours.

  ## Examples

      # Geocode a location
      {:ok, results} = OsmClient.geocode("San Francisco, CA")
      # => [%{lat: "37.7749", lon: "-122.4194", display_name: "San Francisco, ..."}]

      # Reverse geocode coordinates
      {:ok, result} = OsmClient.reverse_geocode(37.7749, -122.4194)
      # => %{display_name: "San Francisco, California, United States", address: %{...}}
  """

  require Logger

  @base_url "https://nominatim.openstreetmap.org"
  @user_agent "SkyFiMCP/0.1.0 (Elixir Phoenix MCP Server)"
  @cache_table :osm_cache
  @cache_ttl_seconds 86_400  # 24 hours

  @doc """
  Geocodes a location name to geographic coordinates.

  ## Parameters

    * `query` - Location name as string (e.g., "San Francisco, CA")
    * `opts` - Optional parameters:
      * `:limit` - Maximum number of results (default: 5, max: 50)
      * `:countrycodes` - Limit to specific countries (ISO 3166-1alpha2, e.g., "us,ca")
      * `:viewbox` - Prefer results in bounding box [min_lon, min_lat, max_lon, max_lat]

  ## Returns

    * `{:ok, results}` - List of location matches with coordinates
    * `{:error, reason}` - Error atom or tuple

  ## Examples

      {:ok, results} = OsmClient.geocode("Paris")
      {:ok, results} = OsmClient.geocode("New York", limit: 1)
      {:ok, results} = OsmClient.geocode("London", countrycodes: "gb")
  """
  def geocode(query, opts \\ []) when is_binary(query) do
    cache_key = {:geocode, query, opts}

    case get_cached(cache_key) do
      {:ok, cached_result} ->
        Logger.debug("OSM geocode cache hit: #{query}")
        {:ok, cached_result}

      :miss ->
        with :ok <- rate_limit_check(),
             {:ok, results} <- do_geocode(query, opts) do
          cache_result(cache_key, results)
          {:ok, results}
        end
    end
  end

  @doc """
  Reverse geocodes coordinates to a location name and address.

  ## Parameters

    * `lat` - Latitude as float
    * `lon` - Longitude as float
    * `opts` - Optional parameters:
      * `:zoom` - Level of detail (3=country, 10=city, 18=building, default: 18)

  ## Returns

    * `{:ok, result}` - Location information with display_name and address
    * `{:error, reason}` - Error atom or tuple

  ## Examples

      {:ok, result} = OsmClient.reverse_geocode(37.7749, -122.4194)
      {:ok, result} = OsmClient.reverse_geocode(48.8566, 2.3522, zoom: 10)
  """
  def reverse_geocode(lat, lon, opts \\ [])
      when is_number(lat) and is_number(lon) do
    cache_key = {:reverse_geocode, lat, lon, opts}

    case get_cached(cache_key) do
      {:ok, cached_result} ->
        Logger.debug("OSM reverse_geocode cache hit: #{lat}, #{lon}")
        {:ok, cached_result}

      :miss ->
        with :ok <- rate_limit_check(),
             {:ok, result} <- do_reverse_geocode(lat, lon, opts) do
          cache_result(cache_key, result)
          {:ok, result}
        end
    end
  end

  # Private Functions

  defp do_geocode(query, opts) do
    params =
      [
        q: query,
        format: "json",
        limit: Keyword.get(opts, :limit, 5)
      ]
      |> maybe_add_param(:countrycodes, opts)
      |> maybe_add_param(:viewbox, opts)

    case get("/search", params) do
      {:ok, []} ->
        Logger.info("OSM geocode: No results for '#{query}'")
        {:ok, []}

      {:ok, results} when is_list(results) ->
        Logger.info("OSM geocode: Found #{length(results)} results for '#{query}'")
        {:ok, parse_geocode_results(results)}

      {:error, reason} = error ->
        Logger.warning("OSM geocode failed for '#{query}': #{inspect(reason)}")
        error
    end
  end

  defp do_reverse_geocode(lat, lon, opts) do
    params = [
      lat: lat,
      lon: lon,
      format: "json",
      zoom: Keyword.get(opts, :zoom, 18)
    ]

    case get("/reverse", params) do
      {:ok, %{"error" => error_msg}} ->
        Logger.warning("OSM reverse_geocode error: #{error_msg}")
        {:error, {:not_found, error_msg}}

      {:ok, result} when is_map(result) ->
        Logger.info("OSM reverse_geocode: Found location for #{lat}, #{lon}")
        {:ok, parse_reverse_result(result)}

      {:error, reason} = error ->
        Logger.warning("OSM reverse_geocode failed for #{lat}, #{lon}: #{inspect(reason)}")
        error
    end
  end

  defp get(path, params) do
    url = @base_url <> path

    case Tesla.get(client(), url, query: params) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Tesla.Env{status: 429}} ->
        {:error, :rate_limit_exceeded}

      {:ok, %Tesla.Env{status: 403}} ->
        {:error, :forbidden}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        Logger.warning("OSM API error: #{status} - #{inspect(body)}")
        {:error, {:http_error, status}}

      {:error, %Tesla.Error{reason: :timeout}} ->
        {:error, :timeout}

      {:error, %Tesla.Error{reason: :econnrefused}} ->
        {:error, :connection_refused}

      {:error, reason} ->
        {:error, {:network_error, reason}}
    end
  end

  defp client do
    middleware = [
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers, [{"user-agent", @user_agent}]},
      {Tesla.Middleware.Timeout, timeout: 10_000}
    ]

    Tesla.client(middleware)
  end

  defp parse_geocode_results(results) do
    Enum.map(results, fn result ->
      %{
        lat: safe_to_float(result["lat"]),
        lon: safe_to_float(result["lon"]),
        display_name: result["display_name"],
        type: result["type"],
        importance: result["importance"],
        bbox: parse_bbox(result["boundingbox"])
      }
    end)
  end

  defp parse_reverse_result(result) do
    %{
      lat: safe_to_float(result["lat"]),
      lon: safe_to_float(result["lon"]),
      display_name: result["display_name"],
      address: result["address"] || %{},
      type: result["type"]
    }
  end

  defp safe_to_float(str) when is_binary(str) do
    case Float.parse(str) do
      {num, _} -> num
      :error -> 0.0
    end
  end

  defp safe_to_float(num) when is_number(num), do: num * 1.0

  defp parse_bbox(nil), do: nil

  defp parse_bbox([min_lat, max_lat, min_lon, max_lon]) do
    [
      safe_to_float(min_lon),
      safe_to_float(min_lat),
      safe_to_float(max_lon),
      safe_to_float(max_lat)
    ]
  end

  defp maybe_add_param(params, key, opts) do
    case Keyword.get(opts, key) do
      nil -> params
      value -> Keyword.put(params, key, value)
    end
  end

  # Rate Limiting

  defp rate_limit_check do
    case :ets.whereis(@cache_table) do
      :undefined ->
        init_cache()
        rate_limit_check()

      _table ->
        now = System.monotonic_time(:millisecond)
        last_request_key = :last_request_time

        case :ets.lookup(@cache_table, last_request_key) do
          [{^last_request_key, last_time, _ttl}] ->
            time_since_last = now - last_time

            if time_since_last >= 1000 do
              # At least 1 second has passed
              :ets.insert(@cache_table, {last_request_key, now, :infinity})
              :ok
            else
              # Need to wait
              wait_time = 1000 - time_since_last
              Logger.debug("OSM rate limit: waiting #{wait_time}ms")
              Process.sleep(wait_time)
              :ets.insert(@cache_table, {last_request_key, now + wait_time, :infinity})
              :ok
            end

          [] ->
            :ets.insert(@cache_table, {last_request_key, now, :infinity})
            :ok
        end
    end
  end

  # Caching

  defp init_cache do
    :ets.new(@cache_table, [:named_table, :public, :set])
  end

  defp get_cached(key) do
    case :ets.whereis(@cache_table) do
      :undefined ->
        init_cache()
        :miss

      _table ->
        case :ets.lookup(@cache_table, key) do
          [{^key, value, ttl}] ->
            if System.monotonic_time(:second) < ttl do
              {:ok, value}
            else
              :ets.delete(@cache_table, key)
              :miss
            end

          [] ->
            :miss
        end
    end
  end

  defp cache_result(key, value) do
    ttl = System.monotonic_time(:second) + @cache_ttl_seconds
    :ets.insert(@cache_table, {key, value, ttl})
    :ok
  end
end
