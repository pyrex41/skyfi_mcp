#!/usr/bin/env node

import { StdioBridge } from './stdio-bridge';

/**
 * CLI entry point for SkyFi MCP client
 *
 * Usage:
 *   skyfi-mcp --server https://skyfi-mcp.fly.dev --access-key sk_mcp_... --api-key skyfi_...
 *
 * Environment variables:
 *   SKYFI_MCP_SERVER_URL - Server URL
 *   SKYFI_MCP_ACCESS_KEY - MCP access key
 *   SKYFI_API_KEY - SkyFi API key
 */

function parseArgs() {
  const args = process.argv.slice(2);
  const config = {
    serverUrl: process.env.SKYFI_MCP_SERVER_URL || '',
    accessKey: process.env.SKYFI_MCP_ACCESS_KEY || '',
    skyfiApiKey: process.env.SKYFI_API_KEY || '',
    debug: false,
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    switch (arg) {
      case '--server':
      case '-s':
        config.serverUrl = args[++i];
        break;

      case '--access-key':
      case '-a':
        config.accessKey = args[++i];
        break;

      case '--api-key':
      case '-k':
        config.skyfiApiKey = args[++i];
        break;

      case '--debug':
      case '-d':
        config.debug = true;
        break;

      case '--help':
      case '-h':
        showHelp();
        process.exit(0);
        break;

      default:
        console.error(`Unknown argument: ${arg}`);
        showHelp();
        process.exit(1);
    }
  }

  // Validate required config
  if (!config.serverUrl) {
    console.error('Error: Server URL is required (--server or SKYFI_MCP_SERVER_URL)');
    showHelp();
    process.exit(1);
  }

  if (!config.accessKey) {
    console.error('Error: Access key is required (--access-key or SKYFI_MCP_ACCESS_KEY)');
    showHelp();
    process.exit(1);
  }

  if (!config.skyfiApiKey) {
    console.error('Error: SkyFi API key is required (--api-key or SKYFI_API_KEY)');
    showHelp();
    process.exit(1);
  }

  return config;
}

function showHelp() {
  console.error(`
SkyFi MCP Client - Bridge to remote SkyFi MCP server

USAGE:
  skyfi-mcp [OPTIONS]

OPTIONS:
  -s, --server <url>       Server URL (required)
  -a, --access-key <key>   MCP access key (required)
  -k, --api-key <key>      SkyFi API key (required)
  -d, --debug              Enable debug logging
  -h, --help               Show this help message

ENVIRONMENT VARIABLES:
  SKYFI_MCP_SERVER_URL     Server URL
  SKYFI_MCP_ACCESS_KEY     MCP access key
  SKYFI_API_KEY            SkyFi API key

EXAMPLES:
  # Using command-line arguments
  skyfi-mcp \\
    --server https://skyfi-mcp.fly.dev \\
    --access-key sk_mcp_abc123... \\
    --api-key skyfi_xyz789...

  # Using environment variables
  export SKYFI_MCP_SERVER_URL=https://skyfi-mcp.fly.dev
  export SKYFI_MCP_ACCESS_KEY=sk_mcp_abc123...
  export SKYFI_API_KEY=skyfi_xyz789...
  skyfi-mcp

  # With debug logging
  skyfi-mcp -s https://skyfi-mcp.fly.dev -a sk_mcp_... -k skyfi_... --debug

CONFIGURATION WITH CLAUDE DESKTOP:
  Add to your Claude Desktop config (~/.claude/config.json):

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

  Or use environment variables in your shell profile:

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

MORE INFO:
  Documentation: https://github.com/yourusername/skyfi_mcp
  Get access key: Contact your SkyFi MCP administrator
  Get SkyFi API key: https://app.skyfi.com/settings/api
`);
}

async function main() {
  const config = parseArgs();

  if (config.debug) {
    console.error('[CLI] Starting SkyFi MCP client...');
    console.error('[CLI] Server:', config.serverUrl);
    console.error('[CLI] Access key:', config.accessKey.substring(0, 10) + '...');
  }

  const bridge = new StdioBridge(config);
  await bridge.start();
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
