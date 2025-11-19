# SkyFi MCP Client - Setup Complete! ✅

## Overview

The SkyFi MCP client has been successfully configured for **all three environments**:
- ✅ Claude Code (this project)
- ✅ Claude Desktop
- ✅ OpenCode

## Credentials

- **Server URL**: `https://skyfi-mcp.fly.dev`
- **Access Key**: `sk_mcp_9a7312e31449dea2cd075997284c6f6b6261c0abebad48adc62a66bcd3e48aba`
- **SkyFi API Key**: `YOUR_SKYFI_API_KEY_HERE`

## Configuration Files

### 1. Claude Code (This Project)
**File**: `/Users/reuben/gauntlet/skyfi_mcp/.mcp.json`

```json
{
  "mcpServers": {
    "skyfi": {
      "command": "skyfi-mcp",
      "args": [
        "-s", "https://skyfi-mcp.fly.dev",
        "-a", "sk_mcp_9a7312e31449dea2cd075997284c6f6b6261c0abebad48adc62a66bcd3e48aba",
        "-k", "YOUR_SKYFI_API_KEY_HERE"
      ]
    }
  }
}
```

**To use in this Claude Code session**: Restart Claude Code to load the MCP server.

### 2. Claude Desktop
**File**: `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "skyfi": {
      "command": "skyfi-mcp",
      "args": [
        "-s", "https://skyfi-mcp.fly.dev",
        "-a", "sk_mcp_9a7312e31449dea2cd075997284c6f6b6261c0abebad48adc62a66bcd3e48aba",
        "-k", "YOUR_SKYFI_API_KEY_HERE"
      ]
    }
  }
}
```

**To use**: Restart Claude Desktop app. You should see the SkyFi tools available in the app.

### 3. OpenCode
**File**: `~/.config/opencode/opencode.json`

```json
{
  "mcp": {
    "skyfi": {
      "type": "local",
      "command": [
        "skyfi-mcp",
        "-s", "https://skyfi-mcp.fly.dev",
        "-a", "sk_mcp_9a7312e31449dea2cd075997284c6f6b6261c0abebad48adc62a66bcd3e48aba",
        "-k", "YOUR_SKYFI_API_KEY_HERE"
      ],
      "enabled": true
    }
  }
}
```

**To use**: Restart OpenCode. The SkyFi MCP server will be available.

## Available Tools

Once connected, you'll have access to these SkyFi MCP tools:

1. **search_archive** - Find existing satellite imagery
2. **check_feasibility** - Check if new imagery can be captured
3. **get_price_estimate** - Get cost estimates for orders
4. **place_order** - Purchase imagery with safety confirmations
5. **list_orders** - View order history with pagination
6. **geocode** - Convert location names to coordinates
7. **reverse_geocode** - Convert coordinates to location names
8. **setup_monitor** - Set up automated alerts for new imagery

## Testing the Connection

To verify the setup works, try asking in any of the three environments:

```
"Search for satellite images of San Francisco from the last month with less than 20% cloud cover"
```

The AI should use the `geocode` and `search_archive` tools to fulfill your request.

## Manual Testing (Command Line)

You can also test the client manually:

```bash
# Using the globally linked command
skyfi-mcp \
  -s https://skyfi-mcp.fly.dev \
  -a sk_mcp_9a7312e31449dea2cd075997284c6f6b6261c0abebad48adc62a66bcd3e48aba \
  -k YOUR_SKYFI_API_KEY_HERE \
  --debug

# Then type JSON-RPC requests:
{"jsonrpc":"2.0","method":"tools/list","params":{},"id":1}
```

## Environment Variables (Alternative)

If you prefer using environment variables, add to your shell profile:

```bash
export SKYFI_MCP_SERVER_URL="https://skyfi-mcp.fly.dev"
export SKYFI_MCP_ACCESS_KEY="sk_mcp_9a7312e31449dea2cd075997284c6f6b6261c0abebad48adc62a66bcd3e48aba"
export SKYFI_API_KEY="YOUR_SKYFI_API_KEY_HERE"

# Then simply run:
skyfi-mcp
```

## Troubleshooting

### "Command not found: skyfi-mcp"

The package might not be linked correctly. Run:
```bash
cd /Users/reuben/gauntlet/skyfi_mcp/npm-bridge
npm link
which skyfi-mcp  # Should show: /opt/homebrew/bin/skyfi-mcp
```

### "401 Unauthorized"

Your access key may be invalid or expired. Contact the SkyFi MCP server admin for a new key.

### "Failed to connect"

Check that the server is running:
```bash
curl https://skyfi-mcp.fly.dev/health
```

Should return:
```json
{"status":"ok","timestamp":"...","version":"0.1.0",...}
```

## Package Information

- **Package Name**: `@skyfi/mcp-client`
- **Version**: 1.0.0
- **Location**: `/Users/reuben/gauntlet/skyfi_mcp/npm-bridge`
- **Binary**: `/opt/homebrew/bin/skyfi-mcp` (globally linked)

## Next Steps

1. **Restart Claude Desktop** to load the MCP server
2. **Restart OpenCode** to load the MCP server
3. **Restart Claude Code** (if needed) to refresh MCP connections
4. **Test with a query** like "Find satellite images of Tokyo"

---

**Setup completed**: 2025-11-18
**Server status**: ✅ Running at https://skyfi-mcp.fly.dev
