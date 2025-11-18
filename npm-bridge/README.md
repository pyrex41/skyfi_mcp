# @skyfi/mcp-client

> Bridge client for connecting to remote SkyFi MCP servers

This npm package allows you to connect to a remotely deployed SkyFi MCP server without needing Elixir or Mix installed locally. It acts as a bridge between the MCP stdio protocol (used by Claude Desktop and other MCP clients) and the HTTP API of your deployed SkyFi MCP server.

## Features

- 🚀 **Zero Setup** - No Elixir or Mix required
- 🔒 **Secure** - Uses access keys + SkyFi API keys for authentication
- 🌐 **Remote** - Connect to any deployed SkyFi MCP server
- 📦 **Lightweight** - Minimal dependencies
- 🔌 **MCP Compatible** - Works with Claude Desktop and other MCP clients

## Installation

### Quick Start (No Installation)

Use npx to run directly:

```bash
npx @skyfi/mcp-client \
  --server https://your-server.fly.dev \
  --access-key sk_mcp_abc123... \
  --api-key skyfi_xyz789...
```

### Global Installation

```bash
npm install -g @skyfi/mcp-client
```

### Local Installation

```bash
npm install @skyfi/mcp-client
```

## Usage

### Command Line

```bash
skyfi-mcp \
  --server https://skyfi-mcp.fly.dev \
  --access-key sk_mcp_abc123... \
  --api-key skyfi_xyz789...
```

### With Environment Variables

```bash
export SKYFI_MCP_SERVER_URL=https://skyfi-mcp.fly.dev
export SKYFI_MCP_ACCESS_KEY=sk_mcp_abc123...
export SKYFI_API_KEY=skyfi_xyz789...

skyfi-mcp
```

### Claude Desktop Configuration

Add to your Claude Desktop config file:

**macOS/Linux**: `~/.claude/config.json`
**Windows**: `%APPDATA%\Claude\config.json`

#### Option 1: Command-line arguments

```json
{
  "mcpServers": {
    "skyfi": {
      "command": "npx",
      "args": [
        "@skyfi/mcp-client",
        "--server", "https://skyfi-mcp.fly.dev",
        "--access-key", "sk_mcp_abc123...",
        "--api-key", "skyfi_xyz789..."
      ]
    }
  }
}
```

#### Option 2: Environment variables (recommended for security)

```json
{
  "mcpServers": {
    "skyfi": {
      "command": "npx",
      "args": ["@skyfi/mcp-client"],
      "env": {
        "SKYFI_MCP_SERVER_URL": "https://skyfi-mcp.fly.dev",
        "SKYFI_MCP_ACCESS_KEY": "sk_mcp_abc123...",
        "SKYFI_API_KEY": "skyfi_xyz789..."
      }
    }
  }
}
```

#### Option 3: Using globally installed package

```json
{
  "mcpServers": {
    "skyfi": {
      "command": "skyfi-mcp",
      "args": [
        "--server", "https://skyfi-mcp.fly.dev",
        "--access-key", "sk_mcp_abc123...",
        "--api-key", "skyfi_xyz789..."
      ]
    }
  }
}
```

## Configuration

### Required Credentials

You need **TWO** credentials to use this client:

1. **MCP Access Key** (`sk_mcp_...`)
   - Validates that you have permission to use the MCP server
   - Obtained from your SkyFi MCP server administrator
   - Created via: `fly ssh console` then run access key generation command

2. **SkyFi API Key**
   - Your personal SkyFi API key for satellite imagery requests
   - Get yours at: https://app.skyfi.com/settings/api

### Command-Line Options

```
-s, --server <url>       Server URL (required)
-a, --access-key <key>   MCP access key (required)
-k, --api-key <key>      SkyFi API key (required)
-d, --debug              Enable debug logging
-h, --help               Show help message
```

### Environment Variables

