#!/bin/bash
# Comprehensive MCP prompt testing script

set -e

echo "==================================="
echo "SkyFi MCP Prompt Testing"
echo "==================================="
echo ""

# Load environment
source .env

# Server details
SERVER="https://skyfi-mcp.fly.dev/mcp/message"
ACCESS_KEY="sk_mcp_9a7312e31449dea2cd075997284c6f6b6261c0abebad48adc62a66bcd3e48aba"
API_KEY="${SKYFI_API_KEY}"

# Helper function to make MCP requests
mcp_request() {
  local method=$1
  local params=$2
  local id=$3

  echo "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":$params,\"id\":$id}" | \
    curl -s -X POST "$SERVER" \
      -H "Authorization: Bearer $ACCESS_KEY" \
      -H "X-SkyFi-API-Key: $API_KEY" \
      -H "Content-Type: application/json" \
      -d @-
}

echo "1. Testing prompts/list..."
echo "-----------------------------------"
response=$(mcp_request "prompts/list" "{}" 1)
echo "$response" | jq '.result.prompts | length' | xargs -I {} echo "✓ Found {} prompts"
echo "$response" | jq -r '.result.prompts[].name' | while read name; do
  echo "  - $name"
done
echo ""

echo "2. Testing search_imagery prompt..."
echo "-----------------------------------"
response=$(mcp_request "prompts/get" '{"name":"search_imagery","arguments":{"location":"San Francisco, CA","days_back":"7"}}' 2)
if echo "$response" | jq -e '.result.messages' > /dev/null 2>&1; then
  echo "✓ search_imagery prompt working"
  echo "$response" | jq -r '.result.messages[0].content[0].text' | head -c 100
  echo "..."
else
  echo "✗ search_imagery prompt failed"
  echo "$response" | jq .
fi
echo ""

echo "3. Testing search_imagery with default days..."
echo "-----------------------------------"
response=$(mcp_request "prompts/get" '{"name":"search_imagery","arguments":{"location":"Death Valley, CA"}}' 3)
if echo "$response" | jq -e '.result.messages' > /dev/null 2>&1; then
  echo "✓ search_imagery with defaults working"
  echo "$response" | jq -r '.result.messages[0].content[0].text' | head -c 100
  echo "..."
else
  echo "✗ search_imagery with defaults failed"
  echo "$response" | jq .
fi
echo ""

echo "4. Testing price_check prompt..."
echo "-----------------------------------"
response=$(mcp_request "prompts/get" '{"name":"price_check","arguments":{"location":"New York, NY","type":"archive"}}' 4)
if echo "$response" | jq -e '.result.messages' > /dev/null 2>&1; then
  echo "✓ price_check prompt working"
  echo "$response" | jq -r '.result.messages[0].content[0].text'
else
  echo "✗ price_check prompt failed"
  echo "$response" | jq .
fi
echo ""

echo "5. Testing price_check with defaults..."
echo "-----------------------------------"
response=$(mcp_request "prompts/get" '{"name":"price_check","arguments":{"location":"London, UK"}}' 5)
if echo "$response" | jq -e '.result.messages' > /dev/null 2>&1; then
  echo "✓ price_check with defaults working"
  echo "$response" | jq -r '.result.messages[0].content[0].text'
else
  echo "✗ price_check with defaults failed"
  echo "$response" | jq .
fi
echo ""

echo "6. Testing monitor_area prompt..."
echo "-----------------------------------"
response=$(mcp_request "prompts/get" '{"name":"monitor_area","arguments":{"location":"Tokyo, Japan","webhook_url":"https://example.com/webhook"}}' 6)
if echo "$response" | jq -e '.result.messages' > /dev/null 2>&1; then
  echo "✓ monitor_area prompt working"
  echo "$response" | jq -r '.result.messages[0].content[0].text'
else
  echo "✗ monitor_area prompt failed"
  echo "$response" | jq .
fi
echo ""

echo "7. Testing geocode tool (used by prompts)..."
echo "-----------------------------------"
response=$(mcp_request "tools/call" '{"name":"geocode","arguments":{"query":"Paris, France","limit":1}}' 7)
if echo "$response" | jq -e '.result.content[0].text' > /dev/null 2>&1; then
  echo "✓ Geocode tool working"
  echo "$response" | jq -r '.result.content[0].text' | jq -r '.[0] | "\(.display_name) [\(.lat), \(.lon)]"'
else
  echo "✗ Geocode tool failed"
  echo "$response" | jq .
fi
echo ""

echo "==================================="
echo "All tests completed!"
echo "==================================="
