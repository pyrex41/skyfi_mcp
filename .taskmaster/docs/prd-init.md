This refined PRD is structured to be immediately actionable. I have reorganized the content to separate **Business Logic** from **Technical Implementation**, standardized the **MCP Terminology** (Tools, Resources, Prompts), and integrated the **Elixir/Phoenix** architectural decisions directly into the technical specifications.

This version is optimized for a "Task Master" (Project Manager or AI Agent) to parse into individual Jira/GitHub tickets.

***

# Product Requirements Document (PRD): SkyFi MCP

| **Project Name** | SkyFi MCP (Model Context Protocol) |
| :--- | :--- |
| **Organization** | SkyFi |
| **Version** | 1.1 (Refined) |
| **Status** | **Draft** / Ready for Development |
| **Tech Stack** | Elixir, Phoenix, Tesla, MCP Standard |

---

## 1. Executive Summary
SkyFi MCP is a standardized interface enabling autonomous AI agents (e.g., Claude, OpenAI GPTs) to discover, task, and purchase geospatial data directly from SkyFi. By implementing the **Model Context Protocol (MCP)**, we transform SkyFi from a human-centric platform into an "agent-ready" ecosystem. This initiative positions SkyFi as the default geospatial provider for the emerging AI economy, allowing agents to perform complex workflows—from feasibility checks to order placement—without human intervention.

## 2. Problem Statement
**The Gap:** Autonomous AI agents are proliferating in finance, logistics, and intelligence sectors, yet they cannot easily access high-quality satellite imagery. Current APIs are designed for human developers, requiring complex authentication flows and rigid polling that confuse LLMs.
**The Solution:** SkyFi MCP bridges this gap by providing a self-documenting, standardized protocol server. It translates natural language intent from agents into precise SkyFi API calls for feasibility, pricing, and ordering.

## 3. Goals & Success Metrics

### Business Goals
*   **Market Reach:** Establish SkyFi as the first "AI-Native" geospatial marketplace.
*   **Sales:** Attributes 20% of new API revenue to MCP-originated requests within Q1.
*   **Adoption:** 500+ installs of the open-source MCP server by AI developers.

### Technical Goals
*   **Latency:** Tool execution overhead <200ms (leveraging Elixir BEAM).
*   **Concurrency:** Support 1,000+ concurrent agent sessions via Phoenix Channels.
*   **Reliability:** 99.9% uptime for the MCP transport layer.

## 4. User Personas & Stories

| Persona | Role | User Story |
| :--- | :--- | :--- |
| **The Architect** | AI Developer | "As a dev, I want a pre-built MCP server so I can plug SkyFi into my customized Claude Desktop without writing API wrappers." |
| **The Analyst** | Enterprise | "As an analyst, I want my internal AI agent to monitor a port and alert me only when new imagery is available, without me checking the dashboard." |
| **The Researcher** | Academic | "As a researcher, I want to ask my AI to 'find all cloud-free images of the Amazon Delta from 2023' and get a JSON list back instantly." |

---

## 5. Functional Requirements (The "What")

The system will expose SkyFi capabilities via the three standard MCP primitives: **Tools**, **Resources**, and **Prompts**.

### 5.1. MCP Tools (P0 - Core Interaction)
*The server must expose executable functions to the AI agent.*

*   **`search_archive`**:
    *   **Input:** AOI (GeoJSON/BBox), Date Range, Cloud Cover %.
    *   **Output:** List of available image IDs with metadata and thumbnails.
*   **`check_feasibility`**:
    *   **Input:** AOI, Date Range, Sensor Type (Optical/SAR).
    *   **Output:** Success probability, available pass times.
*   **`get_price_estimate`**:
    *   **Input:** Tasking parameters or Archive Image ID.
    *   **Output:** Cost estimate breakdown.
*   **`place_order`**:
    *   **Input:** Final configuration payload + Price Confirmation Token.
    *   **Output:** Order ID and status URL.
    *   **Logic:** Must require a "human-in-the-loop" confirmation step or specific approval flag if price > $X.
