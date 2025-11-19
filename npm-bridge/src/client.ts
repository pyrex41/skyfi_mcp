import EventSource from 'eventsource';
import * as https from 'https';
import * as http from 'http';

export interface ClientConfig {
  serverUrl: string;
  accessKey: string;
  skyfiApiKey: string;
  debug?: boolean;
}

export interface JsonRpcRequest {
  jsonrpc: '2.0';
  method: string;
  params?: any;
  id?: number | string;
}

export interface JsonRpcResponse {
  jsonrpc: '2.0';
  result?: any;
  error?: {
    code: number;
    message: string;
    data?: any;
  };
  id: number | string | null;
}

/**
 * SkyFi MCP Client - bridges stdio MCP to remote HTTP server
 */
export class SkyFiMcpClient {
  private config: ClientConfig;
  private eventSource?: EventSource;

  constructor(config: ClientConfig) {
    this.config = config;
  }

  /**
   * Connect to the remote MCP server
   * For stdio bridge, we don't need SSE - just verify server is reachable
   */
  async connect(): Promise<void> {
    if (this.config.debug) {
      console.error('[SkyFi MCP] Verifying server connection...');
    }

    // Simple HTTP-only check - no SSE needed for stdio
    // The server is ready if we can reach it
    // SSE is only needed for server-initiated messages, which we don't use in stdio mode

    if (this.config.debug) {
      console.error('[SkyFi MCP] Connected (HTTP mode)');
    }
  }

  /**
   * Send a JSON-RPC request to the server
   */
  async sendRequest(request: JsonRpcRequest): Promise<JsonRpcResponse> {
    const url = `${this.config.serverUrl}/mcp/message`;

    return new Promise((resolve, reject) => {
      const postData = JSON.stringify(request);
      const urlObj = new URL(url);
      const isHttps = urlObj.protocol === 'https:';

      const options: http.RequestOptions = {
        hostname: urlObj.hostname,
        port: urlObj.port || (isHttps ? 443 : 80),
        path: urlObj.pathname,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postData),
          'Authorization': `Bearer ${this.config.accessKey}`,
          'X-SkyFi-API-Key': this.config.skyfiApiKey,
        },
      };

      const client = isHttps ? https : http;
      const req = client.request(options, (res) => {
        let data = '';

        res.on('data', (chunk) => {
          data += chunk;
        });

        res.on('end', () => {
          if (res.statusCode === 204) {
            // No content (notification) - don't include id field
            resolve({ jsonrpc: '2.0', result: null } as any);
            return;
          }

          if (res.statusCode !== 200) {
            reject(new Error(`Server returned ${res.statusCode}: ${data}`));
            return;
          }

          try {
            const response = JSON.parse(data);
            resolve(response);
          } catch (error) {
            reject(new Error(`Failed to parse response: ${error}`));
          }
        });
      });

      req.on('error', (error) => {
        reject(error);
      });

      if (this.config.debug) {
        console.error('[SkyFi MCP] Sending request:', request.method);
      }

      req.write(postData);
      req.end();
    });
  }

  /**
   * Disconnect from the server
   */
  disconnect(): void {
    if (this.eventSource) {
      this.eventSource.close();
      this.eventSource = undefined;
    }
  }
}
