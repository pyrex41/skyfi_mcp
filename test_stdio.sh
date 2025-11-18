#!/bin/bash
# Test script for stdio transport
# Usage: ./test_stdio.sh | mix skyfi_mcp.stdio

echo "Testing MCP stdio transport..."
echo ""

# Test 1: Initialize
echo "Test 1: Initialize"
echo '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}'
echo ""

# Wait a bit
sleep 1

# Test 2: List tools
echo "Test 2: List tools"
echo '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}'
echo ""

# Wait a bit
sleep 1

# Test 3: Call search_archive tool (this will fail without real API key, but tests the routing)
echo "Test 3: Call search_archive (will fail without API key, but tests routing)"
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"search_archive","arguments":{"aoi":[0,0,1,1],"start_date":"2023-01-01T00:00:00Z","end_date":"2023-12-31T23:59:59Z"}},"id":3}'
echo ""

echo "Done sending test messages. Press Ctrl+C to stop the server."
