defmodule SkyfiMcp.Tools.ReverseGeocode do
  @moduledoc """
  MCP tool for reverse geocoding coordinates to location names.

  Converts geographic coordinates (latitude, longitude) into human-readable
  location names and addresses.

  Uses OpenStreetMap's Nominatim service with built-in rate limiting
  and caching to comply with usage policies.

  ## Examples

      # Reverse geocode coordinates
      ReverseGeocode.execute(%{"lat" => 37.7749, "lon" => -122.4194})
      # => {:ok, %{display_name: "San Francisco, California, United States", ...}}

      # Get country-level location
      ReverseGeocode.execute(%{"lat" => 48.8566, "lon" => 2.3522, "zoom" => 3})
  """

  alias SkyfiMcp.OsmClient
  require Logger

  @doc """
  Executes the reverse_geocode tool with the given parameters.

  ## Parameters

    * `lat` (required) - Latitude as float (-90 to 90)
    * `lon` (required) - Longitude as float (-180 to 180)
    * `zoom` (optional) - Detail level:
      * 3 = country
      * 5 = state
      * 8 = county
      * 10 = city
      * 14 = suburb
      * 16 = major streets
      * 18 = building (default)

  ## Returns

    * `{:ok, result}` - Location information
    * `{:error, reason}` - Error message

  ## Result Format

  The result contains:
    * `lat` - Latitude (float)
    * `lon` - Longitude (float)
    * `display_name` - Full formatted address
    * `address` - Structured address components (house_number, road, city, etc.)
    * `type` - Location type (house, building, road, etc.)
  """
  def execute(params) when is_map(params) do
    with {:ok, validated} <- validate_params(params),
         {:ok, result} <- reverse_geocode(validated) do
      {:ok, format_response(result)}
    end
  end

  # Validation

  defp validate_params(params) do
    with {:ok, lat} <- validate_latitude(params),
         {:ok, lon} <- validate_longitude(params),
         {:ok, zoom} <- validate_zoom(params) do
      {:ok, {lat, lon, [zoom: zoom]}}
    end
  end

  defp validate_latitude(%{"lat" => lat}) when is_number(lat) do
    cond do
      lat < -90 -> {:error, "latitude must be >= -90"}
      lat > 90 -> {:error, "latitude must be <= 90"}
      true -> {:ok, lat}
    end
  end

  defp validate_latitude(%{"lat" => lat}) when is_binary(lat) do
    case Float.parse(lat) do
      {num, ""} -> validate_latitude(%{"lat" => num})
      _ -> {:error, "latitude must be a number"}
    end
  end

  defp validate_latitude(%{"lat" => _}) do
    {:error, "latitude must be a number between -90 and 90"}
  end

  defp validate_latitude(_) do
    {:error, "lat parameter is required"}
  end

  defp validate_longitude(%{"lon" => lon}) when is_number(lon) do
    cond do
      lon < -180 -> {:error, "longitude must be >= -180"}
      lon > 180 -> {:error, "longitude must be <= 180"}
      true -> {:ok, lon}
    end
  end

  defp validate_longitude(%{"lon" => lon}) when is_binary(lon) do
    case Float.parse(lon) do
      {num, ""} -> validate_longitude(%{"lon" => num})
      _ -> {:error, "longitude must be a number"}
    end
  end

  defp validate_longitude(%{"lon" => _}) do
    {:error, "longitude must be a number between -180 and 180"}
  end

  defp validate_longitude(_) do
    {:error, "lon parameter is required"}
  end

  defp validate_zoom(%{"zoom" => zoom}) when is_integer(zoom) do
    cond do
      zoom < 0 -> {:error, "zoom must be >= 0"}
      zoom > 18 -> {:error, "zoom must be <= 18"}
      true -> {:ok, zoom}
    end
  end

  defp validate_zoom(%{"zoom" => zoom}) when is_binary(zoom) do
    case Integer.parse(zoom) do
      {num, ""} -> validate_zoom(%{"zoom" => num})
      _ -> {:error, "zoom must be an integer"}
    end
  end

  defp validate_zoom(%{"zoom" => zoom}) when is_float(zoom) do
    validate_zoom(%{"zoom" => trunc(zoom)})
  end

  defp validate_zoom(_), do: {:ok, 18}  # default to building level

  # Reverse Geocoding

  defp reverse_geocode({lat, lon, opts}) do
    Logger.info("Reverse geocoding coordinates: #{lat}, #{lon} with opts: #{inspect(opts)}")

    case OsmClient.reverse_geocode(lat, lon, opts) do
      {:ok, result} ->
        Logger.info("Found location: #{result.display_name}")
        {:ok, result}

      {:error, {:not_found, msg}} ->
        Logger.info("No location found for #{lat}, #{lon}: #{msg}")
        {:error, "No location found at coordinates (#{lat}, #{lon}). This area may be in open water or remote terrain."}

      {:error, :rate_limit_exceeded} ->
        {:error,
         "Rate limit exceeded for OpenStreetMap Nominatim (1 request/second). Please try again in a moment."}

      {:error, :timeout} ->
        {:error,
         "Reverse geocoding request timed out after 10 seconds. The OpenStreetMap service may be slow or unreachable."}

      {:error, :connection_refused} ->
        {:error,
         "Unable to connect to OpenStreetMap geocoding service. Please check your internet connection or try again later."}

      {:error, :forbidden} ->
        {:error,
         "Access forbidden by OpenStreetMap. This may indicate a User-Agent issue or policy violation."}

      {:error, {:http_error, status}} ->
        {:error, "OpenStreetMap API returned HTTP #{status}. The service may be experiencing issues."}

      {:error, {:network_error, reason}} ->
        Logger.warning("Reverse geocoding network error: #{inspect(reason)}")
        {:error, "Network error while connecting to geocoding service: #{format_network_error(reason)}"}

      {:error, reason} ->
        Logger.warning("Reverse geocoding failed: #{inspect(reason)}")
        {:error, "Geocoding service error: #{format_error_reason(reason)}"}
    end
  end

  # Response Formatting

  defp format_response(result) do
    %{
      location: %{
        lat: result.lat,
        lon: result.lon,
        display_name: result.display_name,
        type: result.type
      },
      address: result.address,
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
