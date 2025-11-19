defmodule SkyfiMcp.Tools.Geocode do
  @moduledoc """
  MCP tool for geocoding location names to geographic coordinates.

  Converts natural language location queries (e.g., "San Francisco, CA",
  "Eiffel Tower, Paris") into geographic coordinates (latitude, longitude).

  Uses OpenStreetMap's Nominatim service with built-in rate limiting
  and caching to comply with usage policies.

  ## Examples

      # Geocode a city
      Geocode.execute(%{"query" => "San Francisco, CA"})
      # => {:ok, [%{lat: 37.7749, lon: -122.4194, display_name: "..."}]}

      # Geocode with country filter
      Geocode.execute(%{"query" => "Paris", "country_codes" => "fr"})

      # Limit results
      Geocode.execute(%{"query" => "Springfield", "limit" => 3})
  """

  alias SkyfiMcp.OsmClient
  require Logger

  @doc """
  Executes the geocode tool with the given parameters.

  ## Parameters

    * `query` (required) - Location name or address to geocode
    * `limit` (optional) - Maximum number of results (1-50, default: 5)
    * `country_codes` (optional) - Comma-separated ISO country codes (e.g., "us,ca,gb")
    * `viewbox` (optional) - Prefer results in bounding box [min_lon, min_lat, max_lon, max_lat]

  ## Returns

    * `{:ok, results}` - List of geocoded locations
    * `{:error, reason}` - Error message

  ## Result Format

  Each result contains:
    * `lat` - Latitude as float
    * `lon` - Longitude as float
    * `display_name` - Full address/location name
    * `type` - Location type (city, town, village, etc.)
    * `importance` - Relevance score (0.0 to 1.0)
    * `bbox` - Bounding box [min_lon, min_lat, max_lon, max_lat]
  """
  def execute(params) when is_map(params) do
    with {:ok, validated} <- validate_params(params),
         {:ok, results} <- geocode(validated) do
      {:ok, format_response(results)}
    end
  end

  # Validation

  defp validate_params(params) do
    with {:ok, query} <- validate_query(params),
         {:ok, limit} <- validate_limit(params),
         {:ok, opts} <- build_options(params, limit) do
      {:ok, {query, opts}}
    end
  end

  defp validate_query(%{"query" => query}) when is_binary(query) and byte_size(query) > 0 do
    {:ok, String.trim(query)}
  end

  defp validate_query(%{"query" => _}) do
    {:error, "query must be a non-empty string"}
  end

  defp validate_query(_) do
    {:error, "query parameter is required"}
  end

  defp validate_limit(%{"limit" => limit}) when is_integer(limit) do
    cond do
      limit < 1 -> {:error, "limit must be at least 1"}
      limit > 50 -> {:error, "limit cannot exceed 50"}
      true -> {:ok, limit}
    end
  end

  defp validate_limit(%{"limit" => limit}) when is_binary(limit) do
    case Integer.parse(limit) do
      {num, ""} -> validate_limit(%{"limit" => num})
      _ -> {:error, "limit must be an integer"}
    end
  end

  defp validate_limit(%{"limit" => limit}) when is_float(limit) do
    validate_limit(%{"limit" => trunc(limit)})
  end

  defp validate_limit(_), do: {:ok, 5}  # default

  defp build_options(params, limit) do
    opts = [limit: limit]

    opts =
      case Map.get(params, "country_codes") do
        nil -> opts
        "" -> opts
        codes when is_binary(codes) -> Keyword.put(opts, :countrycodes, codes)
        _ -> opts
      end

    opts =
      case Map.get(params, "viewbox") do
        [_, _, _, _] = bbox when is_list(bbox) -> Keyword.put(opts, :viewbox, bbox)
        _ -> opts
      end

    {:ok, opts}
  end

  # Geocoding

  defp geocode({query, opts}) do
    Logger.info("Geocoding query: '#{query}' with opts: #{inspect(opts)}")

    case OsmClient.geocode(query, opts) do
      {:ok, []} ->
        Logger.info("No results found for: '#{query}'")
        {:ok, []}

      {:ok, results} ->
        Logger.info("Found #{length(results)} results for: '#{query}'")
        {:ok, results}

      {:error, :rate_limit_exceeded} ->
        {:error,
         "Rate limit exceeded for OpenStreetMap Nominatim (1 request/second). Please try again in a moment."}

      {:error, :timeout} ->
        {:error,
         "Geocoding request timed out after 10 seconds. The OpenStreetMap service may be slow or unreachable."}

      {:error, :connection_refused} ->
        {:error,
         "Unable to connect to OpenStreetMap geocoding service. Please check your internet connection or try again later."}

      {:error, :forbidden} ->
        {:error,
         "Access forbidden by OpenStreetMap. This may indicate a User-Agent issue or policy violation."}

      {:error, {:http_error, status}} ->
        {:error, "OpenStreetMap API returned HTTP #{status}. The service may be experiencing issues."}

      {:error, {:network_error, reason}} ->
        Logger.warning("Geocoding network error: #{inspect(reason)}")
        {:error, "Network error while connecting to geocoding service: #{format_network_error(reason)}"}

      {:error, reason} ->
        Logger.warning("Geocoding failed: #{inspect(reason)}")
        {:error, "Geocoding service error: #{format_error_reason(reason)}"}
    end
  end

  # Response Formatting

  defp format_response(results) do
    %{
      results: results,
      count: length(results),
      service: "OpenStreetMap Nominatim"
    }
  end

  # Error Formatting

  defp format_network_error(%Tesla.Error{reason: reason}), do: format_network_error(reason)
  defp format_network_error(:econnrefused), do: "Connection refused"
  defp format_network_error(:nxdomain), do: "DNS lookup failed"
  defp format_network_error(:closed), do: "Connection closed unexpectedly"
  defp format_network_error(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_network_error(reason), do: inspect(reason)

  defp format_error_reason({:not_found, msg}), do: "Location not found: #{msg}"
  defp format_error_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_error_reason(reason) when is_binary(reason), do: reason
  defp format_error_reason(reason), do: inspect(reason)
end
