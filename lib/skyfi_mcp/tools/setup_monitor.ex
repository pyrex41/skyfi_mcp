defmodule SkyfiMcp.Tools.SetupMonitor do
  @moduledoc """
  Tool for setting up monitoring of an area of interest (AOI).

  Creates a monitor that will periodically check for new satellite imagery
  matching the specified criteria and send webhook notifications when found.
  """

  require Logger
  alias SkyfiMcp.Monitoring
  alias SkyfiMcp.AoiConverter

  @doc """
  Executes the setup_monitor tool.

  ## Parameters

    - `aoi` - Area of interest as WKT POLYGON string, bounding box as JSON string, or GeoJSON Polygon as JSON string
    - `webhook_url` - HTTPS URL to receive notifications (required)
    - `cloud_cover_max` - Maximum cloud cover percentage (0-100, default: 100)
    - `sensor_types` - Array of sensor types to monitor (default: ["optical"])
    - `resolution_min` - Minimum resolution in meters (optional)
    - `check_interval` - Check interval in seconds (default: 86400 = daily, minimum: 3600 = hourly)

  ## Options

    - `skyfi_api_key`: SkyFi API key to use for this request (overrides config)

  ## Returns

    - `{:ok, result}` - Monitor created successfully
    - `{:error, reason}` - Validation or creation failed
  """
  def execute(params, opts \\ []) do
    # Inject the API key from opts into params
    api_key = Keyword.get(opts, :skyfi_api_key)
    params_with_key = if api_key, do: Map.put(params, "api_key", api_key), else: params

    with {:ok, validated_params} <- validate_params(params_with_key),
         {:ok, params_with_converted_aoi} <- convert_aoi(validated_params),
         {:ok, normalized_params} <- normalize_params(params_with_converted_aoi),
         {:ok, monitor} <- Monitoring.create_monitor(normalized_params) do
      format_response(monitor)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, format_validation_errors(changeset)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp convert_aoi(params) do
    aoi = Map.get(params, "aoi")
    aoi_input = parse_aoi_input(aoi)

    # Convert to WKT first (for API compatibility), then back to GeoJSON for storage
    case AoiConverter.to_wkt(aoi_input) do
      {:ok, _wkt_aoi} ->
        # Now convert to GeoJSON format for internal storage
        geojson_aoi = normalize_aoi(aoi_input)
        {:ok, Map.put(params, "aoi", geojson_aoi)}

      {:error, reason} ->
        {:error, "Invalid AOI: #{reason}"}
    end
  end

  # Parse AOI input - it might be a JSON string or already parsed
  defp parse_aoi_input(aoi) when is_binary(aoi) do
    case Jason.decode(aoi) do
      {:ok, parsed} -> parsed
      {:error, _} -> aoi  # Already a WKT string (which we'll need to convert)
    end
  end

  defp parse_aoi_input(aoi), do: aoi

  defp validate_params(params) do
    required = ["aoi", "webhook_url"]
    missing = Enum.filter(required, &(not Map.has_key?(params, &1)))

    if Enum.empty?(missing) do
      # Validate check_interval if provided
      if interval = params["check_interval"] do
        if is_integer(interval) and interval >= 3600 do
          {:ok, params}
        else
          {:error, "check_interval must be at least 3600 seconds (1 hour)"}
        end
      else
        {:ok, params}
      end
    else
      {:error, "Missing required parameters: #{Enum.join(missing, ", ")}"}
    end
  end

  defp normalize_params(params) do
    # Extract API key from params or environment
    # In production, this might come from session context in the MCP server
    api_key =
      Map.get(params, "api_key") || Application.get_env(:skyfi_mcp, :default_api_key)

    if not api_key do
      {:error, "API key not provided"}
    else
      # Hash the API key for storage (NEVER store plaintext)
      api_key_hash = :crypto.hash(:sha256, api_key) |> Base.encode16(case: :lower)

      # Build criteria from individual params or criteria map
      criteria = build_criteria(params)

      # Normalize AOI to GeoJSON format
      aoi = normalize_aoi(params["aoi"])

      normalized = %{
        user_api_key_hash: api_key_hash,
        aoi: aoi,
        criteria: criteria,
        webhook_url: params["webhook_url"],
        check_interval: Map.get(params, "check_interval", 86400)
      }

      {:ok, normalized}
    end
  end

  defp normalize_aoi(aoi) when is_list(aoi) and length(aoi) == 4 do
    # Convert bbox [min_lon, min_lat, max_lon, max_lat] to GeoJSON Polygon
    [min_lon, min_lat, max_lon, max_lat] = aoi

    %{
      "type" => "Polygon",
      "coordinates" => [
        [
          [min_lon, min_lat],
          [max_lon, min_lat],
          [max_lon, max_lat],
          [min_lon, max_lat],
          [min_lon, min_lat]
        ]
      ]
    }
  end

  defp normalize_aoi(aoi) when is_map(aoi) do
    # Already GeoJSON format
    aoi
  end

  defp normalize_aoi(_) do
    # Invalid format - let validation catch it
    %{}
  end

  defp build_criteria(params) do
    # Allow criteria as a nested map OR individual params
    base_criteria = Map.get(params, "criteria", %{})

    base_criteria
    |> Map.put_new("cloud_cover_max", Map.get(params, "cloud_cover_max", 100))
    |> Map.put_new("sensor_types", Map.get(params, "sensor_types", ["optical"]))
    |> then(fn criteria ->
      # Only add resolution_min if provided
      if res = Map.get(params, "resolution_min") do
        Map.put(criteria, "resolution_min", res)
      else
        criteria
      end
    end)
  end

  defp format_response(monitor) do
    {:ok,
     %{
       monitor_id: monitor.id,
       status: monitor.status,
       check_interval_seconds: monitor.check_interval,
       next_check_at: calculate_next_check(monitor),
       webhook_url: monitor.webhook_url,
       aoi: monitor.aoi,
       criteria: monitor.criteria,
       message:
         "Monitor created successfully. You will receive notifications at the configured webhook URL when new imagery matching your criteria becomes available."
     }}
  end

  defp calculate_next_check(monitor) do
    DateTime.utc_now()
    |> DateTime.add(monitor.check_interval, :second)
    |> DateTime.to_iso8601()
  end

  defp format_validation_errors(changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)

    error_messages =
      Enum.map(errors, fn {field, msgs} ->
        "#{field}: #{Enum.join(List.wrap(msgs), ", ")}"
      end)

    "Validation failed: #{Enum.join(error_messages, "; ")}"
  end
end