- `SKYFI_MCP_SERVER_URL` - Server URL
- `SKYFI_MCP_ACCESS_KEY` - MCP access key
- `SKYFI_API_KEY` - SkyFi API key

## How It Works

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   Claude    │ stdio   │ npm-bridge   │  HTTP   │   Remote    │
│   Desktop   │◄───────►│  (this pkg)  │◄───────►│ MCP Server  │
└─────────────┘         └──────────────┘         └─────────────┘
                              │                          │
                              │                          │
                         JSON-RPC                   Elixir/Phoenix
                         over stdio                 on Fly.io
```

This package:
1. Receives MCP messages over stdio (from Claude Desktop)
2. Forwards them to your remote server via HTTP
3. Returns responses back over stdio

## Available Tools

Once connected, you'll have access to these SkyFi MCP tools:

- `skyfi_search_aoi` - Search for imagery in an area of interest
- `skyfi_place_order` - Place an order for satellite imagery
- `skyfi_get_order_status` - Check order status
- `skyfi_list_orders` - List your recent orders
- `skyfi_geocode_address` - Convert address to coordinates
- `skyfi_reverse_geocode` - Convert coordinates to address

## Programmatic Usage

You can also use this package as a library in your Node.js application:

```typescript
import { SkyFiMcpClient } from '@skyfi/mcp-client';

const client = new SkyFiMcpClient({
  serverUrl: 'https://skyfi-mcp.fly.dev',
  accessKey: 'sk_mcp_abc123...',
  skyfiApiKey: 'skyfi_xyz789...',
  debug: false,
});

// Connect
await client.connect();

// Send a request
const response = await client.sendRequest({
  jsonrpc: '2.0',
  method: 'tools/list',
  id: 1,
});

console.log(response);

// Disconnect
client.disconnect();
```

## Troubleshooting

### Connection Issues

Enable debug mode to see detailed logs:

```bash
skyfi-mcp --debug \
  --server https://skyfi-mcp.fly.dev \
  --access-key sk_mcp_... \
  --api-key skyfi_...
```

### Authentication Errors

- **401 Unauthorized**: Check your MCP access key
- **400 Bad Request**: Check your SkyFi API key
- **403 Forbidden**: Your access key may be revoked or inactive

### Claude Desktop Integration

1. Make sure the config file is valid JSON
2. Restart Claude Desktop after config changes
3. Check Claude Desktop logs for errors

## Getting Credentials

### MCP Access Key

Contact your SkyFi MCP server administrator to get an access key. If you're running your own server:

```bash
# SSH into your Fly.io deployment
fly ssh console

# Generate a new access key
/app/bin/skyfi_mcp rpc "SkyfiMcp.AccessKey.create(\"you@example.com\", \"Description\")"
```

### SkyFi API Key

1. Go to https://app.skyfi.com/settings/api
2. Create a new API key
3. Copy and save it securely

## Security Best Practices

1. **Never commit credentials** to version control
2. **Use environment variables** instead of command-line args when possible
3. **Rotate access keys** periodically
4. **Revoke unused keys** via your server administrator
5. **Use separate API keys** for different applications

## Development

### Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/skyfi_mcp.git
cd skyfi_mcp/npm-bridge

# Install dependencies
npm install

# Build
npm run build

# Test locally
node dist/cli.js --help
```

### Testing

```bash
# Test with a deployed server
npm run build
echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | \
  node dist/cli.js \
    --server https://skyfi-mcp.fly.dev \
    --access-key sk_mcp_... \
    --api-key skyfi_...
```

## Related Projects

- [SkyFi MCP Server](../) - The Elixir server this client connects to
- [Model Context Protocol](https://modelcontextprotocol.io/) - MCP specification
- [Claude Desktop](https://claude.ai/download) - Claude desktop app with MCP support

## Support

- **Issues**: https://github.com/yourusername/skyfi_mcp/issues
- **Documentation**: https://github.com/yourusername/skyfi_mcp
- **SkyFi Support**: support@skyfi.com

## License

MIT
