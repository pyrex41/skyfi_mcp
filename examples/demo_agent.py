#!/usr/bin/env python3
"""
SkyFi MCP Demo Agent

This demo script showcases how to interact with the SkyFi MCP server
to perform satellite imagery research workflows.

Requirements:
    - SkyFi MCP server running (local or remote)
    - Valid SkyFi API key
    - Python 3.8+
    - Dependencies: requests

Usage:
    python demo_agent.py
"""

import json
import requests
from typing import Dict, Any, List
from datetime import datetime, timedelta


class SkyFiMCPDemo:
    """Demo agent for SkyFi MCP interactions."""

    def __init__(self, mcp_url: str = "http://localhost:4000", skyfi_api_key: str = None):
        """
        Initialize the demo agent.

        Args:
            mcp_url: URL of the SkyFi MCP server
            skyfi_api_key: Your SkyFi API key (optional, can be set in server env)
        """
        self.mcp_url = mcp_url.rstrip('/')
        self.api_key = skyfi_api_key
        self.session_id = 1

    def call_tool(self, tool_name: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """
        Call an MCP tool via JSON-RPC.

        Args:
            tool_name: Name of the tool to call
            arguments: Tool arguments as dictionary

        Returns:
            Tool result
        """
        # Add API key if provided
        if self.api_key and "api_key" not in arguments:
            arguments["api_key"] = self.api_key

        payload = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": tool_name,
                "arguments": arguments
            },
            "id": self.session_id
        }

        self.session_id += 1

        print(f"\n📡 Calling tool: {tool_name}")
        print(f"   Arguments: {json.dumps(arguments, indent=2)}")

        try:
            response = requests.post(
                f"{self.mcp_url}/mcp/message",
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=30
            )
            response.raise_for_status()
            result = response.json()

            if "error" in result:
                print(f"❌ Error: {result['error']}")
                return None

            print(f"✅ Success!")
            return result.get("result", {})

        except Exception as e:
            print(f"❌ Request failed: {e}")
            return None

    # =========================================================================
    # Workflow 1: Search for Satellite Imagery
    # =========================================================================

    def demo_search_workflow(self):
        """
        Demonstrates searching for existing satellite imagery.

        This workflow shows:
        1. Geocoding a location name to coordinates
        2. Searching archive imagery with filters
        """
        print("\n" + "="*70)
        print("WORKFLOW 1: Search for Satellite Imagery")
        print("="*70)
        print("\n🎯 Goal: Find recent satellite images of San Francisco")

        # Step 1: Geocode the location
        print("\n📍 Step 1: Convert 'San Francisco' to coordinates...")
        geocode_result = self.call_tool("geocode", {
            "query": "San Francisco, California, USA"
        })

        if not geocode_result:
            return

        bbox = geocode_result.get("boundingbox", [])
        print(f"   Found coordinates: {geocode_result.get('lat')}, {geocode_result.get('lon')}")
        print(f"   Bounding box: {bbox}")

        # Step 2: Search for imagery
        print("\n🛰️  Step 2: Search for satellite imagery...")

        # Calculate date range (last 30 days)
        end_date = datetime.now()
        start_date = end_date - timedelta(days=30)

        search_result = self.call_tool("search_archive", {
            "aoi": bbox,  # Use geocoded bounding box
            "start_date": start_date.isoformat() + "Z",
            "end_date": end_date.isoformat() + "Z",
            "cloud_cover_max": 20  # Less than 20% cloud cover
        })

        if search_result:
            images = search_result if isinstance(search_result, list) else []
            print(f"\n   Found {len(images)} images with <20% cloud cover")
            if images:
                print("\n   Sample result:")
                print(f"   - Image ID: {images[0].get('id')}")
                print(f"   - Date: {images[0].get('capture_date')}")
                print(f"   - Cloud Cover: {images[0].get('cloud_cover')}%")
                print(f"   - Resolution: {images[0].get('resolution')}m")

    # =========================================================================
    # Workflow 2: Check Feasibility for New Tasking
    # =========================================================================

    def demo_feasibility_workflow(self):
        """
        Demonstrates checking feasibility for new satellite tasking.

        This workflow shows:
        1. Geocoding a specific landmark
        2. Checking if new imagery can be captured
        3. Getting satellite pass times
        """
        print("\n" + "="*70)
        print("WORKFLOW 2: Check Satellite Tasking Feasibility")
        print("="*70)
        print("\n🎯 Goal: Can we capture new imagery of the Golden Gate Bridge?")

        # Step 1: Geocode the landmark
        print("\n📍 Step 1: Find coordinates for Golden Gate Bridge...")
        geocode_result = self.call_tool("geocode", {
            "query": "Golden Gate Bridge, San Francisco"
        })

        if not geocode_result:
            return

        lat = geocode_result.get("lat")
        lon = geocode_result.get("lon")
        print(f"   Coordinates: {lat}, {lon}")

        # Step 2: Check feasibility
        print("\n🛰️  Step 2: Check if satellite can capture this area...")

        # Calculate date range (next 14 days)
        start_date = datetime.now()
        end_date = start_date + timedelta(days=14)

        # Create a small bounding box around the point
        bbox = [
            float(lon) - 0.01,  # min_lon
            float(lat) - 0.01,  # min_lat
            float(lon) + 0.01,  # max_lon
            float(lat) + 0.01   # max_lat
        ]

        feasibility_result = self.call_tool("check_feasibility", {
            "aoi": bbox,
            "start_date": start_date.isoformat() + "Z",
            "end_date": end_date.isoformat() + "Z",
            "sensor_type": "optical"  # or "sar" for radar
        })

        if feasibility_result:
            print(f"\n   ✅ Feasibility: {feasibility_result.get('success_probability', 0)*100:.1f}%")
            pass_times = feasibility_result.get("pass_times", [])
            print(f"   📅 Satellite pass times: {len(pass_times)} opportunities")
            if pass_times:
                print(f"      Next pass: {pass_times[0]}")

    # =========================================================================
    # Workflow 3: Get Pricing Estimate
    # =========================================================================

    def demo_pricing_workflow(self):
        """
        Demonstrates getting pricing for satellite imagery.

        This workflow shows:
        1. Getting price estimate for tasking
        2. Understanding cost breakdown
        """
        print("\n" + "="*70)
        print("WORKFLOW 3: Get Pricing Estimate")
        print("="*70)
        print("\n🎯 Goal: How much would new imagery cost?")

        # Define area of interest (small area in San Francisco)
        bbox = [-122.42, 37.77, -122.40, 37.79]

        print("\n💰 Step 1: Get price estimate for tasking...")

        start_date = datetime.now()
        end_date = start_date + timedelta(days=7)

        pricing_result = self.call_tool("get_price_estimate", {
            "aoi": bbox,
            "start_date": start_date.isoformat() + "Z",
            "end_date": end_date.isoformat() + "Z",
            "sensor_type": "optical",
            "resolution": 0.5  # 50cm resolution
        })

        if pricing_result:
            print(f"\n   Total Cost: ${pricing_result.get('total_cost', 0):,.2f}")
            breakdown = pricing_result.get("breakdown", {})
            if breakdown:
                print(f"   Breakdown:")
                print(f"   - Base Price: ${breakdown.get('base_price', 0):,.2f}")
                print(f"   - Area Cost: ${breakdown.get('area_cost', 0):,.2f}")
                print(f"   - Priority Fee: ${breakdown.get('priority_fee', 0):,.2f}")
            print(f"   Currency: {pricing_result.get('currency', 'USD')}")

    # =========================================================================
    # Workflow 4: Set Up Area Monitoring
    # =========================================================================

    def demo_monitoring_workflow(self, webhook_url: str = "https://webhook.site/your-unique-id"):
        """
        Demonstrates setting up automated monitoring for an area.

        This workflow shows:
        1. Geocoding an area
        2. Setting up a monitor with webhook notifications
        3. Configuring monitoring criteria

        Args:
            webhook_url: Webhook URL to receive notifications (get one from webhook.site)
        """
        print("\n" + "="*70)
        print("WORKFLOW 4: Set Up Area Monitoring")
        print("="*70)
        print("\n🎯 Goal: Get notified when new imagery is available")

        # Step 1: Geocode the area
        print("\n📍 Step 1: Find coordinates for Paris, France...")
        geocode_result = self.call_tool("geocode", {
            "query": "Paris, France"
        })

        if not geocode_result:
            return

        bbox = geocode_result.get("boundingbox", [])
        print(f"   Bounding box: {bbox}")

        # Step 2: Set up monitoring
        print(f"\n🔔 Step 2: Set up monitoring with webhook...")
        print(f"   Webhook URL: {webhook_url}")

        monitor_result = self.call_tool("setup_monitor", {
            "aoi": bbox,
            "webhook_url": webhook_url,
            "cloud_cover_max": 30,  # Alert for images with <30% clouds
            "sensor_types": ["optical"],
            "check_interval": 86400,  # Check daily (in seconds)
            "api_key": self.api_key  # Required for monitors
        })

        if monitor_result:
            print(f"\n   ✅ Monitor created!")
            print(f"   Monitor ID: {monitor_result.get('monitor_id')}")
            print(f"   Status: {monitor_result.get('status')}")
            print(f"   Next check: {monitor_result.get('next_check_at')}")
            print(f"\n   💡 You'll receive webhook notifications when new imagery is found!")

    # =========================================================================
    # Workflow 5: Review Order History
    # =========================================================================

    def demo_orders_workflow(self):
        """
        Demonstrates reviewing order history.

        This workflow shows:
        1. Listing all orders
        2. Filtering by status
        3. Understanding order metadata
        """
        print("\n" + "="*70)
        print("WORKFLOW 5: Review Order History")
        print("="*70)
        print("\n🎯 Goal: See my recent satellite imagery orders")

        print("\n📋 Step 1: List all recent orders...")

        orders_result = self.call_tool("list_orders", {
            "limit": 10,
            "offset": 0
        })

        if orders_result:
            orders = orders_result.get("orders", [])
            print(f"\n   Found {len(orders)} recent orders")

            if orders:
                print("\n   Recent orders:")
                for i, order in enumerate(orders[:3], 1):
                    print(f"\n   {i}. Order #{order.get('id')}")
                    print(f"      Status: {order.get('status')}")
                    print(f"      Created: {order.get('created_at')}")
                    print(f"      Cost: ${order.get('total_cost', 0):,.2f}")

        # Filter by status
        print("\n📋 Step 2: Filter by pending orders...")

        pending_result = self.call_tool("list_orders", {
            "status_filter": "pending",
            "limit": 5
        })

        if pending_result:
            pending_orders = pending_result.get("orders", [])
            print(f"\n   Pending orders: {len(pending_orders)}")


