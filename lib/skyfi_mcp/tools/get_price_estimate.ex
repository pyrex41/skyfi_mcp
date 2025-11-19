defmodule SkyfiMcp.Tools.GetPriceEstimate do
  @moduledoc """
  Implements the get_price_estimate MCP tool.

  Gets pricing estimates for either archive imagery or tasking orders.
  Supports two modes:
  1. Archive mode: Provide image_id to get pricing for existing imagery
  2. Tasking mode: Provide tasking parameters (aoi, sensor, resolution, etc.)
  """

  alias SkyfiMcp.SkyfiClient
  alias SkyfiMcp.AoiConverter

  @doc """
  Executes the get_price_estimate tool.

  Archive mode params:
  - `image_id`: String - ID of archive image

  Tasking mode params:
  - `aoi`: WKT POLYGON string, bounding box as JSON string, or GeoJSON Polygon as JSON string
  - `sensor_type`: String - "optical" or "sar"
  - `resolution`: Float - desired resolution in meters (optional)
  - `start_date`: ISO8601 string (optional for tasking)
  - `end_date`: ISO8601 string (optional for tasking)
  - `priority`: String - "standard", "priority", or "urgent" (optional)

  Options:
  - `skyfi_api_key`: SkyFi API key to use for this request (overrides config)
  """
  def execute(params, opts \\ []) do
    api_key = Keyword.get(opts, :skyfi_api_key)

    with {:ok, validated_params} <- validate_and_convert_params(params),
         {:ok, response} <- SkyfiClient.get_price_estimate(api_key, validated_params) do
      format_response(response)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_and_convert_params(params) do
    cond do
      # Archive mode
      Map.has_key?(params, "image_id") ->
        validate_archive_params(params)

      # Tasking mode
      Map.has_key?(params, "aoi") ->
        validate_and_convert_tasking_params(params)

      true ->
        {:error, "Must provide either 'image_id' (archive) or 'aoi' (tasking)"}
    end
  end

  defp validate_archive_params(params) do
    image_id = Map.get(params, "image_id")

    if is_nil(image_id) or image_id == "" do
      {:error, "Invalid image_id"}
    else
      {:ok, params}
    end
  end

  defp validate_and_convert_tasking_params(params) do
    aoi = Map.get(params, "aoi")
    sensor_type = Map.get(params, "sensor_type")

    cond do
      is_nil(aoi) ->
        {:error, "Missing required parameter: aoi"}

      is_nil(sensor_type) ->
        {:error, "Missing required parameter: sensor_type"}

      sensor_type not in ["optical", "sar"] ->
        {:error, "Invalid sensor_type. Must be 'optical' or 'sar'"}

      true ->
        # Convert AOI to WKT format
        aoi_input = parse_aoi_input(aoi)

        case AoiConverter.to_wkt(aoi_input) do
          {:ok, wkt_aoi} ->
            updated_params = Map.put(params, "aoi", wkt_aoi)
            {:ok, updated_params}

          {:error, reason} ->
            {:error, "Invalid AOI: #{reason}"}
        end
    end
  end

  # Parse AOI input - it might be a JSON string or already parsed
  defp parse_aoi_input(aoi) when is_binary(aoi) do
    case Jason.decode(aoi) do
      {:ok, parsed} -> parsed
      {:error, _} -> aoi  # Already a WKT string
    end
  end

  defp parse_aoi_input(aoi), do: aoi

  defp format_response(body) when is_map(body) do
    # Format the API response into a clean structure
    formatted = %{
      total_cost: Map.get(body, "total_cost") || Map.get(body, "price"),
      currency: Map.get(body, "currency", "USD"),
      breakdown: %{
        base_price: Map.get(body, "base_price"),
        area_cost: Map.get(body, "area_cost"),
        priority_fee: Map.get(body, "priority_fee", 0),
        resolution_fee: Map.get(body, "resolution_fee", 0)
      },
      order_type: Map.get(body, "order_type"),
      estimated_delivery: Map.get(body, "estimated_delivery")
    }

    {:ok, formatted}
  end
end