*   **`list_orders`**:
    *   **Input:** Status filter (pending, completed).
    *   **Output:** History of orders for the authenticated user.

### 5.2. MCP Resources (P1 - Data Context)
*The server must allow the agent to "read" data as context.*

*   **`skyfi://orders/{id}/status`**: Direct read access to order status updates.
*   **`skyfi://archive/{id}/metadata`**: Read-only access to full sensor metadata.

### 5.3. System Capabilities
*   **Authentication:** API Key passthrough (User provides SkyFi Key → MCP Server → SkyFi API).
*   **Transport:** Support `stdio` (local) and `SSE` (Server-Sent Events over HTTP) for remote deployment.
*   **Logging:** structured logs for tool invocation success/failure rates.

---

## 6. Technical Specifications (The "How")

### 6.1. Architecture: Elixir/Phoenix
We will utilize Elixir for its fault tolerance and ability to handle stateful connections (SSE) efficiently.

*   **Framework:** Phoenix 1.7+ (no HTML/CSS assets required, API mode only).
*   **HTTP Client:** `Tesla` with middleware for SkyFi API authentication and JSON parsing.
*   **Concurrency:** `GenServer` per active MCP session to maintain context (e.g., remembering the last searched AOI).
*   **JSON Handling:** `Jason` for high-performance serialization.

### 6.2. Protocol Implementation
*   **Route:** `/mcp/sse` (Primary endpoint).
*   **Message Format:** Adherence to JSON-RPC 2.0 as defined by MCP spec.
*   **Schema Validation:** All tool inputs must be validated against defined JSON Schemas before hitting the SkyFi API.

### 6.3. Project Structure (Reference)
```text
lib/
├── skyfi_mcp/
│   ├── mcp_protocol/       # JSON-RPC parsing & Schema definitions
│   ├── skyfi_client/       # Tesla wrappers for SkyFi Public API
│   └── tools/              # Individual tool logic (Search, Order, etc.)
└── skyfi_mcp_web/
    └── controllers/        # SSE Handler
```

---

## 7. Implementation Roadmap & Phasing
*This section is designed for the "Task Master" to generate tickets.*

### Phase 1: Skeleton & Transport (Day 1-2)
*   [ ] Initialize Phoenix Project (`mix new` --no-html).
*   [ ] Implement generic MCP JSON-RPC handler.
*   [ ] Implement SSE Controller for transport.
*   [ ] Create `SkyfiClient` module with authentication middleware.

### Phase 2: Core Tools (Day 3-4)
*   [ ] **Tool:** Implement `search_archive` with GeoJSON normalization.
*   [ ] **Tool:** Implement `check_feasibility`.
*   [ ] **Tool:** Implement `get_price_estimate`.
*   [ ] **Test:** Verify tools using Claude Desktop via `localhost`.

### Phase 3: Transactions & Safety (Day 5)
*   [ ] **Tool:** Implement `place_order` with a required `confirm_price` parameter.
*   [ ] Add error handling (mapping SkyFi 4xx/5xx errors to friendly MCP error messages).

### Phase 4: Documentation & Deploy (Day 6-7)
*   [ ] Write `README.md` with setup instructions for Claude Desktop.
*   [ ] Create a `Dockerfile` for Fly.io/Render deployment.
*   [ ] Record demo video of an AI agent searching and pricing an image.

---

## 8. Constraints & Assumptions
*   **Constraint:** Use SkyFi Public API only (no internal database access).
*   **Assumption:** The user possesses a valid SkyFi Gold API Key.
*   **Assumption:** Order placement via API allows for immediate credit deduction (requires account having credits or card on file).
*   **Security:** The MCP server is stateless; it does not store API keys persistently. Keys are passed per session or stored in the local environment of the user.

## 9. Out of Scope (MVP)
*   User Management (The MCP server is a conduit, not a SaaS platform).
*   Payment Gateway logic (Handled by SkyFi main platform).
*   Image downloading/processing (The agent retrieves metadata/links, not binary blobs).
