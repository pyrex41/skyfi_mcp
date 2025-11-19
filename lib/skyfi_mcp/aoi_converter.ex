defmodule SkyfiMcp.AoiConverter do
  @moduledoc """
  Converts various AOI (Area of Interest) formats to WKT (Well-Known Text) format
  required by the SkyFi API.

  Supports:
  - WKT strings (passed through)
  - Bounding boxes as [min_lon, min_lat, max_lon, max_lat]
  - GeoJSON Polygon objects
  """

  @doc """
  Converts an AOI in various formats to WKT POLYGON format.

  ## Examples

      # WKT string (passed through)
      iex> AoiConverter.to_wkt("POLYGON((-122.5 37.7, -122.3 37.7, -122.3 37.9, -122.5 37.9, -122.5 37.7))")
      {:ok, "POLYGON((-122.5 37.7, -122.3 37.7, -122.3 37.9, -122.5 37.9, -122.5 37.7))"}

      # Bounding box array
      iex> AoiConverter.to_wkt([-122.5, 37.7, -122.3, 37.9])
      {:ok, "POLYGON((-122.5 37.7, -122.3 37.7, -122.3 37.9, -122.5 37.9, -122.5 37.7))"}

      # GeoJSON Polygon
      iex> AoiConverter.to_wkt(%{"type" => "Polygon", "coordinates" => [[[-122.5, 37.7], [-122.3, 37.7], [-122.3, 37.9], [-122.5, 37.9], [-122.5, 37.7]]]})
      {:ok, "POLYGON((-122.5 37.7, -122.3 37.7, -122.3 37.9, -122.5 37.9, -122.5 37.7))"}
  """
  def to_wkt(aoi) when is_binary(aoi) do
    # Already a string, assume it's WKT format
    # Basic validation: should start with POLYGON
    if String.upcase(aoi) =~ ~r/^POLYGON/i do
      {:ok, aoi}
    else
      {:error, "Invalid WKT format: must start with POLYGON"}
    end
  end

  def to_wkt(aoi) when is_list(aoi) and length(aoi) == 4 do
    # Bounding box: [min_lon, min_lat, max_lon, max_lat]
    [min_lon, min_lat, max_lon, max_lat] = aoi

    # Validate coordinates
    cond do
      not is_number(min_lon) or not is_number(min_lat) or not is_number(max_lon) or not is_number(max_lat) ->
        {:error, "Bounding box coordinates must be numbers"}

      min_lon < -180 or min_lon > 180 or max_lon < -180 or max_lon > 180 ->
        {:error, "Longitude must be between -180 and 180"}

      min_lat < -90 or min_lat > 90 or max_lat < -90 or max_lat > 90 ->
        {:error, "Latitude must be between -90 and 90"}

      min_lon >= max_lon ->
        {:error, "min_lon must be less than max_lon"}

      min_lat >= max_lat ->
        {:error, "min_lat must be less than max_lat"}

      true ->
        # Convert to WKT POLYGON
        # Format: POLYGON((lon1 lat1, lon2 lat2, lon3 lat3, lon4 lat4, lon1 lat1))
        # Note: First and last coordinate must be the same to close the polygon
        wkt = "POLYGON((#{min_lon} #{min_lat}, #{max_lon} #{min_lat}, #{max_lon} #{max_lat}, #{min_lon} #{max_lat}, #{min_lon} #{min_lat}))"
        {:ok, wkt}
    end
  end

  def to_wkt(%{"type" => "Polygon", "coordinates" => coordinates}) when is_list(coordinates) do
    # GeoJSON Polygon format
    convert_geojson_polygon(coordinates)
  end

  def to_wkt(%{"type" => "MultiPolygon", "coordinates" => _coordinates}) do
    {:error, "MultiPolygon not supported, please use a single Polygon"}
  end

  def to_wkt(_invalid) do
    {:error, "Invalid AOI format. Expected: WKT string, bounding box array [min_lon, min_lat, max_lon, max_lat], or GeoJSON Polygon"}
  end

  defp convert_geojson_polygon([ring | _rest]) when is_list(ring) do
    # GeoJSON uses the first ring (outer ring)
    # Format: [[[lon1, lat1], [lon2, lat2], ...]]
    # Convert to WKT: POLYGON((lon1 lat1, lon2 lat2, ...))

    coordinates_str =
      ring
      |> Enum.map(fn
        [lon, lat] when is_number(lon) and is_number(lat) ->
          "#{lon} #{lat}"

        _ ->
          nil
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.join(", ")

    if coordinates_str == "" do
      {:error, "Invalid GeoJSON coordinates"}
    else
      wkt = "POLYGON((#{coordinates_str}))"
      {:ok, wkt}
    end
  end

  defp convert_geojson_polygon(_invalid) do
    {:error, "Invalid GeoJSON Polygon coordinates"}
  end
end
