# SkyFi MCP Server

> **AI-native access to satellite imagery through the Model Context Protocol**

SkyFi MCP is a standardized interface that enables autonomous AI agents (Claude, GPT, etc.) to discover, task, and purchase geospatial data directly from SkyFi's platform. By implementing the [Model Context Protocol (MCP)](https://modelcontextprotocol.io/), this server transforms SkyFi into an "agent-ready" ecosystem for the emerging AI economy.

## What is MCP?

The Model Context Protocol is an open standard that allows AI applications to securely connect to external data sources and tools. Think of it as a universal adapter that lets AI agents interact with services like SkyFi through a consistent, discoverable interface.

## Features

### ✅ Available Now

- **Search Archive**: Find existing satellite imagery by location, date, and cloud cover
- **Check Feasibility**: Determine if new imagery can be captured for a specific area
- **Price Estimates**: Get cost breakdowns for archive downloads or tasking orders
- **Place Orders**: Purchase imagery with built-in safety confirmations
- **List Orders**: View and filter your order history with pagination support
- **Geocoding**: Convert location names to coordinates (e.g., "San Francisco" → lat/lon)
- **Reverse Geocoding**: Convert coordinates to location names (e.g., lat/lon → "San Francisco, California")

### 🚧 In Development

- **AOI Monitoring**: Set up automated alerts when new imagery becomes available
- **Webhook Notifications**: Receive real-time updates about imagery availability

## Prerequisites

Before you begin, ensure you have the following installed:

