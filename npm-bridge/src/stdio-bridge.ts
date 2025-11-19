import * as readline from 'readline';
import { SkyFiMcpClient, ClientConfig, JsonRpcRequest } from './client';

/**
 * StdioBridge connects stdio (used by MCP clients like Claude) to a remote HTTP server
 */
export class StdioBridge {
  private client: SkyFiMcpClient;
  private rl: readline.Interface;
  private debug: boolean;

  constructor(config: ClientConfig) {
    this.client = new SkyFiMcpClient(config);
    this.debug = config.debug || false;

    // Create readline interface for stdin
    // Note: No output param - stdout is reserved for JSON-RPC responses only
    this.rl = readline.createInterface({
      input: process.stdin,
      terminal: false,
    });
  }

  /**
   * Start the bridge
   */
  async start(): Promise<void> {
    try {
      // Connect to the server
      if (this.debug) {
        console.error('[Bridge] Connecting to server...');
      }

      await this.client.connect();

      if (this.debug) {
        console.error('[Bridge] Connected! Listening for JSON-RPC messages...');
      }

      // Handle stdin messages
      this.rl.on('line', async (line) => {
        await this.handleStdinMessage(line);
      });

      // Handle process termination
      process.on('SIGINT', () => this.shutdown());
      process.on('SIGTERM', () => this.shutdown());

    } catch (error) {
      console.error('Failed to start bridge:', error);
      process.exit(1);
    }
  }

  /**
   * Handle a JSON-RPC message from stdin
   */
  private async handleStdinMessage(line: string): Promise<void> {
    try {
      // Parse JSON-RPC request
      const request: JsonRpcRequest = JSON.parse(line);

      if (this.debug) {
        console.error('[Bridge] Received request:', request.method, 'id:', request.id);
      }

      // Forward to server
      const response = await this.client.sendRequest(request);

      // Write response to stdout
      // Note: We write to stdout (fd 1), not stderr (fd 2)
      // Using process.stdout.write instead of console.log to avoid extra newlines
      process.stdout.write(JSON.stringify(response) + '\n');

      if (this.debug) {
        console.error('[Bridge] Sent response for id:', request.id);
      }

    } catch (error) {
      if (this.debug) {
        console.error('[Bridge] Error handling message:', error);
      }

      // Send error response if we have a request id
      try {
        const errorLine = line.trim();
        if (errorLine.length > 0) {
          const request = JSON.parse(errorLine);
          const errorResponse = {
            jsonrpc: '2.0' as const,
            error: {
              code: -32603,
              message: error instanceof Error ? error.message : 'Internal error',
            },
            id: request.id || null,
          };
          process.stdout.write(JSON.stringify(errorResponse) + '\n');
        }
      } catch (parseError) {
        // If we can't parse the request, just log the error
        if (this.debug) {
          console.error('[Bridge] Failed to send error response:', parseError);
        }
      }
    }
  }

  /**
   * Shutdown the bridge gracefully
   */
  private shutdown(): void {
    if (this.debug) {
      console.error('[Bridge] Shutting down...');
    }

    this.rl.close();
    this.client.disconnect();
    process.exit(0);
  }
}
