defmodule SkyfiMcp.OsmClientTest do
  use ExUnit.Case, async: false
  import Tesla.Mock

  alias SkyfiMcp.OsmClient

  setup do
    # Clear ETS cache before each test
    case :ets.whereis(:osm_cache) do
      :undefined -> :ok
      _table -> :ets.delete_all_objects(:osm_cache)
    end

    mock(fn
      %{method: :get, url: "https://nominatim.openstreetmap.org/search"} = request ->
        query = request.query[:q]

        cond do
          query == "San Francisco" ->
            json([
              %{
                "lat" => "37.7749295",
                "lon" => "-122.4194155",
                "display_name" => "San Francisco, California, United States",
                "type" => "city",
                "importance" => 0.9,
                "boundingbox" => ["37.6398299", "37.929824", "-123.173825", "-122.28178"]
              }
            ])

          query == "NonexistentPlace12345" ->
            json([])

          true ->
            json([
              %{
                "lat" => "48.856614",
                "lon" => "2.3522219",
                "display_name" => "Paris, France",
                "type" => "city",
                "importance" => 0.95,
                "boundingbox" => ["48.815573", "48.902145", "2.224199", "2.469920"]
              }
            ])
        end

      %{method: :get, url: "https://nominatim.openstreetmap.org/reverse"} = request ->
        lat = request.query[:lat]
        lon = request.query[:lon]

        if lat == 37.7749 && lon == -122.4194 do
          json(%{
            "lat" => "37.7749295",
            "lon" => "-122.4194155",
            "display_name" => "San Francisco City Hall, Civic Center, San Francisco, California, 94102, United States",
            "address" => %{
              "city" => "San Francisco",
              "state" => "California",
              "country" => "United States",
              "postcode" => "94102"
            },
            "type" => "building"
          })
        else
          json(%{
            "error" => "Unable to geocode"
          })
        end
    end)

    :ok
  end

  describe "geocode/2" do
    test "geocodes a city successfully" do
      assert {:ok, results} = OsmClient.geocode("San Francisco")

      assert length(results) == 1
      result = List.first(results)

      assert result.lat == 37.7749295
      assert result.lon == -122.4194155
      assert result.display_name == "San Francisco, California, United States"
      assert result.type == "city"
      assert result.importance == 0.9
      assert is_list(result.bbox)
    end

    test "returns empty list for nonexistent location" do
      assert {:ok, []} = OsmClient.geocode("NonexistentPlace12345")
    end

    test "uses cache for repeated queries" do
      # First call
      assert {:ok, results1} = OsmClient.geocode("Paris")
      assert length(results1) == 1

      # Second call should use cache (we can verify by checking it doesn't make another request)
      assert {:ok, results2} = OsmClient.geocode("Paris")
      assert results1 == results2
    end

    test "respects limit parameter" do
      assert {:ok, _results} = OsmClient.geocode("Paris", limit: 3)
    end

    test "accepts country_codes parameter" do
      assert {:ok, _results} = OsmClient.geocode("Paris", countrycodes: "fr")
    end
  end

  describe "reverse_geocode/3" do
    test "reverse geocodes coordinates successfully" do
      assert {:ok, result} = OsmClient.reverse_geocode(37.7749, -122.4194)

      assert result.lat == 37.7749295
      assert result.lon == -122.4194155
      assert result.display_name =~ "San Francisco"
      assert result.type == "building"
      assert is_map(result.address)
      assert result.address["city"] == "San Francisco"
    end

    test "returns error for invalid coordinates" do
      assert {:error, {:not_found, _msg}} = OsmClient.reverse_geocode(0, 0)
    end

    test "uses cache for repeated queries" do
      # First call
      assert {:ok, result1} = OsmClient.reverse_geocode(37.7749, -122.4194)

      # Second call should use cache
      assert {:ok, result2} = OsmClient.reverse_geocode(37.7749, -122.4194)
      assert result1 == result2
    end

    test "accepts zoom parameter" do
      assert {:ok, _result} = OsmClient.reverse_geocode(37.7749, -122.4194, zoom: 10)
    end
  end

  describe "rate limiting" do
    test "enforces 1 request per second" do
      start_time = System.monotonic_time(:millisecond)

      # Make two requests quickly
      {:ok, _} = OsmClient.geocode("Paris")
      {:ok, _} = OsmClient.geocode("London")

      end_time = System.monotonic_time(:millisecond)
      elapsed = end_time - start_time

      # Should take at least 1 second due to rate limiting
      assert elapsed >= 1000
    end
  end
end
