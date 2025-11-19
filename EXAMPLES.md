# SkyFi MCP - Quick Examples

Quick reference for testing SkyFi MCP tools manually.

## MCP Prompts (High-Level Commands)

These are the easiest way to use the service via Claude Code or other MCP clients.

### Search for Imagery
```
/skyfi:search_imagery San Francisco
/skyfi:search_imagery Tokyo
/skyfi:search_imagery Death Valley, days_back=60
/skyfi:search_imagery Eiffel Tower, Paris
```

### Check Pricing
```
/skyfi:price_check Golden Gate Bridge
/skyfi:price_check Central Park, type=archive
/skyfi:price_check Mount Everest, type=tasking
```

### Set Up Monitoring
```
/skyfi:monitor_area Yellowstone National Park, webhook_url=https://your-webhook.com/notify
/skyfi:monitor_area Area 51, webhook_url=https://example.com/alerts
```

## Direct Tool Calls

### 1. Geocode Location
Convert location names to coordinates:

```javascript
// Via Claude Code MCP
mcp__skyfi__geocode({
  query: "Grand Canyon",
  limit: 1
})
```

Example locations to try:
- `"Mount Rushmore"`
- `"Statue of Liberty"`
- `"Golden Gate Bridge"`
- `"Sydney Opera House"`

### 2. Search Archive
Search existing satellite imagery:

```javascript
mcp__skyfi__search_archive({
  aoi: [-122.5, 37.7, -122.3, 37.9],  // San Francisco bbox
  start_date: "2025-10-01T00:00:00Z",
  end_date: "2025-11-18T23:59:59Z",
  cloud_cover_max: 20
})
```

**Quick Areas to Try:**
```javascript
// Death Valley
aoi: [-117.651, 35.551, -116.257, 37.296]

// Las Vegas
aoi: [-115.36, 35.99, -115.06, 36.29]

// Yosemite
aoi: [-119.87, 37.55, -119.20, 38.20]
```

### 3. Check Feasibility
Check if new imagery can be captured:

```javascript
mcp__skyfi__check_feasibility({
  aoi: [-122.5, 37.7, -122.3, 37.9],
  start_date: "2025-11-20T00:00:00Z",
  end_date: "2025-11-27T23:59:59Z",
  sensor_type: "optical"
})
```

Try with:
- `sensor_type: "optical"` - Weather-dependent, high resolution
- `sensor_type: "sar"` - All-weather radar imaging

### 4. Get Price Estimate
Get pricing for archive or tasking:

```javascript
mcp__skyfi__get_price_estimate({
  aoi: [-122.5, 37.7, -122.3, 37.9],
  sensor_type: "optical",
  resolution: 0.5,
  priority: "standard"
})
```

Priority options:
- `"standard"` - Normal delivery
- `"priority"` - Faster delivery
- `"urgent"` - Expedited delivery

### 5. List Orders
View your order history:

```javascript
mcp__skyfi__list_orders({
  status: "completed",
  limit: 10
})
```

Status filters:
- `"pending"`
- `"processing"`
- `"completed"`
- `"failed"`
- `"cancelled"`

### 6. Reverse Geocode
Convert coordinates to location names:

```javascript
mcp__skyfi__reverse_geocode({
  lat: 36.4228722,
  lon: -116.913718,
  zoom: 10  // City level
})
```

Zoom levels:
- `3` - Country
- `5` - State
- `10` - City
- `14` - Suburb
- `18` - Building

## Complete Workflow Example

```bash
# 1. Find coordinates for a location
/skyfi:search_imagery Yellowstone National Park

# 2. Check feasibility for new capture
# (Use coordinates from step 1)

# 3. Get price estimate

# 4. Place order (if satisfied with price)

# 5. Monitor order status
```

## Testing Open Data (FREE)

Search for free Sentinel-2 imagery:

```javascript
mcp__skyfi__search_archive({
  aoi: [-122.5, 37.7, -122.3, 37.9],
  start_date: "2025-10-01T00:00:00Z",
  end_date: "2025-11-18T23:59:59Z",
  cloud_cover_max: 30
})
```

Look for images with:
- `"openData": true`
- `"priceForOneSquareKm": 0.0`
- `"provider": "SENTINEL2_CREODIAS"`

## Quick Test Locations

### US Landmarks
- Death Valley: `[-117.651, 35.551, -116.257, 37.296]`
- Grand Canyon: `[-112.35, 35.85, -111.65, 36.45]`
- Yellowstone: `[-111.15, 44.13, -109.83, 45.12]`
- Manhattan: `[-74.02, 40.70, -73.91, 40.88]`

### International
- Tokyo: `[139.50, 35.50, 139.95, 35.85]`
- Paris: `[2.22, 48.81, 2.47, 48.90]`
- London: `[-0.23, 51.43, 0.05, 51.60]`
- Sydney: `[151.10, -33.95, 151.35, -33.80]`

## Environment Setup

Make sure your `.env` file has:
```bash
SKYFI_API_KEY="your-api-key-here"
```

Get your API key from: https://app.skyfi.com/settings/api

## Production Endpoints

- **MCP Server:** https://skyfi-mcp.fly.dev
- **Health Check:** https://skyfi-mcp.fly.dev/health
- **SkyFi API:** https://app.skyfi.com/platform-api

## Next Steps

1. **Get API Key:** Sign up at https://app.skyfi.com
2. **Update .env:** Add your real API key
3. **Test Search:** Try the Death Valley example above
4. **Explore Features:** Use the prompt commands for workflows

---

**Need Help?** Check the full README or API docs at https://app.skyfi.com/platform-api/docs
