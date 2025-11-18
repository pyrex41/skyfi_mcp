# SkyFi MCP - Human Testing Guide

This guide provides a comprehensive test plan to verify all P0 requirements from `project.md` are working correctly.

## Prerequisites

- Claude Desktop with MCP configured (stdio transport)
- Valid SkyFi API key (Gold tier)
- Test webhook endpoint (use [webhook.site](https://webhook.site) for testing)

---

## Test Suite

### 1. ✅ Server Deployment & Authentication

**P0 Requirement:** _Deploy a remote MCP server based on SkyFi's public API methods_

**Test Steps:**
```
1. Start the server: mix phx.server
2. In Claude Desktop, ask: "What tools do you have available?"
3. Verify you see all 8 tools listed
```

**Expected Result:** Claude lists: search_archive, check_feasibility, get_price_estimate, place_order, list_orders, geocode, reverse_geocode, setup_monitor

**Status:** ⬜ Pass / ⬜ Fail

---

### 2. ✅ OpenStreetMaps Integration

**P0 Requirement:** _Integrate OpenStreetMaps_

**Test Steps:**
```
Ask Claude:
"Find me the coordinates for San Francisco"

Then:
"What location is at coordinates 37.7749, -122.4194?"
```

**Expected Result:**
- First query returns lat/lon coordinates and bounding box
- Second query returns "San Francisco" or similar location name

**Status:** ⬜ Pass / ⬜ Fail

---

### 3. ✅ Iterative Data Search

**P0 Requirement:** _Support iterative data search and previous orders exploration_

**Test Steps:**
```
Ask Claude:
"Search for satellite images of Paris, France from the last 30 days with less than 20% cloud cover"

Then:
"Can you refine that search to only show images from the last 7 days?"

Then:
"Show me my order history"
```

**Expected Result:**
- First search returns available imagery for Paris
- Second search returns refined results (fewer images)
- Third request shows order history with status/type filtering

**Status:** ⬜ Pass / ⬜ Fail

---

### 4. ✅ Task Feasibility Exploration

**P0 Requirement:** _Facilitate task feasibility and pricing exploration_

**Test Steps:**
```
Ask Claude:
"Can SkyFi capture new optical imagery of the Golden Gate Bridge in San Francisco?
Check if it's feasible and tell me how much it would cost."
```

**Expected Result:**
- Claude calls check_feasibility with coordinates
- Returns success probability and satellite pass times
- Calls get_price_estimate
- Returns detailed cost breakdown (base price, area cost, priority fee)

**Status:** ⬜ Pass / ⬜ Fail

---

### 5. ✅ Check Order Feasibility Before Placement

**P0 Requirement:** _Check order feasibility and report to users before placement_

**Test Steps:**
```
Ask Claude:
"I want to order new SAR imagery of Tokyo. First check if it's possible."
```

**Expected Result:**
- Claude converts "Tokyo" to coordinates via geocoding
- Calls check_feasibility for SAR sensor
- Reports feasibility results BEFORE offering to place order
- Shows success probability and pass times

**Status:** ⬜ Pass / ⬜ Fail

---

### 6. ✅ Conversational Order Placement with Price Confirmation

**P0 Requirement:** _Enable conversational order placement with price confirmation_

**Test Steps:**
```
Ask Claude:
"I want to purchase this archive image: img_123"

Wait for price confirmation, then say:
"Yes, please place the order"
```

**Expected Result:**
- Claude calls get_price_estimate FIRST
- Shows price breakdown and asks for confirmation
- Waits for user approval
- Only places order after explicit confirmation
- Returns order ID and status

**Safety Check:** Try ordering without confirmation - Claude should refuse

**Status:** ⬜ Pass / ⬜ Fail

---

### 7. ✅ AOI Monitoring Setup

**P0 Requirement:** _Enable AOI monitoring setup and notifications via webhooks_

**Test Steps:**
```
1. Go to https://webhook.site and copy your unique webhook URL

2. Ask Claude:
"Set up monitoring for the Eiffel Tower in Paris.
Alert me when new imagery is available with less than 30% cloud cover.
Use this webhook: https://webhook.site/YOUR-UNIQUE-ID"
```

**Expected Result:**
- Claude geocodes "Eiffel Tower in Paris"
- Creates monitor with bounding box
- Returns monitor_id and status
- Confirms check interval (default: daily)

**Manual Verification:**
- Check webhook.site for test notifications (may take up to 60 seconds)
- Verify webhook payload includes monitor_id, AOI, criteria, and new_images

**Status:** ⬜ Pass / ⬜ Fail

---

### 8. ✅ Local Server Hosting (stdio)

**P0 Requirement:** _Allow local server hosting_

**Test Steps:**
```
1. Verify server is running locally via stdio transport
2. Check Claude Desktop MCP settings shows skyfi_mcp connected
3. Ask: "What's the status of the MCP server?"
```

**Expected Result:**
- Server responds via stdio (not HTTP)
- Claude can communicate locally without network requests
- Tools execute successfully

**Status:** ⬜ Pass / ⬜ Fail

---

### 9. ✅ Stateless HTTP + SSE Communication

**P0 Requirement:** _Stateless HTTP + SSE communication_

**Test Steps:**
```
1. Start server: mix phx.server
2. Visit http://localhost:4000/mcp/sse in browser
3. Verify response headers:
   - content-type: text/event-stream
   - cache-control: no-cache
   - connection: keep-alive
```

**Expected Result:**
- SSE endpoint returns proper headers
- Connection stays open for streaming
- Test environment returns immediately (no hang)

**Status:** ⬜ Pass / ⬜ Fail

---

### 10. ✅ Authentication Support

**P0 Requirement:** _Ensure authentication and payment support_

**Test Steps:**
```
1. Test with invalid API key:
   - Set SKYFI_API_KEY=invalid_key
   - Ask Claude to search for imagery

2. Test with valid API key:
   - Set correct SKYFI_API_KEY
   - Ask Claude to search for imagery
```

**Expected Result:**
- Invalid key: Clear error message about authentication
- Valid key: Successful API calls
- No API keys visible in logs or error messages
- Monitor API keys stored as SHA256 hash in database

**Status:** ⬜ Pass / ⬜ Fail

---

## End-to-End Workflow Test

**Complete User Journey:**

```
1. "Find satellite images of the Amazon rainforest from the last month"
   → Verifies: geocoding + search_archive

2. "Can you get new high-resolution imagery of the deforestation area at coordinates -3.4653, -62.2159?"
   → Verifies: check_feasibility + get_price_estimate

3. "How much would that cost?"
   → Verifies: pricing with tasking parameters

4. "Set up monitoring for this area and alert me when new images are available at https://webhook.site/YOUR-ID"
   → Verifies: setup_monitor + geocoding

5. "Show me my recent orders"
   → Verifies: list_orders with filtering

6. "What was the location of my last order?"
   → Verifies: reverse_geocode from order coordinates
```

**Expected Flow:**
- All tools execute in correct order
- Context is maintained across conversation
- Claude provides natural, helpful responses
- No errors or unexpected behavior

**Status:** ⬜ Pass / ⬜ Fail

---

## Performance & Quality Checks

### Response Times
- [ ] Tool calls complete within 5 seconds
- [ ] Geocoding responds within 2 seconds
- [ ] No rate limit errors (OSM: 1 req/sec respected)

### Error Handling
- [ ] Invalid coordinates return helpful error
- [ ] Missing parameters show clear guidance
- [ ] Network errors provide retry suggestions
- [ ] API errors don't expose sensitive data

### Safety Features
- [ ] Price confirmation required before orders
- [ ] High-value orders ($500+) require approval flag
- [ ] API keys never appear in logs
- [ ] Webhook URLs validated (HTTP/HTTPS only)

---

## Test Results Summary

**Total Tests:** 10 required + 1 end-to-end
**Passed:** ___
**Failed:** ___
**Blocked:** ___

**P0 Requirements Coverage:** ___/10 (100% required)

**Critical Issues Found:**
```
(List any blocking issues here)
```

**Notes:**
```
(Add any observations or feedback here)
```

---

## Quick Verification Commands

```bash
# Verify server starts
mix phx.server

# Run all tests
mix test

# Check migrations
mix ecto.migrations

# View logs
tail -f log/dev.log

# Test webhook delivery (in IEx)
iex -S mix phx.server
SkyfiMcp.Monitoring.MonitorWorker.status()
```

---

**Tester Name:** _______________
**Date:** _______________
**Server Version:** v0.1.0
**Test Environment:** Local / Staging / Production
**Claude Desktop Version:** _______________

---

## Tips for Testing

1. **Use webhook.site** for real-time webhook monitoring
2. **Enable verbose logging** to see tool calls: `LOG_LEVEL=debug`
3. **Check the database** to verify monitors: `sqlite3 skyfi_mcp_dev.db "SELECT * FROM monitors;"`
4. **Test edge cases** like invalid coordinates, missing parameters, etc.
5. **Verify security** by checking logs don't contain API keys

**Happy Testing! 🚀**
