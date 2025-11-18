# SkyFi MCP Examples

This directory contains examples and demos showing how to interact with the SkyFi MCP server.

## Contents

- **`demo_agent.py`** - Complete Python demo showcasing all 8 MCP tools
- **`requirements.txt`** - Python dependencies for the demo

## Quick Start

### 1. Start the MCP Server

```bash
# From the project root
mix phx.server
```

The server will be available at `http://localhost:4000`.

### 2. Install Python Dependencies

```bash
# From the examples directory
pip install -r requirements.txt
```

### 3. Run the Demo

```bash
python demo_agent.py
```

## Demo Workflows

The demo agent demonstrates 5 complete workflows:

### Workflow 1: Search for Satellite Imagery
- Geocode a location name (e.g., "San Francisco")
- Search for existing satellite imagery
- Filter by date range and cloud cover

**Use Case:** Finding historical imagery for analysis

### Workflow 2: Check Satellite Tasking Feasibility
- Geocode a specific landmark (e.g., "Golden Gate Bridge")
- Check if new imagery can be captured
- Get satellite pass times

**Use Case:** Planning new satellite tasking orders

### Workflow 3: Get Pricing Estimate
- Define an area of interest
- Get cost breakdown for tasking
- Understand pricing components

**Use Case:** Budget planning for satellite orders

### Workflow 4: Set Up Area Monitoring
- Geocode an area (e.g., "Paris, France")
- Configure monitoring criteria (cloud cover, sensors)
- Set up webhook notifications

**Use Case:** Automated alerts for new imagery

### Workflow 5: Review Order History
- List all recent orders
- Filter by status (pending, completed, etc.)
- View order metadata

**Use Case:** Tracking purchases and deliveries

## Expected Output

When you run the demo, you'll see:

```
╔═══════════════════════════════════════════════════════════════════╗
║                                                                     ║
║              SkyFi MCP Demo Agent - Interactive Tour               ║
║                                                                     ║
║  This demo showcases satellite imagery workflows using the         ║
║  SkyFi Model Context Protocol server.                              ║
║                                                                     ║
╚═══════════════════════════════════════════════════════════════════╝

======================================================================
WORKFLOW 1: Search for Satellite Imagery
======================================================================

🎯 Goal: Find recent satellite images of San Francisco

📍 Step 1: Convert 'San Francisco' to coordinates...

📡 Calling tool: geocode
   Arguments: {
     "query": "San Francisco, California, USA"
   }
✅ Success!
   Found coordinates: 37.7749, -122.4194
   Bounding box: [-122.5155, 37.7034, -122.3581, 37.8324]

🛰️  Step 2: Search for satellite imagery...

📡 Calling tool: search_archive
   Arguments: {
     "aoi": [-122.5155, 37.7034, -122.3581, 37.8324],
     "start_date": "2025-10-18T00:00:00Z",
     "end_date": "2025-11-18T00:00:00Z",
     "cloud_cover_max": 20
   }
✅ Success!
   Found 5 images with <20% cloud cover

   Sample result:
   - Image ID: img_12345
   - Date: 2025-11-10T14:30:00Z
   - Cloud Cover: 8%
   - Resolution: 0.5m
```

## Customizing the Demo

### Use Your Own API Key

Edit `demo_agent.py` and set your API key:

```python
demo = SkyFiMCPDemo(
    mcp_url="http://localhost:4000",
    skyfi_api_key="your_skyfi_api_key_here"  # <-- Add your key here
)
```

Alternatively, set the `SKYFI_API_KEY` environment variable when running the MCP server.

### Change the Target Location

Modify the location in any workflow:

```python
# Instead of "San Francisco"
geocode_result = self.call_tool("geocode", {
    "query": "Tokyo, Japan"  # <-- Your location here
})
```

### Adjust Search Criteria

Change filters in the search workflow:

