defmodule SkyfiMcp.Tools.SearchArchive do
  @moduledoc """
  Implements the search_archive MCP tool.
  """

  alias SkyfiMcp.SkyfiClient
  alias SkyfiMcp.AoiConverter

  @doc """
  Executes the search_archive tool.

  Expected params:
  - `aoi`: WKT POLYGON string, bounding box as JSON string, or GeoJSON Polygon as JSON string
  - `start_date`: ISO8601 string (e.g., "2023-01-01T00:00:00Z")
  - `end_date`: ISO8601 string
  - `cloud_cover_max`: Integer 0-100 (optional, default 100)

  Options:
  - `skyfi_api_key`: SkyFi API key to use for this request (overrides config)
  """
  def execute(params, opts \\ []) do
    api_key = Keyword.get(opts, :skyfi_api_key)

    # Debug logging
    require Logger
    key_preview = if api_key && String.length(api_key) >= 6 do
      "#{String.slice(api_key, 0, 3)}...#{String.slice(api_key, -3, 3)}"
    else
      "<none or too short>"
    end
    Logger.info("SearchArchive: Using API key: #{key_preview}")

    with {:ok, validated_params} <- validate_and_convert_params(params),
         {:ok, body} <- SkyfiClient.search_archive(api_key, validated_params) do
      format_response(body)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_and_convert_params(params) do
    aoi = Map.get(params, "aoi")
    start_date = Map.get(params, "start_date")
    end_date = Map.get(params, "end_date")

    cond do
      is_nil(aoi) ->
        {:error, "Missing required parameter: aoi"}

      is_nil(start_date) ->
        {:error, "Missing required parameter: start_date"}

      is_nil(end_date) ->
        {:error, "Missing required parameter: end_date"}

      true ->
        # Convert AOI to WKT format
        aoi_input = parse_aoi_input(aoi)

        case AoiConverter.to_wkt(aoi_input) do
          {:ok, wkt_aoi} ->
            # Replace aoi with WKT version
            updated_params = Map.put(params, "aoi", wkt_aoi)
            {:ok, updated_params}

          {:error, reason} ->
            {:error, "Invalid AOI: #{reason}"}
        end
    end
  end

  # Parse AOI input - it might be a JSON string or already parsed
  defp parse_aoi_input(aoi) when is_binary(aoi) do
    # Try to parse as JSON first
    case Jason.decode(aoi) do
      {:ok, parsed} -> parsed
      {:error, _} -> aoi  # Already a WKT string
    end
  end

  defp parse_aoi_input(aoi), do: aoi

  defp format_response(body) when is_map(body) do
    # SkyFi API response structure (assumed based on task description)
    # We need to transform it into a list of clean image objects
    images = Map.get(body, "data", []) || []

    formatted_images = Enum.map(images, fn img ->
      %{
        id: img["id"],
        timestamp: img["capture_date"],
        cloud_cover: img["cloud_cover"],
        thumbnail_url: img["thumbnail_url"],
        preview_url: img["preview_url"],
        resolution: img["resolution"],
        sensor: img["sensor_type"]
      }
    end)

    {:ok, formatted_images}
  end
end
