defmodule SkyfiMcp.Tools.CheckFeasibility do
  @moduledoc """
  Implements the check_feasibility MCP tool.

  Checks the feasibility of satellite tasking for a given area of interest (AOI),
  date range, and sensor type. Returns success probability and available pass times.
  """

  alias SkyfiMcp.SkyfiClient

  @valid_sensors ["optical", "sar"]

  @doc """
  Executes the check_feasibility tool.

  Expected params:
  - `aoi`: GeoJSON Polygon or BBox [min_lon, min_lat, max_lon, max_lat]
  - `start_date`: ISO8601 string (e.g., "2023-01-01T00:00:00Z")
  - `end_date`: ISO8601 string
  - `sensor_type`: String - "optical" or "sar" (optional, default: "optical")
  - `resolution`: Float - desired resolution in meters (optional)
  """
  def execute(params) do
    with {:ok, validated_params} <- validate_params(params),
         {:ok, response} <- SkyfiClient.check_feasibility(validated_params) do
      format_response(response)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_params(params) do
    aoi = Map.get(params, "aoi")
    start_date = Map.get(params, "start_date")
    end_date = Map.get(params, "end_date")
    sensor_type = Map.get(params, "sensor_type", "optical")

    cond do
      is_nil(aoi) ->
        {:error, "Missing required parameter: aoi"}

      is_nil(start_date) ->
        {:error, "Missing required parameter: start_date"}

      is_nil(end_date) ->
        {:error, "Missing required parameter: end_date"}

      sensor_type not in @valid_sensors ->
        {:error, "Invalid sensor_type. Must be one of: #{Enum.join(@valid_sensors, ", ")}"}

      true ->
        {:ok, params}
    end
  end

  defp format_response(body) when is_map(body) do
    # Format the API response into a clean structure
    formatted = %{
      success_probability: Map.get(body, "success_probability", 0.0),
      pass_times: Map.get(body, "pass_times", []),
      constraints: Map.get(body, "constraints", []),
      sensor_info: %{
        type: Map.get(body, "sensor_type"),
        resolution: Map.get(body, "resolution"),
        weather_dependent: Map.get(body, "weather_dependent", true)
      },
      estimated_delivery: Map.get(body, "estimated_delivery")
    }

    {:ok, formatted}
  end
end
