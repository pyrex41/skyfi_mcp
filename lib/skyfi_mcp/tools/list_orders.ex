defmodule SkyfiMcp.Tools.ListOrders do
  @moduledoc """
  Implements the list_orders MCP tool.

  Retrieves order history with optional filtering and pagination.
  """

  alias SkyfiMcp.SkyfiClient

  @valid_statuses ["pending", "processing", "completed", "failed", "cancelled"]
  @default_limit 10

  @doc """
  Executes the list_orders tool.

  Optional params:
  - `status`: String - Filter by order status ("pending", "processing", "completed", "failed", "cancelled")
  - `limit`: Integer - Number of results per page (default: 10, max: 100)
  - `offset`: Integer - Pagination offset (default: 0)
  - `order_type`: String - Filter by order type ("archive" or "tasking")
  """
  def execute(params \\ %{}) do
    with {:ok, validated_params} <- validate_params(params),
         {:ok, response} <- SkyfiClient.list_orders(validated_params) do
      format_response(response)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_params(params) do
    status = Map.get(params, "status")
    limit = Map.get(params, "limit", @default_limit)
    offset = Map.get(params, "offset", 0)

    cond do
      not is_nil(status) and status not in @valid_statuses ->
        {:error,
         "Invalid status. Must be one of: #{Enum.join(@valid_statuses, ", ")}"}

      not is_integer(limit) or limit < 1 or limit > 100 ->
        {:error, "Invalid limit. Must be between 1 and 100"}

      not is_integer(offset) or offset < 0 ->
        {:error, "Invalid offset. Must be >= 0"}

      true ->
        # Ensure limit and offset are integers in the params
        validated =
          params
          |> Map.put("limit", limit)
          |> Map.put("offset", offset)

        {:ok, validated}
    end
  end

  defp format_response(body) when is_map(body) do
    orders = Map.get(body, "orders", []) || Map.get(body, "data", [])
    total_count = Map.get(body, "total_count", length(orders))
    limit = Map.get(body, "limit", @default_limit)
    offset = Map.get(body, "offset", 0)

    formatted_orders =
      Enum.map(orders, fn order ->
        %{
          id: Map.get(order, "order_id") || Map.get(order, "id"),
          status: Map.get(order, "status"),
          order_type: Map.get(order, "order_type"),
          created_at: Map.get(order, "created_at"),
          total_cost: Map.get(order, "total_cost"),
          estimated_delivery: Map.get(order, "estimated_delivery"),
          aoi_preview: Map.get(order, "aoi_preview"),
          image_count: Map.get(order, "image_count")
        }
      end)

    result = %{
      orders: formatted_orders,
      total_count: total_count,
      limit: limit,
      offset: offset,
      has_more: (offset + limit) < total_count
    }

    {:ok, result}
  end
end