def main():
    """Run all demo workflows."""
    print("""
╔═══════════════════════════════════════════════════════════════════╗
║                                                                     ║
║              SkyFi MCP Demo Agent - Interactive Tour               ║
║                                                                     ║
║  This demo showcases satellite imagery workflows using the         ║
║  SkyFi Model Context Protocol server.                              ║
║                                                                     ║
╚═══════════════════════════════════════════════════════════════════╝
    """)

    # Initialize the demo agent
    # Note: API key can be set here or in the MCP server's environment
    demo = SkyFiMCPDemo(
        mcp_url="http://localhost:4000",
        skyfi_api_key=None  # Set to your API key or leave None if server has it
    )

    # Run all workflows
    try:
        demo.demo_search_workflow()

        input("\n\nPress Enter to continue to Workflow 2...")
        demo.demo_feasibility_workflow()

        input("\n\nPress Enter to continue to Workflow 3...")
        demo.demo_pricing_workflow()

        input("\n\nPress Enter to continue to Workflow 4...")
        print("\n💡 Note: Replace webhook URL with your own from https://webhook.site")
        demo.demo_monitoring_workflow(webhook_url="https://webhook.site/your-unique-id")

        input("\n\nPress Enter to continue to Workflow 5...")
        demo.demo_orders_workflow()

    except KeyboardInterrupt:
        print("\n\n👋 Demo interrupted by user. Goodbye!")
        return

    print("\n" + "="*70)
    print("✅ Demo Complete!")
    print("="*70)
    print("""
🎉 Congratulations! You've seen all 8 SkyFi MCP tools in action:

   1. geocode - Convert locations to coordinates
   2. reverse_geocode - Convert coordinates to locations
   3. search_archive - Find existing imagery
   4. check_feasibility - Check if new imagery can be captured
   5. get_price_estimate - Get pricing for imagery
   6. place_order - Purchase imagery (not shown for safety)
   7. list_orders - View order history
   8. setup_monitor - Set up automated monitoring

📚 Next Steps:
   - Modify this script to explore your own areas of interest
   - Try the Claude Desktop integration for natural language queries
   - Deploy your own MCP server to Fly.io
   - Build your own AI agent using these tools!

🔗 Resources:
   - GitHub: https://github.com/anthropics/skyfi_mcp
   - Docs: See README.md in the project root
   - MCP Protocol: https://modelcontextprotocol.io

    """)


if __name__ == "__main__":
    main()