- **Elixir** 1.15 or later ([installation guide](https://elixir-lang.org/install.html))
- **Erlang/OTP** 25 or later (usually installed with Elixir)
- **PostgreSQL** 14 or later ([download](https://www.postgresql.org/download/))
- **SkyFi API Key** - Sign up at [skyfi.com](https://www.skyfi.com) and get your Gold tier API key

Check your versions:
```bash
elixir --version  # Should show Elixir 1.15+ and Erlang/OTP 25+
psql --version    # Should show PostgreSQL 14+
```

## Installation

1. **Clone or navigate to the project directory:**
   ```bash
   cd /path/to/skyfi_mcp
   ```

2. **Install dependencies:**
   ```bash
   mix deps.get
   ```

3. **Set up your database:**
   ```bash
   mix ecto.create
   ```

4. **Verify the installation:**
   ```bash
   mix compile
   mix test
   ```

## Configuration

### Environment Variables

Create a `.env` file in the project root (this file is gitignored):

```bash
# SkyFi API Configuration
SKYFI_API_KEY=your_skyfi_api_key_here

# Database Configuration (optional, defaults work for local dev)
DATABASE_URL=postgresql://postgres:postgres@localhost/skyfi_mcp_dev

# Server Configuration
PHX_HOST=localhost
PORT=4000
SECRET_KEY_BASE=your_secret_key_here  # Generate with: mix phx.gen.secret
```

### Generate Secret Key

```bash
mix phx.gen.secret
```

Copy the output to your `.env` file as `SECRET_KEY_BASE`.

### Database Configuration

Edit `config/dev.exs` if you need to customize database settings:

```elixir
config :skyfi_mcp, SkyfiMcp.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "skyfi_mcp_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```

## Running the Server

### Development Mode

Start the Phoenix server in development:

```bash
mix phx.server
```

Or run it inside IEx (Interactive Elixir) for debugging:

```bash
iex -S mix phx.server
```

The server will be available at `http://localhost:4000`.

### Running Tests

```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover

# Run specific test file
mix test test/skyfi_mcp/specific_test.exs
```

## Project Structure

```
lib/
├── skyfi_mcp/                 # Core business logic
│   ├── application.ex          # OTP application setup
│   ├── repo.ex                 # Database repository
│   ├── mcp_protocol/           # (TODO) JSON-RPC & MCP handlers
│   ├── skyfi_client/           # (TODO) Tesla HTTP client for SkyFi API
│   └── tools/                  # (TODO) MCP tool implementations
│
├── skyfi_mcp_web/             # Web layer
│   ├── endpoint.ex             # HTTP endpoint configuration
│   ├── router.ex               # Route definitions
│   ├── telemetry.ex            # Metrics and monitoring
│   └── controllers/            # (TODO) SSE & API controllers
│
├── skyfi_mcp.ex               # Main application module
└── skyfi_mcp_web.ex           # Web module

config/                         # Environment configurations
├── config.exs                  # Shared config
├── dev.exs                     # Development config
├── test.exs                    # Test config
├── prod.exs                    # Production config
└── runtime.exs                 # Runtime config (reads env vars)

priv/
├── repo/migrations/            # Database migrations
└── static/                     # Static files

test/                           # Test suite
```

## Development Roadmap

### ✅ Phase 1: Foundation (Complete)
- [x] Phoenix project setup
- [x] Basic README and documentation
- [x] SkyFi API client module
- [x] MCP JSON-RPC handler
- [x] stdio transport for local development

### ✅ Phase 2: Core Tools (Complete)
- [x] `search_archive` tool
- [x] `check_feasibility` tool
- [x] `get_price_estimate` tool
- [x] `place_order` tool with safety
- [x] `list_orders` tool
- [x] `geocode` tool (OpenStreetMap integration)
- [x] `reverse_geocode` tool (OpenStreetMap integration)

### 📅 Phase 3: Monitoring & Webhooks (Week 2)
- [ ] AOI monitoring setup
- [ ] Webhook notification system
- [ ] Database schema for monitors
- [ ] Background job processing

### 🚀 Phase 4: Production Ready (Week 3)
- [ ] SSE transport for remote deployment
- [ ] Docker containerization
- [ ] Security audit
- [ ] Error handling & logging
- [ ] Comprehensive documentation

### 🎨 Phase 5: Polish (Week 4)
- [ ] Demo agent with example workflows
- [ ] Telemetry and monitoring dashboards
- [ ] Performance optimization

## Connecting with Claude Desktop

Once the server is running with stdio transport, you can connect it to Claude Desktop:

1. Edit Claude Desktop's MCP settings file:
   - **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

2. Add the SkyFi MCP server:
   ```json
   {
     "mcpServers": {
       "skyfi": {
         "command": "mix",
         "args": ["skyfi_mcp.stdio"],
         "cwd": "/absolute/path/to/skyfi_mcp",
         "env": {
           "SKYFI_API_KEY": "your_api_key_here"
         }
       }
     }
   }
   ```

3. Restart Claude Desktop

You can also test the stdio transport manually:
```bash
# Send a test message
echo '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":1}' | mix skyfi_mcp.stdio
```

## API Documentation

### SkyFi Public API

This server wraps the SkyFi Public API. Key endpoints:

- `POST /archive/search` - Search existing imagery
- `POST /tasking/feasibility` - Check if new capture is possible
- `POST /pricing/estimate` - Get cost estimates
- `POST /orders` - Place an order
- `GET /orders` - List order history

Full API documentation: [SkyFi API Docs](https://docs.skyfi.com)

### MCP Tools Specification

_(Coming soon - see `.taskmaster/docs/missing-features-spec.md` for detailed specifications)_

## Contributing

This project is currently in active development. Contributions are welcome!

### Development Workflow

1. Check the task list: `.taskmaster/tasks/tasks.json`
2. Pick a task and create a branch: `git checkout -b task-N-description`
3. Make your changes with tests
4. Run the precommit checks: `mix precommit`
5. Submit a pull request

### Code Quality

Before committing, run:

```bash
# Format code
mix format

# Run linter
mix compile --warnings-as-errors

# Run all tests
mix test

# Or run the full precommit suite
mix precommit
```

## Troubleshooting

### Database Connection Errors

If you see "connection refused" for PostgreSQL:

```bash
# Check if PostgreSQL is running
pg_isready

# Start PostgreSQL (macOS with Homebrew)
brew services start postgresql@14

# Start PostgreSQL (Linux)
sudo systemctl start postgresql
```

### Port Already in Use

If port 4000 is already taken:

```bash
# Use a different port
PORT=4001 mix phx.server
```

### Dependencies Won't Compile

```bash
# Clean and reinstall
mix deps.clean --all
mix deps.get
mix compile
```

## Resources

### Model Context Protocol
- [MCP Specification](https://modelcontextprotocol.io/)
- [MCP GitHub](https://github.com/modelcontextprotocol)

### Phoenix Framework
- [Phoenix Guides](https://hexdocs.pm/phoenix/overview.html)
- [Phoenix Docs](https://hexdocs.pm/phoenix)
- [Elixir Forum](https://elixirforum.com/c/phoenix-forum)

### SkyFi Platform
- [SkyFi Website](https://www.skyfi.com)
- [SkyFi API Documentation](https://docs.skyfi.com)
- [Get API Key](https://www.skyfi.com/settings/api)

## Project Documentation

- **Tasks**: `.taskmaster/tasks/tasks.json` - Development task list
- **PRD**: `.taskmaster/docs/prd-init.md` - Product requirements document
- **Feature Specs**: `.taskmaster/docs/missing-features-spec.md` - Detailed feature specifications
- **Project Overview**: `project.md` - High-level project goals

## License

_(To be determined)_

## Support

For questions or issues:
- Open an issue on GitHub (coming soon)
- Contact SkyFi support at support@skyfi.com
- Check the Elixir Forum for Phoenix-related questions

---

**Status**: 🚧 In Active Development - Task #2 of 23 Complete

Built with [Phoenix Framework](https://phoenixframework.org) and [Elixir](https://elixir-lang.org)
