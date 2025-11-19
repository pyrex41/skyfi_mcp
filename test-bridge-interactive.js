#!/usr/bin/env node
/**
 * Interactive test for MCP bridge - simulates a real MCP client
 */
const { spawn } = require('child_process');

const bridge = spawn('node', [
  '/Users/reuben/gauntlet/skyfi_mcp/npm-bridge/dist/cli.js',
  '--server', 'https://skyfi-mcp.fly.dev',
  '--access-key', 'sk_mcp_9a7312e31449dea2cd075997284c6f6b6261c0abebad48adc62a66bcd3e48aba',
  '--api-key', 'YOUR_SKYFI_API_KEY_HERE'
]);

let responseCount = 0;

bridge.stdout.on('data', (data) => {
  console.log('Response:', data.toString().trim());
  responseCount++;

  if (responseCount === 2) {
    console.log('\n✓ Bridge test successful!');
    bridge.kill();
    process.exit(0);
  }
});

bridge.stderr.on('data', (data) => {
  console.error('Debug:', data.toString().trim());
});

bridge.on('error', (error) => {
  console.error('Error:', error);
  process.exit(1);
});

// Wait for bridge to start (2 seconds)
setTimeout(() => {
  console.log('Sending initialize request...');
  bridge.stdin.write(JSON.stringify({
    jsonrpc: '2.0',
    method: 'initialize',
    params: {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'test', version: '1.0' }
    },
    id: 1
  }) + '\n');

  setTimeout(() => {
    console.log('Sending tools/list request...');
    bridge.stdin.write(JSON.stringify({
      jsonrpc: '2.0',
      method: 'tools/list',
      id: 2
    }) + '\n');
  }, 1000);
}, 2000);

// Timeout after 10 seconds
setTimeout(() => {
  console.error('\n✗ Test timed out');
  bridge.kill();
  process.exit(1);
}, 10000);
