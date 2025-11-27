# SkyFi MCP Server

> **AI-native access to satellite imagery through the Model Context Protocol**

SkyFi MCP is a standardized interface that enables autonomous AI agents (Claude, GPT, etc.) to discover, task, and purchase geospatial data directly from SkyFi's platform. By implementing the [Model Context Protocol (MCP)](https://modelcontextprotocol.io/), this server transforms SkyFi into an "agent-ready" ecosystem for the emerging AI economy.

## Quick Start

The easiest way to use SkyFi MCP is via **npx** (no installation required) or by connecting directly to a **hosted server**.

### Prerequisites

You'll need:
1. **Node.js** (for npx) OR an MCP client that supports HTTP/SSE
2. **SkyFi API Key** - Sign up at [skyfi.com](https://www.skyfi.com) and get your API key
3. **MCP Access Key** (for remote servers) - Request from your server administrator

### Option 1: npx (Recommended)

Connect to a remote SkyFi MCP server with zero installation:

```bash
npx skyfi-mcp-client \
  --server https://your-server.fly.dev \
  --access-key sk_mcp_your_access_key \
  --api-key your_skyfi_api_key
```

### Option 2: HTTP Transport

For MCP clients that support HTTP, connect directly:

```
URL: https://your-server.fly.dev/mcp/message
Headers:
  Authorization: Bearer sk_mcp_your_access_key
  X-SkyFi-API-Key: your_skyfi_api_key
```

### Option 3: SSE Transport

For real-time streaming connections:

```
URL: https://your-server.fly.dev/mcp/sse
Headers:
  Authorization: Bearer sk_mcp_your_access_key
  X-SkyFi-API-Key: your_skyfi_api_key
```

---

## AI Client Configuration

### Claude Desktop

Edit your MCP settings file:
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "skyfi": {
      "command": "npx",
      "args": [
        "skyfi-mcp-client",
        "--server", "https://your-deployment.fly.dev",
        "--access-key", "sk_mcp_your_access_key",
        "--api-key", "your_skyfi_api_key"
      ]
    }
  }
}
```

### Claude Code

Add to `.mcp.json` in your project root or `~/.claude/mcp.json`:

```json
{
  "mcpServers": {
    "skyfi": {
      "command": "npx",
      "args": ["-y", "skyfi-mcp-client"],
      "env": {
        "SKYFI_MCP_SERVER_URL": "https://your-deployment.fly.dev",
        "SKYFI_MCP_ACCESS_KEY": "sk_mcp_your_access_key",
        "SKYFI_API_KEY": "your_skyfi_api_key"
      }
    }
  }
}
```

### Codex

Add to `.codex/mcp.json` or `~/.codex/mcp.json`:

```json
{
  "mcpServers": {
    "skyfi": {
      "command": "npx",
      "args": [
        "-y", "skyfi-mcp-client",
        "--server", "https://your-deployment.fly.dev",
        "--access-key", "sk_mcp_your_access_key",
        "--api-key", "your_skyfi_api_key"
      ]
    }
  }
}
```

### OpenCode

Add to `~/.config/opencode/config.json`:

```json
{
  "mcp": {
    "servers": {
      "skyfi": {
        "type": "http",
        "url": "https://your-deployment.fly.dev/mcp/message",
        "headers": {
          "Authorization": "Bearer sk_mcp_your_access_key",
          "X-SkyFi-API-Key": "your_skyfi_api_key"
        },
        "enabled": true
      }
    }
  }
}
```

---

## Features

- **Search Archive**: Find existing satellite imagery by location, date, and cloud cover
- **Check Feasibility**: Determine if new imagery can be captured for a specific area
- **Price Estimates**: Get cost breakdowns for archive downloads or tasking orders
- **Place Orders**: Purchase imagery with built-in safety confirmations
- **List Orders**: View and filter your order history with pagination support
- **Geocoding**: Convert location names to coordinates (e.g., "San Francisco" → lat/lon)
- **Reverse Geocoding**: Convert coordinates to location names
- **AOI Monitoring**: Set up automated alerts when new imagery becomes available
- **Webhook Notifications**: Receive real-time updates about imagery availability

---

## Transport Comparison

| Transport | Best For | Requirements |
|-----------|----------|--------------|
| **npx bridge** | Most users | Node.js |
| **HTTP** | Firewalls, debugging | HTTP client support |
| **SSE** | Real-time updates | SSE client support |
| **stdio (local)** | Development | Elixir runtime |

---

## Demo & Examples

### Interactive Python Demo

```bash
cd examples
pip install -r requirements.txt
python demo_agent.py
```

### Quick Example with Claude

```
You: "Find satellite images of the Amazon rainforest from last month with less than 20% cloud cover"

