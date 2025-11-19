#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');

// Start the MCP server
const server = spawn('node', [
  path.join(__dirname, 'npm-bridge/dist/cli.js'),
  '--server', 'https://skyfi-mcp.fly.dev',
  '--access-key', 'sk_mcp_9a7312e31449dea2cd075997284c6f6b6261c0abebad48adc62a66bcd3e48aba',
  '--api-key', '053eef6dc8b849358eedaacd5bdd1b8d'
]);

let output = '';

server.stdout.on('data', (data) => {
  output += data.toString();
  console.log('STDOUT:', data.toString().trim());
});

server.stderr.on('data', (data) => {
  console.log('STDERR:', data.toString().trim());
});

server.on('close', (code) => {
  console.log(`Server exited with code ${code}`);
  console.log('Total output:', output);
});

// Wait for server to start
setTimeout(() => {
  console.log('\nSending initialize request...');
  const initRequest = {
    jsonrpc: '2.0',
    method: 'initialize',
    params: {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'test', version: '1.0' }
    },
    id: 1
  };

  server.stdin.write(JSON.stringify(initRequest) + '\n');

  // Wait for response
  setTimeout(() => {
    console.log('\nSending tools/list request...');
    const toolsRequest = {
      jsonrpc: '2.0',
      method: 'tools/list',
      id: 2
    };

    server.stdin.write(JSON.stringify(toolsRequest) + '\n');

    // Close after getting responses
    setTimeout(() => {
      console.log('\nClosing server...');
      server.kill('SIGTERM');
    }, 2000);
  }, 2000);
}, 2000);
