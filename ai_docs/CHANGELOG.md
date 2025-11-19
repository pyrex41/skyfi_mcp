# Changelog

All notable changes to the SkyFi MCP project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-11-18

### Added
- **MCP Server Implementation**
  - stdio transport for local Claude Desktop integration
  - SSE transport for remote server deployment
  - Full JSON-RPC 2.0 support
  - Tool registry with 8 complete tools

- **SkyFi API Tools**
  - `search_archive` - Search existing satellite imagery
  - `check_feasibility` - Check satellite tasking feasibility
  - `get_price_estimate` - Get pricing for archive or tasking
  - `place_order` - Place satellite imagery orders (with safety features)
  - `list_orders` - List order history with filtering

- **Geocoding Tools**
  - `geocode` - Convert location names to coordinates via OpenStreetMap
  - `reverse_geocode` - Convert coordinates to location names
  - Rate limiting (1 req/sec) to respect OSM Terms of Service
  - ETS-based caching with 24-hour TTL

- **Monitoring System**
  - `setup_monitor` - Set up AOI monitoring with webhook notifications
  - Background worker (MonitorWorker GenServer) checking every 60 seconds
  - Webhook delivery with exponential backoff retry (3 attempts)
  - SQLite3 database for persistent monitor storage
  - SHA256 hashing of API keys (never stores plaintext)

- **Safety Features**
  - Price confirmation required for orders
  - High-value order approval ($500+ threshold)
  - Comprehensive logging for all critical operations
  - Input validation with user-friendly error messages

- **Infrastructure**
  - Phoenix 1.8.1 framework (API-only mode)
  - Ecto with SQLite3 adapter (zero-config deployment)
  - Tesla HTTP client with middleware composition
  - Comprehensive test suite (82 tests, 100% passing)

### Security
- API keys hashed with SHA256 before database storage
- No API keys logged in any error messages or logs
- Webhook URL validation
- Secure environment variable handling

### Technical Details
- **Lines of Code**: ~2,650 production, ~1,025 tests
- **Test Coverage**: 82/82 tests passing (100%)
- **Dependencies**: 41 packages, all audited (no vulnerabilities)
- **Database**: SQLite3 with Ecto migrations
- **Deployment Ready**: Configured for Fly.io deployment

---

## [Unreleased]

### Planned
- Docker deployment configuration
- Enhanced error handling across all tools
- Telemetry and monitoring instrumentation
- Demo agent / reference implementation
- Comprehensive API documentation
- Load testing and performance optimization

---

[0.1.0]: https://github.com/yourusername/skyfi_mcp/releases/tag/v0.1.0
