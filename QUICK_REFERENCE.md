# SkyFi MCP - Quick Reference Card

## 🎯 Quick Start

The SkyFi MCP client is now installed and configured for all your AI environments!

### Try It Now

In **Claude Desktop**, **Claude Code**, or **OpenCode**, ask:

```
"Find satellite images of Central Park, New York from the last week"
```

The AI will automatically use the SkyFi tools to:
1. Geocode "Central Park, New York" → coordinates
2. Search the archive for recent imagery
3. Show you results with cloud cover, resolution, and pricing

## 🔧 Installation Status

✅ **Built**: `/Users/reuben/gauntlet/skyfi_mcp/npm-bridge`
✅ **Linked**: `/opt/homebrew/bin/skyfi-mcp`
✅ **Server**: `https://skyfi-mcp.fly.dev` (online)

## 📱 Configured Environments

| Environment | Config File | Status |
|------------|-------------|--------|
| **Claude Code** | `.mcp.json` (this project) | ✅ Ready |
| **Claude Desktop** | `~/Library/Application Support/Claude/claude_desktop_config.json` | ✅ Ready |
| **OpenCode** | `~/.config/opencode/opencode.json` | ✅ Ready |

## 🛠️ Available Tools

| Tool | Description | Example |
|------|-------------|---------|
| `search_archive` | Find existing imagery | "Show me satellite images of Tokyo" |
| `check_feasibility` | Can new imagery be captured? | "Can you capture imagery of Paris tomorrow?" |
| `get_price_estimate` | Cost for new imagery | "How much to order 0.5m imagery of Dubai?" |
| `place_order` | Purchase imagery | "Order that imagery for me" |
| `list_orders` | View purchase history | "Show my recent orders" |
| `geocode` | Location → coordinates | "What are the coordinates of London?" |
| `reverse_geocode` | Coordinates → location | "What location is at 37.7749, -122.4194?" |
| `setup_monitor` | Automated alerts | "Alert me when new imagery is available for SF" |

## 💬 Example Queries

### Search for Imagery
```
"Find high-resolution satellite images of the Amazon rainforest
from October 2024 with less than 15% cloud cover"
```

### Check Feasibility
```
"Can I get new satellite imagery of the Grand Canyon captured
in the next 3 days with 0.5m resolution?"
```

### Price Check
```
"How much would it cost to order 1m resolution imagery of
downtown Manhattan covering a 5km x 5km area?"
```

### Monitoring
```
"Set up an alert for when new clear imagery of San Francisco
becomes available (less than 10% cloud cover)"
```

## 🔑 Credentials

**Server**: `https://skyfi-mcp.fly.dev`
**Access Key**: `sk_mcp_9a7...` (saved in configs)
**API Key**: `053eef...` (saved in configs)

## 🚀 Manual Testing

Test the client directly from the command line:

```bash
skyfi-mcp \
  -s https://skyfi-mcp.fly.dev \
  -a sk_mcp_9a7312e31449dea2cd075997284c6f6b6261c0abebad48adc62a66bcd3e48aba \
  -k 053eef6dc8b849358eedaacd5bdd1b8d \
  --debug
```

Then send a JSON-RPC request:
```json
{"jsonrpc":"2.0","method":"tools/list","params":{},"id":1}
```

## 📊 Server Health

Check server status anytime:
```bash
curl https://skyfi-mcp.fly.dev/health
```

Expected response:
```json
{
  "status": "ok",
  "timestamp": "2025-11-19T...",
  "version": "0.1.0",
  "database": "connected",
  "mcp_protocol": "2024-11-05"
}
```

## 🔄 Restart Instructions

After any config changes:

- **Claude Desktop**: Quit and restart the app
- **Claude Code**: Run `/clear` or restart the session
- **OpenCode**: Restart the application

## 📝 Files Modified

```
✅ /Users/reuben/gauntlet/skyfi_mcp/.mcp.json
✅ ~/Library/Application Support/Claude/claude_desktop_config.json
✅ ~/.config/opencode/opencode.json
```

## 🆘 Troubleshooting

### Issue: Tools not showing up

**Solution**: Restart the AI environment completely

### Issue: "401 Unauthorized"

**Solution**: Access key may be invalid. Check server logs:
```bash
fly logs -a skyfi-mcp
```

### Issue: "Connection failed"

**Solution**: Verify server is running:
```bash
fly status -a skyfi-mcp
```

## 📚 More Info

- **Full Setup Guide**: `SETUP_COMPLETE.md`
- **Project README**: `README.md`
- **Examples**: `EXAMPLES.md`
- **npm Package**: `/Users/reuben/gauntlet/skyfi_mcp/npm-bridge`

---

**Last Updated**: 2025-11-18
**Version**: 1.0.0
