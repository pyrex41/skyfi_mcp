defmodule SkyfiMcp.Tools.SearchArchive do
  @moduledoc """
  Implements the search_archive MCP tool.
  """

  alias SkyfiMcp.SkyfiClient

  @doc """
  Executes the search_archive tool.

  Expected params:
  - `aoi`: GeoJSON Polygon or BBox [min_lon, min_lat, max_lon, max_lat]
  - `start_date`: ISO8601 string (e.g., "2023-01-01T00:00:00Z")
  - `end_date`: ISO8601 string
  - `cloud_cover_max`: Integer 0-100 (optional, default 100)
  """
  def execute(params) do
    with {:ok, validated_params} <- validate_params(params),
         {:ok, response} <- SkyfiClient.search_archive(validated_params) do
      format_response(response)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_params(params) do
    # Basic validation - in a real app, use Ecto schemaless changesets or ExJsonSchema
    aoi = Map.get(params, "aoi")
    start_date = Map.get(params, "start_date")
    end_date = Map.get(params, "end_date")

    cond do
      is_nil(aoi) -> {:error, "Missing required parameter: aoi"}
      is_nil(start_date) -> {:error, "Missing required parameter: start_date"}
      is_nil(end_date) -> {:error, "Missing required parameter: end_date"}
      true -> {:ok, params}
    end
  end

  defp format_response(%Tesla.Env{status: 200, body: body}) do
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

  defp format_response(%Tesla.Env{status: status}) do
    {:error, "SkyFi API error: #{status}"}
  end
end
