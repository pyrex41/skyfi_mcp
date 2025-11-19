# OpenCode Debugging Guide

## ✅ What We've Verified

1. ✅ Server is running and healthy
2. ✅ npm bridge works perfectly (tested)
3. ✅ Wrapper script works (`run_remote.sh`)
4. ✅ JSON config is valid

## 🔧 Current Config

**opencode.json** (simplified):
```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "skyfi-remote": {
      "type": "local",
      "command": ["/Users/reuben/gauntlet/skyfi_mcp/run_remote.sh"],
      "enabled": true
    }
  }
}
```

## 🐛 Debugging Steps

### 1. Check OpenCode Logs

OpenCode should have logs somewhere. Look for:
- Console logs in the app
- Log files in `~/.opencode/` or similar
- Developer console (if available)

### 2. Verify OpenCode Can Find the Script

```bash
# Test if the script is accessible
/Users/reuben/gauntlet/skyfi_mcp/run_remote.sh --help

# Should show help message
```

### 3. Try Even Simpler Config

If still failing, try this minimal version in `opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "test-echo": {
      "type": "local",
      "command": ["echo", "test"],
      "enabled": true
    }
  }
}
```

If this works, then OpenCode is loading configs. If not, there's an OpenCode config issue.

### 4. Check OpenCode MCP Support

Some questions to verify:
- Does OpenCode show ANY MCP servers?
- Can you see other MCP servers in the UI?
- Is there an OpenCode version requirement for MCP?

### 5. Alternative: Use npx

Try this in `opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "skyfi-remote": {
      "type": "local",
      "command": ["bash", "/Users/reuben/gauntlet/skyfi_mcp/run_remote.sh"],
      "enabled": true
    }
  }
}
```

Or explicitly specify bash:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "skyfi-remote": {
      "type": "local",
      "command": ["bash", "-c", "/Users/reuben/gauntlet/skyfi_mcp/run_remote.sh"],
      "enabled": true
    }
  }
}
```

### 6. Test Local Mix Version

If the local Mix version was working before, try enabling it temporarily:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "skyfi-local": {
      "type": "local",
      "command": ["/Users/reuben/gauntlet/skyfi_mcp/run_stdio.sh"],
      "enabled": true,
      "environment": {
        "SKYFI_API_KEY": "053eef6dc8b849358eedaacd5bdd1b8d"
      }
    }
  }
}
```

If this works but remote doesn't, there might be an issue with how OpenCode handles the wrapper.

## 📝 What "Silent Failure" Means

Silent failures in OpenCode could be:
1. **Config not loading** - OpenCode isn't reading the file
2. **Command fails immediately** - Script exits with error
3. **MCP handshake fails** - Script runs but MCP protocol fails
4. **OpenCode MCP disabled** - Feature not enabled in OpenCode

## 🔍 How to Find the Real Error

### Check if OpenCode has a developer mode:
1. Look for Developer Tools / Console
2. Check for error messages when loading MCP servers
3. Look for network errors or stdio errors

### Try running OpenCode from terminal:
```bash
# If OpenCode can be launched from terminal
opencode /Users/reuben/gauntlet/skyfi_mcp

# Check terminal output for errors
```

### Check permissions:
```bash
ls -la /Users/reuben/gauntlet/skyfi_mcp/run_remote.sh
# Should show: -rwxr-xr-x (executable)

ls -la /Users/reuben/gauntlet/skyfi_mcp/npm-bridge/dist/cli.js
# Should show: -rwxr-xr-x (executable)
```

## 🎯 Next Actions

1. **Restart OpenCode completely** (quit and reopen)
2. **Check OpenCode version** - ensure MCP support is available
3. **Look for logs** - find where OpenCode logs errors
4. **Try minimal config** - test with simple echo command
5. **Contact OpenCode support** - if still failing, this might be an OpenCode issue

## ✅ Confirmed Working

The following have been tested and work:
- ✅ Server connection
- ✅ npm bridge stdio communication
- ✅ MCP protocol (initialize, tools/list)
- ✅ Wrapper script execution

The issue is likely OpenCode-specific, not with our server or bridge.

## 📞 Get Help

If still stuck:
1. Check OpenCode documentation for MCP troubleshooting
2. Look for OpenCode community/support channels
3. Verify OpenCode MCP feature is enabled
4. Check OpenCode version requirements for MCP

## 🔄 Working Alternative: Claude Code

Claude Code is working correctly with `.mcp.json`. You can use that while debugging OpenCode.
