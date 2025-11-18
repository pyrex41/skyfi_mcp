defmodule SkyfiMcp.ToolRouter do
  @moduledoc """
  Routes MCP JSON-RPC requests to appropriate handlers.

  Handles MCP protocol methods:
  - initialize: Server initialization
  - tools/list: List available tools
  - tools/call: Execute a specific tool
  """

  require Logger
  alias SkyfiMcp.McpProtocol.JsonRpc
  alias SkyfiMcp.Tools.SearchArchive
  alias SkyfiMcp.Tools.CheckFeasibility
  alias SkyfiMcp.Tools.GetPriceEstimate
  alias SkyfiMcp.Tools.PlaceOrder
  alias SkyfiMcp.Tools.ListOrders
  alias SkyfiMcp.Tools.Geocode
  alias SkyfiMcp.Tools.ReverseGeocode
  alias SkyfiMcp.Tools.SetupMonitor

  @server_name "skyfi-mcp"
  @server_version "0.1.0"

  @doc """
  Handles an incoming JSON-RPC request and returns a response.

  opts can include:
  - skyfi_api_key: Override the default SkyFi API key for this request
  """
  def handle_request(request, opts \\ [])

  def handle_request(%JsonRpc.Request{method: "initialize", id: id}, _opts) do
    Logger.info("MCP: Initializing server")

    result = %{
      protocolVersion: "2024-11-05",
      capabilities: %{
        tools: %{}
      },
      serverInfo: %{
        name: @server_name,
        version: @server_version
      }
    }

    JsonRpc.success_response(id, result)
  end

  def handle_request(%JsonRpc.Request{method: "tools/list", id: id}, _opts) do
    Logger.info("MCP: Listing tools")

    tools = [
      %{
        name: "search_archive",
        description: "Search SkyFi's archive for existing satellite imagery within a specified area of interest (AOI) and date range.",
        inputSchema: %{
          type: "object",
          properties: %{
            aoi: %{
              type: "array",
              description: "Bounding box as [min_lon, min_lat, max_lon, max_lat] or GeoJSON Polygon",
              items: %{type: "number"}
            },
            start_date: %{
              type: "string",
              description: "ISO8601 start date (e.g., '2023-01-01T00:00:00Z')",
              format: "date-time"
            },
            end_date: %{
              type: "string",
              description: "ISO8601 end date",
              format: "date-time"
            },
            cloud_cover_max: %{
              type: "integer",
              description: "Maximum cloud cover percentage (0-100)",
              minimum: 0,
              maximum: 100,
              default: 100
            }
          },
          required: ["aoi", "start_date", "end_date"]
        }
      },
      %{
        name: "check_feasibility",
        description: "Check the feasibility of satellite tasking for a given AOI, date range, and sensor type. Returns success probability and available pass times.",
        inputSchema: %{
          type: "object",
          properties: %{
            aoi: %{
              type: "array",
              description: "Bounding box as [min_lon, min_lat, max_lon, max_lat] or GeoJSON Polygon",
              items: %{type: "number"}
            },
            start_date: %{
              type: "string",
              description: "ISO8601 start date for tasking window",
              format: "date-time"
            },
            end_date: %{
              type: "string",
              description: "ISO8601 end date for tasking window",
              format: "date-time"
            },
            sensor_type: %{
              type: "string",
              description: "Sensor type: 'optical' (weather-dependent) or 'sar' (all-weather)",
              enum: ["optical", "sar"],
              default: "optical"
            },
            resolution: %{
              type: "number",
              description: "Desired resolution in meters (optional)"
            }
          },
          required: ["aoi", "start_date", "end_date"]
        }
      },
      %{
        name: "get_price_estimate",
        description: "Get pricing estimate for archive imagery or tasking orders. Provide either image_id (archive) or tasking parameters.",
        inputSchema: %{
          type: "object",
          properties: %{
            image_id: %{
              type: "string",
              description: "Archive image ID (for archive pricing)"
            },
            aoi: %{
              type: "array",
              description: "Bounding box for tasking (required for tasking pricing)",
              items: %{type: "number"}
            },
            sensor_type: %{
              type: "string",
              description: "Sensor type for tasking: 'optical' or 'sar'",
              enum: ["optical", "sar"]
            },
            resolution: %{
              type: "number",
              description: "Desired resolution in meters (optional)"
            },
            priority: %{
              type: "string",
              description: "Priority level: 'standard', 'priority', or 'urgent'",
              enum: ["standard", "priority", "urgent"],
              default: "standard"
            }
          }
        }
      },
      %{
        name: "place_order",
        description: "Place an order for satellite imagery (archive or tasking). IMPORTANT: Requires price confirmation and human approval for high-value orders (>$500).",
        inputSchema: %{
          type: "object",
          properties: %{
            order_type: %{
              type: "string",
              description: "Order type: 'archive' or 'tasking'",
              enum: ["archive", "tasking"]
            },
            image_id: %{
              type: "string",
              description: "Archive image ID (required for archive orders)"
            },
            aoi: %{
              type: "array",
              description: "Bounding box (required for tasking orders)",
              items: %{type: "number"}
            },
            sensor_type: %{
              type: "string",
              description: "Sensor type for tasking",
              enum: ["optical", "sar"]
            },
            start_date: %{
              type: "string",
              description: "Start date for tasking window",
              format: "date-time"
            },
            end_date: %{
              type: "string",
              description: "End date for tasking window",
              format: "date-time"
            },
            price_confirmed: %{
              type: "boolean",
              description: "User confirms they accept the estimated price (REQUIRED)"
            },
            estimated_cost: %{
              type: "number",
              description: "Expected cost from price estimate"
            },
            human_approval: %{
              type: "boolean",
              description: "Required for orders >$500"
            }
          },
          required: ["order_type", "price_confirmed"]
        }
      },
      %{
        name: "list_orders",
        description: "List order history with optional filtering and pagination. Returns orders sorted by creation date (newest first).",
        inputSchema: %{
          type: "object",
          properties: %{
            status: %{
              type: "string",
              description: "Filter by order status",
              enum: ["pending", "processing", "completed", "failed", "cancelled"]
            },
            order_type: %{
              type: "string",
              description: "Filter by order type",
              enum: ["archive", "tasking"]
            },
            limit: %{
              type: "integer",
              description: "Number of results per page (1-100)",
              minimum: 1,
              maximum: 100,
              default: 10
            },
            offset: %{
              type: "integer",
              description: "Pagination offset",
              minimum: 0,
              default: 0
            }
          }
        }
      },
      %{
        name: "geocode",
        description: "Convert a location name or address into geographic coordinates (latitude, longitude). Useful for finding satellite imagery of natural language locations like 'San Francisco' or 'Eiffel Tower, Paris'.",
        inputSchema: %{
          type: "object",
          properties: %{
            query: %{
              type: "string",
              description: "Location name or address to geocode (e.g., 'San Francisco, CA', 'Paris, France')"
            },
            limit: %{
              type: "integer",
              description: "Maximum number of results to return (1-50)",
              minimum: 1,
              maximum: 50,
              default: 5
            },
            country_codes: %{
              type: "string",
              description: "Comma-separated ISO 3166-1alpha2 country codes to limit results (e.g., 'us,ca,gb')"
            },
            viewbox: %{
              type: "array",
              description: "Prefer results within bounding box [min_lon, min_lat, max_lon, max_lat]",
              items: %{type: "number"},
              minItems: 4,
              maxItems: 4
            }
          },
          required: ["query"]
        }
      },
      %{
        name: "reverse_geocode",
        description: "Convert geographic coordinates (latitude, longitude) into a human-readable location name and address. Useful for identifying what location satellite imagery coordinates represent.",
        inputSchema: %{
          type: "object",
          properties: %{
            lat: %{
              type: "number",
              description: "Latitude (-90 to 90)",
              minimum: -90,
              maximum: 90
            },
            lon: %{
              type: "number",
              description: "Longitude (-180 to 180)",
              minimum: -180,
              maximum: 180
            },
            zoom: %{
              type: "integer",
              description: "Detail level: 3=country, 5=state, 8=county, 10=city, 14=suburb, 16=streets, 18=building",
              minimum: 0,
              maximum: 18,
              default: 18
            }
          },
          required: ["lat", "lon"]
        }
      },
      %{
        name: "setup_monitor",
        description: "Set up monitoring for an area of interest to receive webhook notifications when new satellite imagery matching your criteria becomes available. Perfect for automated alerting and continuous monitoring.",
        inputSchema: %{
          type: "object",
          properties: %{
            aoi: %{
              oneOf: [
                %{
                  type: "array",
                  description: "Bounding box as [min_lon, min_lat, max_lon, max_lat]",
                  items: %{type: "number"},
                  minItems: 4,
                  maxItems: 4
                },
                %{
                  type: "object",
                  description: "GeoJSON Polygon",
                  required: ["type", "coordinates"],
                  properties: %{
                    type: %{type: "string", enum: ["Polygon", "MultiPolygon"]},
                    coordinates: %{type: "array"}
                  }
                }
              ]
            },
            webhook_url: %{
              type: "string",
              description: "HTTPS URL to receive POST notifications when new imagery is found",
              format: "uri"
            },
            cloud_cover_max: %{
              type: "integer",
              description: "Maximum cloud cover percentage (0-100)",
              minimum: 0,
              maximum: 100,
              default: 100
            },
            sensor_types: %{
              type: "array",
              description: "Sensor types to monitor",
              items: %{type: "string", enum: ["optical", "sar"]},
              default: ["optical"]
            },
            resolution_min: %{
              type: "number",
              description: "Minimum resolution in meters (optional)"
            },
            check_interval: %{
              type: "integer",
              description: "Check interval in seconds (minimum: 3600 = hourly, default: 86400 = daily)",
              minimum: 3600,
              default: 86400
            },
            api_key: %{
              type: "string",
              description: "SkyFi API key for authentication"
            }
          },
          required: ["aoi", "webhook_url"]
        }
      }
    ]

    result = %{tools: tools}
    JsonRpc.success_response(id, result)
  end

  def handle_request(%JsonRpc.Request{method: "tools/call", params: params, id: id}, opts) do
    tool_name = Map.get(params, "name")
    tool_arguments = Map.get(params, "arguments", %{})

    Logger.info("MCP: Calling tool #{tool_name}")

    case execute_tool(tool_name, tool_arguments, opts) do
      {:ok, result} ->
        JsonRpc.success_response(id, %{
          content: [
            %{
              type: "text",
              text: Jason.encode!(result, pretty: true)
            }
          ]
        })

      {:error, reason} ->
        Logger.error("Tool execution failed: #{inspect(reason)}")
        JsonRpc.error_response(id, -32000, "Tool execution failed: #{inspect(reason)}")
    end
  end

  def handle_request(%JsonRpc.Request{method: _method, id: nil}, _opts) do
    # Notification (no response expected)
    Logger.debug("MCP: Received notification, no response needed")
    nil
  end

  def handle_request(%JsonRpc.Request{method: method, id: id}, _opts) do
    Logger.warning("MCP: Unknown method: #{method}")
    JsonRpc.method_not_found(id)
  end

  defp execute_tool("search_archive", arguments, opts) do
    SearchArchive.execute(arguments, opts)
  end

  defp execute_tool("check_feasibility", arguments, opts) do
    CheckFeasibility.execute(arguments, opts)
  end

  defp execute_tool("get_price_estimate", arguments, opts) do
    GetPriceEstimate.execute(arguments, opts)
  end

  defp execute_tool("place_order", arguments, opts) do
    PlaceOrder.execute(arguments, opts)
  end

  defp execute_tool("list_orders", arguments, opts) do
    ListOrders.execute(arguments, opts)
  end

  defp execute_tool("geocode", arguments, _opts) do
    # Geocode doesn't need SkyFi API key
    Geocode.execute(arguments)
  end

  defp execute_tool("reverse_geocode", arguments, _opts) do
    # Reverse geocode doesn't need SkyFi API key
    ReverseGeocode.execute(arguments)
  end

  defp execute_tool("setup_monitor", arguments, opts) do
    SetupMonitor.execute(arguments, opts)
  end

  defp execute_tool(unknown_tool, _arguments, _opts) do
    {:error, "Unknown tool: #{unknown_tool}"}
  end
end
