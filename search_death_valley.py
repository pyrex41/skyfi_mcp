#!/usr/bin/env python3
"""
Quick script to search for satellite imagery of Death Valley.
"""

import json
import sys
from datetime import datetime, timedelta


def call_mcp_tool(tool_name, arguments):
    """Call an MCP tool via HTTP endpoint."""
    import requests
    import os

    # Get credentials
    access_key = "sk_mcp_cabec379136b4d3a0b07f275257b1ef4508d494aff7e049680b9c31ae962ccd7"
    skyfi_api_key = os.getenv("SKYFI_API_KEY", "YOUR_SKYFI_API_KEY_HERE")

    payload = {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": tool_name,
            "arguments": arguments
        },
        "id": 1
    }

    try:
        response = requests.post(
            "http://localhost:4000/mcp/message",
            json=payload,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {access_key}",
                "X-SkyFi-API-Key": skyfi_api_key
            },
            timeout=30
        )
        response.raise_for_status()
        result = response.json()

        if "error" in result:
            print(f"❌ Error: {result['error']}")
            return None

        return result.get("result", {})

    except requests.exceptions.RequestException as e:
        print(f"❌ Request failed: {e}")
        return None
    except json.JSONDecodeError as e:
        print(f"❌ Failed to parse response: {e}")
        return None
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return None


def main():
    print("\n" + "="*70)
    print("🏜️  Searching for Death Valley Satellite Imagery")
    print("="*70)

    # Step 1: Geocode Death Valley
    print("\n📍 Step 1: Converting 'Death Valley' to coordinates...")
    geocode_result = call_mcp_tool("geocode", {
        "query": "Death Valley, California, USA"
    })

    if not geocode_result or "content" not in geocode_result:
        print("Failed to geocode Death Valley")
        sys.exit(1)

    # Extract location data from content array
    content = geocode_result.get("content", [])
    if content and len(content) > 0:
        location_text = content[0].get("text", "")
        print(f"✅ {location_text}")

        # Parse the location data (it should be JSON in the text field)
        try:
            location_data = json.loads(location_text)
            results = location_data.get("results", [])

            if results and len(results) > 0:
                first_result = results[0]
                bbox = first_result.get("bbox", [])
                lat = first_result.get("lat")
                lon = first_result.get("lon")
                display_name = first_result.get("display_name")

                print(f"   Location: {display_name}")
                print(f"   Coordinates: {lat}, {lon}")
                print(f"   Bounding box: {bbox}")
            else:
                print("   No results found")
                bbox = None
        except json.JSONDecodeError:
            print(f"   Raw result: {location_text[:200]}")
            bbox = None
    else:
        print("No geocoding data returned")
        sys.exit(1)

    # Step 2: Search for imagery
    if bbox and len(bbox) == 4:
        print("\n🛰️  Step 2: Searching for satellite imagery...")

        # Calculate date range (last 90 days for better chances)
        end_date = datetime.now()
        start_date = end_date - timedelta(days=90)

        search_result = call_mcp_tool("search_archive", {
            "aoi": [float(x) for x in bbox],  # Convert to floats
            "start_date": start_date.isoformat() + "Z",
            "end_date": end_date.isoformat() + "Z",
            "cloud_cover_max": 30  # Death Valley is usually clear
        })

        if search_result and "content" in search_result:
            content = search_result.get("content", [])
            if content and len(content) > 0:
                result_text = content[0].get("text", "")
                print(f"\n✅ Search complete!")

                try:
                    images = json.loads(result_text)
                    if isinstance(images, list):
                        print(f"\n📸 Found {len(images)} images with <30% cloud cover\n")

                        for i, img in enumerate(images[:5], 1):  # Show first 5
                            print(f"   Image {i}:")
                            print(f"   - ID: {img.get('id')}")
                            print(f"   - Date: {img.get('capture_date')}")
                            print(f"   - Cloud Cover: {img.get('cloud_cover')}%")
                            print(f"   - Resolution: {img.get('resolution')}m")
                            print(f"   - Sensor: {img.get('sensor_type')}")
                            print()
                    else:
                        print(f"   Result: {result_text[:200]}")
                except json.JSONDecodeError:
                    print(f"   Raw result: {result_text[:200]}")
        else:
            print("❌ No imagery found or search failed")
    else:
        print("❌ Invalid bounding box from geocoding")

    print("\n" + "="*70)


if __name__ == "__main__":
    main()
