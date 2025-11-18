defmodule SkyfiMcp.Tools.PlaceOrder do
  @moduledoc """
  Implements the place_order MCP tool with safety validations.

  Places an order for satellite imagery (archive or tasking).
  Includes safety features:
  - Requires price confirmation
  - High-value order validation (>$500)
  - Comprehensive logging
  """

  require Logger
  alias SkyfiMcp.SkyfiClient

  @high_value_threshold 500.0

  @doc """
  Executes the place_order tool.

  Required params:
  - `order_type`: String - "archive" or "tasking"
  - `price_confirmed`: Boolean - User must confirm they accept the price

  Archive order params:
  - `image_id`: String - ID of archive image

  Tasking order params:
  - `aoi`: GeoJSON Polygon or BBox
  - `sensor_type`: String - "optical" or "sar"
  - `start_date`: ISO8601 string
  - `end_date`: ISO8601 string
  - `resolution`: Float - desired resolution in meters (optional)

  High-value order params (when total > $500):
  - `human_approval`: Boolean - Must be true for orders > $500
  - `estimated_cost`: Float - Expected cost (for validation)

  Options:
  - `skyfi_api_key`: SkyFi API key to use for this request (overrides config)
  """
  def execute(params, opts \\ []) do
    api_key = Keyword.get(opts, :skyfi_api_key)
    Logger.info("Place order attempt", params: sanitize_params(params))

    with {:ok, validated_params} <- validate_params(params),
         {:ok, _} <- check_price_confirmation(validated_params),
         {:ok, _} <- check_high_value_approval(validated_params),
         {:ok, response} <- SkyfiClient.place_order(api_key, validated_params) do
      Logger.info("Order placed successfully", order_id: Map.get(response, "order_id"))
      format_response(response)
    else
      {:error, reason} = error ->
        Logger.warning("Order placement failed", reason: reason)
        error
    end
  end

  defp validate_params(params) do
    order_type = Map.get(params, "order_type")

    cond do
      is_nil(order_type) ->
        {:error, "Missing required parameter: order_type"}

      order_type not in ["archive", "tasking"] ->
        {:error, "Invalid order_type. Must be 'archive' or 'tasking'"}

      order_type == "archive" ->
        validate_archive_order(params)

      order_type == "tasking" ->
        validate_tasking_order(params)
    end
  end

  defp validate_archive_order(params) do
    image_id = Map.get(params, "image_id")

    if is_nil(image_id) or image_id == "" do
      {:error, "Missing required parameter for archive order: image_id"}
    else
      {:ok, params}
    end
  end

  defp validate_tasking_order(params) do
    aoi = Map.get(params, "aoi")
    sensor_type = Map.get(params, "sensor_type")
    start_date = Map.get(params, "start_date")
    end_date = Map.get(params, "end_date")

    cond do
      is_nil(aoi) ->
        {:error, "Missing required parameter for tasking order: aoi"}

      is_nil(sensor_type) ->
        {:error, "Missing required parameter for tasking order: sensor_type"}

      is_nil(start_date) ->
        {:error, "Missing required parameter for tasking order: start_date"}

      is_nil(end_date) ->
        {:error, "Missing required parameter for tasking order: end_date"}

      sensor_type not in ["optical", "sar"] ->
        {:error, "Invalid sensor_type. Must be 'optical' or 'sar'"}

      true ->
        {:ok, params}
    end
  end

  defp check_price_confirmation(params) do
    price_confirmed = Map.get(params, "price_confirmed", false)

    if price_confirmed do
      {:ok, params}
    else
      {:error,
       "Price confirmation required. Please set 'price_confirmed: true' to confirm you accept the estimated cost."}
    end
  end

  defp check_high_value_approval(params) do
    estimated_cost = Map.get(params, "estimated_cost", 0.0)

    if estimated_cost > @high_value_threshold do
      human_approval = Map.get(params, "human_approval", false)

      if human_approval do
        Logger.info("High-value order approved",
          cost: estimated_cost,
          threshold: @high_value_threshold
        )

        {:ok, params}
      else
        {:error,
         "High-value order requires human approval. This order costs $#{estimated_cost}, which exceeds the $#{@high_value_threshold} threshold. Please set 'human_approval: true' to confirm."}
      end
    else
      {:ok, params}
    end
  end

  defp format_response(body) when is_map(body) do
    formatted = %{
      order_id: Map.get(body, "order_id") || Map.get(body, "id"),
      status: Map.get(body, "status", "pending"),
      status_url: Map.get(body, "status_url"),
      estimated_delivery: Map.get(body, "estimated_delivery"),
      total_cost: Map.get(body, "total_cost"),
      created_at: Map.get(body, "created_at"),
      order_type: Map.get(body, "order_type")
    }

    {:ok, formatted}
  end

  # Remove sensitive data from logs
  defp sanitize_params(params) do
    params
    |> Map.drop(["api_key", "payment_method"])
    |> Map.update("estimated_cost", nil, fn cost -> "$#{cost}" end)
  end
end
