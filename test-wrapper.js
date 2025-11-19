#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');

console.log('Testing wrapper script: run_remote.sh\n');

// Start the MCP server using wrapper
const server = spawn(path.join(__dirname, 'run_remote.sh'));

let responses = 0;

server.stdout.on('data', (data) => {
  responses++;
  const response = JSON.parse(data.toString());
  console.log(`✓ Response ${responses}:`, response.result ? 'Success' : 'Error');
  if (response.result && response.result.serverInfo) {
    console.log(`  Server: ${response.result.serverInfo.name} v${response.result.serverInfo.version}`);
  }
  if (response.result && response.result.tools) {
    console.log(`  Tools: ${response.result.tools.length}`);
  }
});

server.stderr.on('data', (data) => {
  // Ignore stderr (debug messages)
});

// Wait for connection
setTimeout(() => {
  console.log('Sending initialize...');
  server.stdin.write(JSON.stringify({
    jsonrpc: '2.0',
    method: 'initialize',
    params: { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'test', version: '1.0' } },
    id: 1
  }) + '\n');

  setTimeout(() => {
    console.log('Sending tools/list...');
    server.stdin.write(JSON.stringify({
      jsonrpc: '2.0',
      method: 'tools/list',
      id: 2
    }) + '\n');

    setTimeout(() => {
      console.log('\n✓ Test complete!');
      server.kill('SIGTERM');
    }, 2000);
  }, 2000);
}, 2000);
