#!/bin/bash
# Test script for SkyFi MCP client

echo "Testing SkyFi MCP Bridge..."
echo ""

# Configuration
SERVER="https://skyfi-mcp.fly.dev"
ACCESS_KEY="sk_mcp_9a7312e31449dea2cd075997284c6f6b6261c0abebad48adc62a66bcd3e48aba"
API_KEY="053eef6dc8b849358eedaacd5bdd1b8d"
BRIDGE="/Users/reuben/gauntlet/skyfi_mcp/npm-bridge/dist/cli.js"

echo "1. Testing server health..."
curl -s "$SERVER/health" | jq . || echo "✗ Server health check failed"
echo ""

echo "2. Testing direct server call (tools/list)..."
curl -s -X POST "$SERVER/mcp/message" \
  -H "Authorization: Bearer $ACCESS_KEY" \
  -H "X-SkyFi-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}' \
  | jq '.result.tools | length' | xargs -I {} echo "✓ Found {} tools"
echo ""

echo "3. Testing npm bridge (initialize)..."
echo '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}},"id":1}' | \
  timeout 3 node "$BRIDGE" \
    --server "$SERVER" \
    --access-key "$ACCESS_KEY" \
    --api-key "$API_KEY" \
    2>/dev/null | jq -r '.result.serverInfo.name' | xargs -I {} echo "✓ Server name: {}"

echo ""
echo "4. Configuration files..."
echo "OpenCode config: opencode.json"
jq '.mcp."skyfi-remote".enabled' opencode.json | xargs -I {} echo "  skyfi-remote enabled: {}"

echo "Claude Code config: .claude.json"
test -f .claude.json && echo "  ✓ .claude.json exists" || echo "  ✗ .claude.json missing"

echo ""
echo "Done! Restart OpenCode/Claude Code to load the new configuration."
