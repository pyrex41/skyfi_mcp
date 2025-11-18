# SkyFi MCP Quick Start Guide

This guide will help you deploy the SkyFi MCP server and set up the npm client bridge.

## Architecture

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   Claude    │ stdio   │ npm-bridge   │  HTTP   │   Remote    │
│   Desktop   │◄───────►│  @skyfi/mcp  │◄───────►│ MCP Server  │
└─────────────┘         └──────────────┘         └─────────────┘
                         (no Elixir needed)        (Fly.io)
```

**Benefits:**
- Users only need Node.js (no Elixir/Mix)
- One server deployment serves many users
- Easy updates (just redeploy server)
- Lower barrier to entry

## Step 1: Deploy the Server to Fly.io

### Prerequisites

- [Fly.io account](https://fly.io/app/sign-up)
- [Fly CLI](https://fly.io/docs/hands-on/install-flyctl/) installed

### Deploy

```bash
# 1. Login to Fly.io
fly auth login

# 2. Launch the app (from project root)
fly launch --no-deploy

# 3. Set required secrets
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)

# 4. Create persistent volume for database
fly volumes create data --size 1

# 5. Deploy!
fly deploy
```

Your server will be available at: `https://<your-app-name>.fly.dev`

### Create Access Keys

Access keys control who can use your server:

```bash
# SSH into your app
fly ssh console

# Create an access key for a user
/app/bin/skyfi_mcp rpc "SkyfiMcp.AccessKey.create(\"user@example.com\", \"Description\")"
```

This outputs:
```
Access key created successfully!
Email: user@example.com
Key: sk_mcp_abc123xyz789...
Description: Description
```

**Save this key!** It can't be retrieved later.

## Step 2: Publish the npm Package (Optional)

If you want to publish the bridge package to npm:

```bash
cd npm-bridge

# Update package.json with your details
# - Change "name" if needed
# - Update "repository" URL
# - Update author/description

# Login to npm
npm login

# Publish
npm publish --access public
```

If you don't publish, users can still use it locally via `npm pack`:

```bash
cd npm-bridge
npm pack
# This creates @skyfi-mcp-client-1.0.0.tgz
```

## Step 3: Configure Claude Desktop

Users need to add the MCP server to their Claude Desktop configuration:

**Config location:**
- macOS/Linux: `~/.claude/config.json`
- Windows: `%APPDATA%\Claude\config.json`

### Option A: Using npx (if published to npm)

```json
{
  "mcpServers": {
    "skyfi": {
      "command": "npx",
      "args": ["@skyfi/mcp-client"],
      "env": {
        "SKYFI_MCP_SERVER_URL": "https://your-app.fly.dev",
        "SKYFI_MCP_ACCESS_KEY": "sk_mcp_abc123...",
        "SKYFI_API_KEY": "your-skyfi-api-key"
      }
    }
  }
}
```

### Option B: Using local package

```bash
# Install the package
npm install -g /path/to/skyfi_mcp/npm-bridge

# Or from tarball
npm install -g @skyfi-mcp-client-1.0.0.tgz
```

Then configure:

```json
{
  "mcpServers": {
    "skyfi": {
      "command": "skyfi-mcp",
      "args": [
        "--server", "https://your-app.fly.dev",
        "--access-key", "sk_mcp_abc123...",
        "--api-key", "your-skyfi-api-key"
      ]
    }
  }
}
```

### Option C: Using command-line args (less secure)

```json
{
  "mcpServers": {
    "skyfi": {
      "command": "npx",
      "args": [
        "@skyfi/mcp-client",
        "--server", "https://your-app.fly.dev",
        "--access-key", "sk_mcp_abc123...",
        "--api-key", "your-skyfi-api-key"
      ]
    }
  }
}
```

**Restart Claude Desktop** after configuration changes.

## Step 4: Test the Integration

### Test with curl

```bash
export ACCESS_KEY="sk_mcp_abc123..."
export SKYFI_API_KEY="your-skyfi-api-key"
export SERVER_URL="https://your-app.fly.dev"

# Test health
curl $SERVER_URL/health

# Test tools/list
curl -X POST $SERVER_URL/mcp/message \
  -H "Authorization: Bearer $ACCESS_KEY" \
  -H "X-SkyFi-API-Key: $SKYFI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
```

### Test with npm bridge

```bash
# Test locally
cd npm-bridge
echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | \
  node dist/cli.js \
    --server https://your-app.fly.dev \
    --access-key sk_mcp_... \
    --api-key your-skyfi-api-key \
    --debug
```

### Test with Claude Desktop

1. Open Claude Desktop
2. Start a new conversation
3. Try asking: "What MCP tools do you have available?"
4. You should see the SkyFi tools listed

## Managing Your Deployment

### View logs

```bash
fly logs
```

### Monitor access

```bash
fly ssh console
/app/bin/skyfi_mcp rpc "SkyfiMcp.AccessKey.list_all()"
```

### Revoke access

```bash
fly ssh console
/app/bin/skyfi_mcp rpc "SkyfiMcp.AccessKey.revoke(\"sk_mcp_...\")"
```

### Update the server

```bash
fly deploy
```

### Scale resources

```bash
# Increase memory
fly scale memory 1024

# Scale to 2 CPUs
fly scale vm shared-cpu-2x
```

## Credentials Management

Each user needs **TWO** credentials:

### 1. MCP Access Key (from server admin)
- Format: `sk_mcp_...`
- Created by server administrator
- Validates MCP access permission
- Can be revoked at any time

### 2. SkyFi API Key (from user)
- Get at: https://app.skyfi.com/settings/api
- User's personal API key
- Used for actual satellite imagery requests
- User manages their own key

## Cost Estimates

### Fly.io Server
- **Free tier**: 3 shared-cpu-1x machines (256MB RAM) free
- **Auto-scaling**: Server stops when idle (costs $0)
- **Volume**: 1GB free (3GB total per account)
- **Typical cost**: $0-5/month for light usage

### npm Bridge
- **Free**: No cost to use
- **No infrastructure**: Runs on user's machine

## Troubleshooting

### Server won't start

```bash
fly logs
fly secrets list
fly volumes list
```

### npm bridge connection issues

```bash
# Enable debug mode
skyfi-mcp --debug -s <url> -a <key> -k <key>

# Test server directly
curl https://your-app.fly.dev/health
```

### Claude Desktop not seeing tools

1. Check config file is valid JSON
2. Restart Claude Desktop
3. Check Claude Desktop logs
4. Test npm bridge manually first

## Next Steps

- See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed deployment guide
- See [npm-bridge/README.md](./npm-bridge/README.md) for npm package docs
- Monitor usage via Fly.io dashboard
- Set up automated backups for production

## Support

- **GitHub Issues**: https://github.com/yourusername/skyfi_mcp/issues
- **Fly.io Docs**: https://fly.io/docs/
- **MCP Docs**: https://modelcontextprotocol.io/

## Security Checklist

- [ ] `SECRET_KEY_BASE` is unique and secure
- [ ] Access keys distributed securely
- [ ] HTTPS enabled (automatic with Fly.io)
- [ ] Access keys rotated periodically
- [ ] Unused keys revoked
- [ ] Monitor request logs
- [ ] Users keep SkyFi API keys private
