#!/usr/bin/env node

// Simple MCP server that logs everything and responds to initialize/tools/list
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

console.error('[TEST MCP] Server starting...');

rl.on('line', (line) => {
  console.error('[TEST MCP] Received:', line);

  try {
    const request = JSON.parse(line);
    let response;

    if (request.method === 'initialize') {
      response = {
        jsonrpc: '2.0',
        id: request.id,
        result: {
          protocolVersion: '2024-11-05',
          capabilities: { tools: {} },
          serverInfo: { name: 'test-mcp', version: '1.0.0' }
        }
      };
    } else if (request.method === 'tools/list') {
      response = {
        jsonrpc: '2.0',
        id: request.id,
        result: {
          tools: [
            { name: 'test_tool', description: 'A test tool', inputSchema: { type: 'object' } }
          ]
        }
      };
    } else {
      response = {
        jsonrpc: '2.0',
        id: request.id,
        error: { code: -32601, message: 'Method not found' }
      };
    }

    console.error('[TEST MCP] Sending:', JSON.stringify(response));
    console.log(JSON.stringify(response));
  } catch (error) {
    console.error('[TEST MCP] Error:', error.message);
  }
});

console.error('[TEST MCP] Listening for JSON-RPC requests...');
