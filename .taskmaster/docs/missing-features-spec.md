# Missing P0 Features Specification

## Overview
This document provides detailed specifications for the P0 features that were missing from the original task list but are required per project.md.

---

## 1. AOI Monitoring System (Tasks #12, #13)

### Purpose
Allow users to set up persistent monitoring for Areas of Interest (AOI), automatically receiving notifications when new imagery matching their criteria becomes available.

### User Story
"As an analyst, I want my AI agent to monitor a specific region and alert me when new cloud-free imagery is available, so I don't have to manually check the dashboard daily."

### Technical Architecture

#### Database Schema
```elixir
# monitors table
defmodule SkyfiMcp.Monitor do
  schema "monitors" do
    field :user_api_key_hash, :string  # SHA256 of API key for security
    field :aoi, :map                    # GeoJSON Polygon
    field :criteria, :map               # {cloud_cover_max, sensor_types, resolution_min}
    field :webhook_url, :string         # Where to send notifications
    field :check_interval, :string      # "hourly", "daily", "weekly"
    field :last_checked_at, :utc_datetime
    field :last_image_id, :string       # Track what we've already notified about
    field :status, :string              # "active", "paused", "failed"
    field :failure_count, :integer      # Track consecutive webhook failures

    timestamps()
  end
end
```

#### MCP Tool: `setup_monitor`

**Input Schema:**
```json
{
  "type": "object",
  "properties": {
    "aoi": {
      "type": "object",
      "description": "GeoJSON Polygon defining the area to monitor"
    },
    "criteria": {
      "type": "object",
      "properties": {
        "cloud_cover_max": {"type": "number", "minimum": 0, "maximum": 100},
        "sensor_types": {"type": "array", "items": {"enum": ["optical", "sar"]}},
        "resolution_min": {"type": "number", "description": "Minimum resolution in meters"}
      }
    },
    "webhook_url": {
      "type": "string",
      "format": "uri",
      "description": "HTTPS endpoint to receive notifications"
    },
    "check_interval": {
      "type": "string",
      "enum": ["hourly", "daily", "weekly"],
      "default": "daily"
    }
  },
  "required": ["aoi", "webhook_url"]
}
```

**Output:**
```json
{
  "monitor_id": "mon_abc123",
  "status": "active",
  "next_check_at": "2025-11-19T00:00:00Z",
  "webhook_url": "https://example.com/webhook"
}
```

**Implementation Notes:**
- Store API key hash (never plaintext) to authenticate future checks
- Validate webhook URL is HTTPS (security requirement)
- Create initial DB record with status="active"
- Schedule first check using Oban or GenServer

#### Background Worker: Webhook Notifier

**Process Flow:**
1. Every check_interval, worker queries active monitors
2. For each monitor:
   - Fetch new imagery from SkyFi API using search_archive with monitor criteria
   - Compare results against `last_image_id` to detect new imagery
   - If new images found, POST to webhook_url
   - Update monitor record: last_checked_at, last_image_id

**Webhook Payload:**
```json
{
  "event": "new_imagery_available",
  "monitor_id": "mon_abc123",
  "aoi": { "type": "Polygon", "coordinates": [...] },
  "new_images": [
    {
      "id": "img_xyz789",
      "timestamp": "2025-11-18T14:30:00Z",
      "cloud_cover": 5.2,
      "sensor": "optical",
      "preview_url": "https://skyfi.com/previews/img_xyz789",
      "thumbnail_url": "https://skyfi.com/thumbs/img_xyz789"
    }
  ],
  "criteria_matched": {
    "cloud_cover_max": 10,
    "sensor_types": ["optical"]
  },
  "timestamp": "2025-11-18T15:00:00Z"
}
```

**Webhook Security:**
- Sign payloads with HMAC-SHA256 using monitor-specific secret
- Include `X-SkyFi-Signature` header
- Timeout webhook requests after 10 seconds
- Retry failed deliveries: 3 attempts with exponential backoff (1min, 5min, 15min)
- After 3 failures, set monitor status="failed" and stop checking

**Monitoring:**
- Track webhook delivery success rate
- Alert if >10% of webhooks are failing
- Provide endpoint to check monitor status: GET /monitors/:id

---

## 2. OpenStreetMap Integration (Task #14)

### Purpose
Enable natural language location queries by converting place names to geographic coordinates and bounding boxes suitable for AOI search.

### User Story
"As a researcher, I want to ask 'find images of the Amazon Delta' without manually looking up coordinates, so I can work conversationally with the AI agent."

### Technical Architecture

#### MCP Tool: `geocode`

**Input Schema:**
```json
{
  "type": "object",
  "properties": {
    "query": {
      "type": "string",
      "description": "Location name or address to geocode (e.g., 'San Francisco', 'Amazon Delta', '1600 Pennsylvania Ave')"
    },
    "language": {
      "type": "string",
      "default": "en",
      "description": "ISO language code for results"
    }
  },
  "required": ["query"]
}
```

