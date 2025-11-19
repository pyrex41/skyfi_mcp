# SkyFi MCP Testing Guide

## Configuration Complete! ✅

Your SkyFi MCP server is now deployed and configured for both local and remote access.

## Deployed Server

- **URL**: https://skyfi-mcp.fly.dev
- **Status**: Running (v3)
- **Access Key**: `sk_mcp_9a7312e31449dea2cd075997284c6f6b6261c0abebad48adc62a66bcd3e48aba`
- **SkyFi API Key**: `YOUR_SKYFI_API_KEY_HERE`

## Configuration Files Updated

### OpenCode (`opencode.json`)

Two configurations available:
- `skyfi-local` (disabled) - Uses local Mix/Elixir
- `skyfi-remote` (enabled) - Uses npm bridge to remote server

### Claude Code (`.mcp.json`)

Two configurations available:
- `skyfi-local` (disabled) - Uses local Mix/Elixir
- `skyfi-remote` (enabled) - Uses npm bridge to remote server

## Testing

### 1. Test with curl (Server Direct)

```bash
curl -X POST https://skyfi-mcp.fly.dev/mcp/message \
  -H "Authorization: Bearer sk_mcp_9a7312e31449dea2cd075997284c6f6b6261c0abebad48adc62a66bcd3e48aba" \
  -H "X-SkyFi-API-Key: YOUR_SKYFI_API_KEY_HERE" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
```

Expected: JSON response with list of SkyFi tools

### 2. Test with OpenCode

1. Restart OpenCode to reload config
2. In a conversation, mention: "use the skyfi-remote tools"
3. Try: "List the available SkyFi tools"

### 3. Test with Claude Code

1. Restart Claude Code (or reload window)
2. The skyfi-remote server should auto-start
3. Try asking: "What MCP tools do you have available?"
4. Look for SkyFi tools in the response

## Available Tools

Your deployed server has these tools:

1. **search_archive** - Search existing satellite imagery
2. **check_feasibility** - Check tasking feasibility
3. **get_price_estimate** - Get pricing estimates
4. **place_order** - Place imagery orders
5. **list_orders** - List order history
6. **geocode** - Convert locations to coordinates
7. **reverse_geocode** - Convert coordinates to locations
8. **setup_monitor** - Set up monitoring for new imagery

## npm Bridge Package

Located at: `/Users/reuben/gauntlet/skyfi_mcp/npm-bridge/`

### Test Locally

```bash
cd /Users/reuben/gauntlet/skyfi_mcp/npm-bridge

# Test connection
node dist/cli.js \
  --server https://skyfi-mcp.fly.dev \
  --access-key sk_mcp_9a7312e31449dea2cd075997284c6f6b6261c0abebad48adc62a66bcd3e48aba \
  --api-key YOUR_SKYFI_API_KEY_HERE \
  --debug
```

Then send a JSON-RPC request via stdin:
```json
{"jsonrpc":"2.0","method":"tools/list","id":1}
```

(Press Ctrl+D to close stdin after the response)

### Build Changes

If you modify the TypeScript source:

```bash
cd npm-bridge
npm run build
```

## Switching Between Local and Remote

### OpenCode

Edit `opencode.json`:
```json
{
  "skyfi-local": { "enabled": false },  // Mix/Elixir
  "skyfi-remote": { "enabled": true }   // npm bridge
}
```

### Claude Code

Edit `.mcp.json`:
```json
{
  "skyfi-local": { "disabled": true },   // Mix/Elixir
  "skyfi-remote": { }                     // npm bridge (enabled)
}
```

## Managing Access Keys

### Create New Key

```bash
fly ssh console -a skyfi-mcp -C \
  "sqlite3 /data/skyfi_mcp.db \"INSERT INTO access_keys (key, user_email, description, active, request_count, inserted_at, updated_at) VALUES ('sk_mcp_' || lower(hex(randomblob(32))), 'user@example.com', 'Description', 1, 0, datetime('now'), datetime('now')); SELECT 'Key: ' || key FROM access_keys ORDER BY id DESC LIMIT 1;\""
```

### List Keys

```bash
fly ssh console -a skyfi-mcp -C \
  "sqlite3 /data/skyfi_mcp.db \"SELECT key, user_email, active, request_count, last_used_at FROM access_keys;\""
```

### Revoke Key

```bash
fly ssh console -a skyfi-mcp -C \
  "sqlite3 /data/skyfi_mcp.db \"UPDATE access_keys SET active=0 WHERE key='sk_mcp_...';\""
```

## Monitoring

### View Logs

```bash
fly logs -a skyfi-mcp
```

### Check Status

```bash
fly status -a skyfi-mcp
```

### SSH Into Server

```bash
fly ssh console -a skyfi-mcp
```

## Publishing npm Package

When ready to publish:

```bash
cd npm-bridge

# Update package.json
# - Change repository URL
# - Update description/author

# Test locally first
npm pack
npm install -g skyfi-mcp-client-1.0.0.tgz

# Publish to npm
npm login
npm publish --access public
```

Then users can use:
```bash
npx @skyfi/mcp-client
```

## Troubleshooting

### Server Issues

```bash
# Check server health
curl https://skyfi-mcp.fly.dev/health

# View recent logs
fly logs -a skyfi-mcp

# Restart server
fly scale count 0 -a skyfi-mcp
fly scale count 1 -a skyfi-mcp
```

### npm Bridge Issues

```bash
# Rebuild
cd npm-bridge
npm run build

# Test with debug
node dist/cli.js --debug ...
```

### OpenCode/Claude Code Issues

1. Check config files are valid JSON
2. Restart the application
3. Check application logs
4. Test npm bridge separately first

## Next Steps

1. ✅ Server deployed and running
2. ✅ Access key created
3. ✅ npm bridge tested
4. ✅ Configs updated for OpenCode & Claude Code
5. 🔄 Test in OpenCode/Claude Code
6. 📦 Publish npm package (optional)
7. 📚 Share with users

## Support

- **GitHub**: https://github.com/yourusername/skyfi_mcp
- **Server Logs**: `fly logs -a skyfi-mcp`
- **Fly.io Dashboard**: https://fly.io/apps/skyfi-mcp/monitoring