Claude: [Uses geocode + search_archive tools]
        I found 12 satellite images of the Amazon rainforest...
```

See `examples/README.md` for complete documentation.

---

## Deploying Your Own Server

### Fly.io (Recommended)

1. **Install Fly CLI and login:**
   ```bash
   curl -L https://fly.io/install.sh | sh
   fly auth login
   ```

2. **Launch and configure:**
   ```bash
   fly launch
   fly volumes create data --size 1 --region <your-region>
   fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
   fly deploy
   fly ssh console -C "/app/bin/skyfi_mcp eval 'SkyfiMcp.Release.migrate'"
   ```

3. **Create access keys for users:**
   ```bash
   mix skyfi.access.create user@example.com "User Name"
   ```

### Docker

```bash
docker build -t skyfi-mcp .
docker run -p 4000:4000 \
  -e SECRET_KEY_BASE=$(mix phx.gen.secret) \
  -v $(pwd)/data:/data \
  skyfi-mcp
```

---

## Admin: Managing Access Keys

```bash
# Create access key
mix skyfi.access.create user@example.com "Description"

# List all keys
mix skyfi.access.list

# View stats
mix skyfi.access.stats sk_mcp_abc123...

# Revoke access
mix skyfi.access.revoke sk_mcp_abc123...
```

---

## Local Development (Elixir)

For contributors or those running the server locally.

### Prerequisites

- **Elixir** 1.15+ ([installation guide](https://elixir-lang.org/install.html))
- **Erlang/OTP** 25+

```bash
elixir --version  # Verify installation
```

### Installation

```bash
# Install dependencies
mix deps.get

# Run migrations
mix ecto.migrate

# Verify
mix test  # Should show: 82 tests, 0 failures
```

### Configuration

Create a `.env` file:

```bash
SKYFI_API_KEY=your_skyfi_api_key_here
SECRET_KEY_BASE=your_secret_key_here  # Generate with: mix phx.gen.secret
```

### Running Locally

```bash
# Development server
mix phx.server

# Or with IEx for debugging
iex -S mix phx.server
```

Server available at `http://localhost:4000`.

### Claude Desktop (Local)

```json
{
  "mcpServers": {
    "skyfi": {
      "command": "mix",
      "args": ["skyfi_mcp.stdio"],
      "cwd": "/path/to/skyfi_mcp",
      "env": {
        "SKYFI_API_KEY": "your_api_key"
      }
    }
  }
}
```

### Running Tests

```bash
mix test              # All tests
mix test --cover      # With coverage
mix precommit         # Full quality checks
```

### Project Structure

```
lib/
├── skyfi_mcp/           # Core business logic
│   ├── mcp_protocol/    # JSON-RPC & MCP handlers
│   ├── skyfi_client/    # HTTP client for SkyFi API
│   └── tools/           # MCP tool implementations
└── skyfi_mcp_web/       # Web layer (SSE, HTTP endpoints)

config/                  # Environment configurations
priv/repo/migrations/    # Database migrations
test/                    # Test suite
```

---

## Resources

- [MCP Specification](https://modelcontextprotocol.io/)
- [SkyFi API Documentation](https://docs.skyfi.com)
- [Phoenix Framework](https://hexdocs.pm/phoenix)
- [Get SkyFi API Key](https://www.skyfi.com/settings/api)

---

## License

_(To be determined)_

## Support

- Open an issue on GitHub
- Contact SkyFi support at support@skyfi.com

---

**Status**: ✅ Production Ready

Built with [Phoenix Framework](https://phoenixframework.org) and [Elixir](https://elixir-lang.org)