**Output:**
```json
{
  "location": "San Francisco, California, United States",
  "coordinates": {
    "lat": 37.7749,
    "lon": -122.4194
  },
  "bounding_box": {
    "type": "Polygon",
    "coordinates": [[
      [-122.5149, 37.7034],
      [-122.5149, 37.8349],
      [-122.3535, 37.8349],
      [-122.3535, 37.7034],
      [-122.5149, 37.7034]
    ]]
  },
  "confidence": "high",
  "type": "city"
}
```

#### MCP Tool: `reverse_geocode`

**Input Schema:**
```json
{
  "type": "object",
  "properties": {
    "lat": {"type": "number", "minimum": -90, "maximum": 90},
    "lon": {"type": "number", "minimum": -180, "maximum": 180}
  },
  "required": ["lat", "lon"]
}
```

**Output:**
```json
{
  "address": "San Francisco City Hall, San Francisco, California, United States",
  "components": {
    "city": "San Francisco",
    "state": "California",
    "country": "United States",
    "country_code": "us"
  },
  "coordinates": {
    "lat": 37.7749,
    "lon": -122.4194
  }
}
```

#### Implementation Details

**API Client:**
```elixir
defmodule SkyfiMcp.GeocodingClient do
  use Tesla

  # Nominatim requires User-Agent per ToS
  plug Tesla.Middleware.BaseUrl, "https://nominatim.openstreetmap.org"
  plug Tesla.Middleware.Headers, [
    {"user-agent", "SkyFi-MCP/1.0 (contact@skyfi.com)"}
  ]
  plug Tesla.Middleware.JSON

  # CRITICAL: Nominatim rate limit is 1 request/second
  # Implement token bucket rate limiter

  def search(query, opts \\ []) do
    # GET /search?q={query}&format=json&limit=1
    # Returns: [%{lat, lon, boundingbox, display_name}]
  end

  def reverse(lat, lon) do
    # GET /reverse?lat={lat}&lon={lon}&format=json
  end
end
```

**Rate Limiting:**
- Use `ExRated` or custom GenServer with token bucket
- Limit: 1 request per second per Nominatim ToS
- Queue requests if burst needed
- Return error if queue full

**Bounding Box Conversion:**
- Nominatim returns `boundingbox: [min_lat, max_lat, min_lon, max_lon]`
- Convert to GeoJSON Polygon for use with `search_archive` tool

