#!/bin/bash

cd /Users/reuben/gauntlet/skyfi_mcp/npm-bridge

# Start bridge with debug
node dist/cli.js \
  --server https://skyfi-mcp.fly.dev \
  --access-key sk_mcp_9a7312e31449dea2cd075997284c6f6b6261c0abebad48adc62a66bcd3e48aba \
  --api-key YOUR_SKYFI_API_KEY_HERE \
  --debug <<'EOF'
{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}},"id":0}
{"jsonrpc":"2.0","method":"tools/list","params":{},"id":1}
EOF
