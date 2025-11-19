#!/bin/bash
# Wrapper script for SkyFi MCP remote bridge

exec node /Users/reuben/gauntlet/skyfi_mcp/npm-bridge/dist/cli.js \
  --server https://skyfi-mcp.fly.dev \
  --access-key sk_mcp_9a7312e31449dea2cd075997284c6f6b6261c0abebad48adc62a66bcd3e48aba \
  --api-key 053eef6dc8b849358eedaacd5bdd1b8d \
  "$@"