**Caching:**
- Cache geocoding results for 7 days (locations don't change frequently)
- Use ETS table or Redis
- Key: `geocode:#{String.downcase(query)}`

**Error Handling:**
- Location not found -> suggest similar locations if available
- Ambiguous results -> return top match with confidence score
- Rate limit exceeded -> return friendly message with retry time

---

## 3. Error Handling & Production Readiness (Task #15)

### Purpose
Provide consistent, user-friendly error messages across all tools and ensure production reliability.

### Error Taxonomy

#### 1. SkyFi API Errors
```elixir
defmodule SkyfiMcp.ErrorHandler do
  def handle_api_error(%Tesla.Env{status: status, body: body}) do
    case status do
      401 ->
        {:error, "Invalid SkyFi API key. Please verify your credentials at https://skyfi.com/settings/api"}

      403 ->
        {:error, "Access denied. Your account may not have permission for this operation."}

      404 ->
        {:error, "Resource not found. The image or order ID may be invalid."}

      429 ->
        {:error, "Rate limit exceeded. Please wait 60 seconds before trying again."}

      400 ->
        parse_validation_error(body)

      500..599 ->
        {:error, "SkyFi service temporarily unavailable. Please try again in a few minutes. [Error #{status}]"}

      _ ->
        {:error, "Unexpected error occurred. Status: #{status}"}
    end
  end

  defp parse_validation_error(body) do
    # Extract field-specific errors from API response
    # Example: "Invalid AOI: coordinates must be within [-180, 180]"
  end
end
```

#### 2. Input Validation Errors
- Use `Ecto.Changeset` for structured validation
- Return specific field errors
- Example: "cloud_cover_max must be between 0 and 100, got 150"

#### 3. Network Errors
- Connection timeout -> "Unable to reach SkyFi API. Check your internet connection."
- DNS resolution -> "Cannot connect to SkyFi. Please check the service status."

### Logging Strategy

**Structured Logging:**
```elixir
Logger.info("Tool invoked",
  tool: "search_archive",
  request_id: request_id,
  api_key_hash: hash_first_8(api_key),
  params: sanitized_params,
  duration_ms: duration
)

Logger.error("Tool failed",
  tool: "place_order",
  request_id: request_id,
  error: error_message,
  status_code: status,
  duration_ms: duration
)
```

**What NOT to Log:**
- Full API keys (only hash first 8 chars)
- Payment information
- Full webhook URLs (only domain)
- User personal data

### Telemetry Events
```elixir
:telemetry.execute(
  [:skyfi_mcp, :tool, :call],
  %{duration: duration_ms},
  %{tool: "search_archive", status: "success"}
)
```

**Metrics to Track:**
- Tool invocation count by name
- Success/error rates
- Latency (p50, p95, p99)
- API error codes by type
- Active monitor count
- Webhook delivery success rate

---

## 4. Demo Agent Specification (Task #21)

### Purpose
Showcase the full power of SkyFi MCP with a polished reference implementation that developers can learn from.

### Demo Scenarios

#### Scenario 1: Research Workflow
```python
# Agent conversation example
User: "Find recent deforestation in the Amazon rainforest from the last 3 months"

Agent reasoning:
1. Use geocode tool: "Amazon rainforest" -> coordinates
2. Use search_archive with:
   - AOI from geocoding bbox
   - Date range: last 3 months
   - Cloud cover: <20% (implied for visual analysis)
3. Filter results by timestamp
4. Present: "Found 15 images. Most recent from Nov 10, 2025. Cloud cover: 8%"

User: "Show me the pricing for the clearest image"

Agent:
1. Select image with lowest cloud cover
2. Use get_price_estimate
3. Present: "The clearest image (2% cloud) costs $45. Archive download, 3m resolution."

User: "Set up monitoring so I'm alerted if new images appear"

Agent:
1. Use setup_monitor with same AOI and criteria
2. Configure webhook (to user's notification endpoint)
3. Confirm: "Monitor active. You'll receive notifications daily if new imagery matches."
```

#### Scenario 2: Tasking Workflow
```
User: "I need a satellite image of the Port of Rotterdam tomorrow"

Agent:
1. Geocode "Port of Rotterdam"
2. Use check_feasibility for tomorrow's date
3. Present: "3 satellite passes available. 85% success probability."
4. Use get_price_estimate for tasking
5. Present: "Optical tasking: $280. SAR (all-weather): $420"

User: "Order the optical tasking"

Agent:
1. Require confirmation: "Please confirm the $280 charge"
2. User: "Confirmed"
3. Use place_order with confirmation token
4. Present: "Order #12345 placed. Estimated delivery: Nov 20. Track at: [URL]"
```

### Implementation

**Stack Options:**
1. **Python with MCP SDK** (recommended for wider reach)
   ```python
   from mcp import Client
   import anthropic

   # Orchestrate Claude + SkyFi MCP tools
   ```

2. **TypeScript with MCP SDK**
   ```typescript
   import { Client } from "@modelcontextprotocol/sdk";
   import Anthropic from "@anthropic-ai/sdk";
   ```

**Features:**
- Conversational CLI interface
- Jupyter notebook for research use case
- Logging of tool calls and reasoning
- Error recovery (retry logic)
- Cost tracking (sum of all price estimates)

**Deliverables:**
- Source code in `examples/demo-agent/`
- README with setup instructions
- Demo video (5-10 minutes)
- Sample transcripts in markdown

---

## Priority Implementation Order

**Week 1 - Core Foundation:**
1. ✅ Task 1: Phoenix project setup
2. ✅ Task 2: Basic README
3. ✅ Task 3: SkyFi client module
4. ✅ Task 4: JSON-RPC handler
5. ✅ Task 7: stdio transport (for local testing)
6. ✅ Task 5: First tool (search_archive) - validate end-to-end

**Week 2 - P0 Tools:**
7. Tasks 8-11: Remaining core tools
8. Task 14: OpenStreetMap integration
9. Task 17: Database for monitors
10. Task 12-13: Monitoring system + webhooks
11. Task 15: Error handling

**Week 3 - Production Ready:**
12. Task 16: Server initialization + tool registry
13. Task 6: SSE transport (for remote deployment)
14. Task 18-19: Config + Docker
15. Task 23: Security audit
16. Task 20: Documentation

**Week 4 - Polish:**
17. Task 21: Demo agent
18. Task 22: Telemetry + monitoring
19. Final testing + bug fixes
20. Launch prep

---

## Success Criteria

### Functional Requirements Met
- ✅ All P0 tools working (search, feasibility, pricing, ordering, monitoring)
- ✅ Monitoring with webhook notifications
- ✅ OpenStreetMap integration for natural language queries
- ✅ stdio and SSE transport modes
- ✅ Comprehensive error handling
- ✅ Demo agent showcasing capabilities

### Technical Quality
- ✅ Test coverage >80%
- ✅ All tests passing in CI/CD
- ✅ Latency <200ms for tool execution (excluding SkyFi API)
- ✅ Successfully handles 100 concurrent sessions
- ✅ Security audit passed (no API key leaks, input validation, webhook security)
- ✅ Documentation complete and validated by external developer

### Business Metrics
- ✅ Deployed to production (Fly.io/Render)
- ✅ Demo video published
- ✅ Open source repo with README
- ✅ Integration tested with Claude Desktop
- ✅ 5+ example workflows documented

---

## Questions for Product Owner

1. **Webhook Signing:** Should we implement webhook signature verification (HMAC) for security, or is HTTPS sufficient for MVP?

2. **Monitoring Limits:** Should we cap the number of active monitors per user? (e.g., 10 monitors max)

3. **Geocoding:** Are there specific regions we should optimize for, or is global coverage sufficient?

4. **Demo Agent:** Which framework should we prioritize - Python (for data science audience) or TypeScript (for web dev audience)?

5. **Pricing Confirmation:** Should high-value orders (>$500) block with a required human approval, or just warn?