```python
search_result = self.call_tool("search_archive", {
    "aoi": bbox,
    "start_date": start_date.isoformat() + "Z",
    "end_date": end_date.isoformat() + "Z",
    "cloud_cover_max": 10  # <-- Stricter cloud cover requirement
})
```

### Set Up Real Webhook Monitoring

1. Go to [webhook.site](https://webhook.site) and copy your unique URL
2. Update the monitoring workflow:

```python
demo.demo_monitoring_workflow(
    webhook_url="https://webhook.site/YOUR-UNIQUE-ID"  # <-- Your webhook URL
)
```

3. Watch for real-time notifications when new imagery is found!

## Using with Claude Desktop

Instead of running the Python demo, you can use Claude Desktop with natural language:

```
"Find satellite images of the Amazon rainforest from the last month with less than 20% cloud cover"

"Can SkyFi capture new imagery of the Eiffel Tower? How much would it cost?"

"Set up monitoring for Central Park in New York and alert me when new images are available"
```

See `HUMAN_TEST.md` in the project root for complete testing scenarios.

## Building Your Own Agent

Use this demo as a template for building your own AI agents:

```python
from demo_agent import SkyFiMCPDemo

# Initialize your agent
agent = SkyFiMCPDemo(
    mcp_url="http://your-mcp-server.com",
    skyfi_api_key="your_api_key"
)

# Call any tool
result = agent.call_tool("search_archive", {
    "aoi": [-122.5, 37.7, -122.3, 37.9],
    "start_date": "2025-01-01T00:00:00Z",
    "end_date": "2025-01-31T23:59:59Z",
    "cloud_cover_max": 15
})

# Process the results
for image in result:
    print(f"Found image: {image['id']} with {image['cloud_cover']}% clouds")
```

## Available Tools

All 8 SkyFi MCP tools are demonstrated:

| Tool | Purpose | Example Use |
|------|---------|-------------|
| `geocode` | Convert location names to coordinates | "San Francisco" → lat/lon |
| `reverse_geocode` | Convert coordinates to location names | 37.7749, -122.4194 → "San Francisco" |
| `search_archive` | Find existing satellite imagery | Search by AOI, date, cloud cover |
| `check_feasibility` | Check if new imagery can be captured | Optical/SAR sensor availability |
| `get_price_estimate` | Get pricing for imagery | Tasking or archive pricing |
| `place_order` | Purchase imagery | (Not shown in demo for safety) |
| `list_orders` | View order history | Filter by status, pagination |
| `setup_monitor` | Set up automated monitoring | Webhook notifications |

## Troubleshooting

### Connection Error

```
❌ Request failed: Connection refused
```

**Solution:** Make sure the MCP server is running on `http://localhost:4000`

### API Key Error

```
❌ Error: Invalid API key
```

**Solution:** Set your SkyFi API key in the server's `.env` file or pass it to the demo agent

### Geocoding Errors

```
❌ Error: Location not found
```

**Solution:** Try being more specific (e.g., "Paris, France" instead of just "Paris")

### Webhook Not Receiving Notifications

**Solution:**
1. Check that the monitor was created successfully (you'll see a `monitor_id`)
2. Wait up to 60 seconds for the background worker to run
3. Verify your webhook URL is correct
4. Check the MCP server logs: `tail -f log/dev.log`

## Next Steps

- ✅ Run the demo to see all tools in action
- ✅ Customize workflows for your use cases
- ✅ Set up real webhook monitoring
- ✅ Try Claude Desktop integration
- ✅ Deploy your own MCP server to Fly.io
- ✅ Build production AI agents with the MCP SDK

## Resources

- **Main README:** `../README.md` - Complete project documentation
- **Testing Guide:** `../HUMAN_TEST.md` - Manual testing scenarios
- **MCP Protocol:** https://modelcontextprotocol.io
- **SkyFi API:** https://docs.skyfi.com

---

**Questions?** Open an issue on GitHub or contact support@skyfi.com
