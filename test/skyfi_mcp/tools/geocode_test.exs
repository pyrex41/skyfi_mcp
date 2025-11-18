defmodule SkyfiMcp.Tools.GeocodeTest do
  use ExUnit.Case, async: false
  import Tesla.Mock

  alias SkyfiMcp.Tools.Geocode

  setup do
    # Clear ETS cache before each test
    case :ets.whereis(:osm_cache) do
      :undefined -> :ok
      _table -> :ets.delete_all_objects(:osm_cache)
    end

    mock(fn
      %{method: :get, url: "https://nominatim.openstreetmap.org/search"} = request ->
        query = request.query[:q]
        limit = request.query[:limit]

        cond do
          query == "San Francisco, CA" ->
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

          query == "Springfield" && limit == 3 ->
            json([
              %{
                "lat" => "39.7817",
                "lon" => "-89.6501",
                "display_name" => "Springfield, Illinois, USA",
                "type" => "city",
                "importance" => 0.7,
                "boundingbox" => ["39.7", "39.8", "-89.7", "-89.6"]
              },
              %{
                "lat" => "42.1015",
                "lon" => "-72.5898",
                "display_name" => "Springfield, Massachusetts, USA",
                "type" => "city",
                "importance" => 0.68,
                "boundingbox" => ["42.0", "42.2", "-72.6", "-72.5"]
              },
              %{
                "lat" => "37.2153",
                "lon" => "-93.2982",
                "display_name" => "Springfield, Missouri, USA",
                "type" => "city",
                "importance" => 0.66,
                "boundingbox" => ["37.1", "37.3", "-93.4", "-93.2"]
              }
            ])

          query == "NonexistentPlace12345" ->
            json([])

          true ->
            json([
              %{
                "lat" => "0",
                "lon" => "0",
                "display_name" => "Default Location",
                "type" => "place",
                "importance" => 0.5,
                "boundingbox" => ["-1", "1", "-1", "1"]
              }
            ])
        end
    end)

    :ok
  end

  describe "execute/1" do
    test "geocodes a location successfully" do
      params = %{"query" => "San Francisco, CA"}

      assert {:ok, response} = Geocode.execute(params)
      assert is_map(response)
      assert Map.has_key?(response, :results)
      assert Map.has_key?(response, :count)
      assert Map.has_key?(response, :service)

      assert response.count == 1
      assert response.service == "OpenStreetMap Nominatim"

      result = List.first(response.results)
      assert result.lat == 37.7749295
      assert result.lon == -122.4194155
      assert result.display_name =~ "San Francisco"
      assert result.type == "city"
    end

    test "returns empty results for nonexistent location" do
      params = %{"query" => "NonexistentPlace12345"}

      assert {:ok, response} = Geocode.execute(params)
      assert response.count == 0
      assert response.results == []
    end

    test "respects limit parameter" do
      params = %{"query" => "Springfield", "limit" => 3}

      assert {:ok, response} = Geocode.execute(params)
      assert response.count == 3
      assert length(response.results) == 3
    end

    test "validates query parameter is required" do
      params = %{}

      assert {:error, "query parameter is required"} = Geocode.execute(params)
    end

    test "validates query is non-empty string" do
      params = %{"query" => ""}

      assert {:error, "query must be a non-empty string"} = Geocode.execute(params)
    end

    test "validates limit is within range" do
      # Limit too low
      params = %{"query" => "Paris", "limit" => 0}
      assert {:error, "limit must be at least 1"} = Geocode.execute(params)

      # Limit too high
      params = %{"query" => "Paris", "limit" => 51}
      assert {:error, "limit cannot exceed 50"} = Geocode.execute(params)
    end

    test "accepts limit as string and converts to integer" do
      params = %{"query" => "Paris", "limit" => "3"}

      assert {:ok, _response} = Geocode.execute(params)
    end

    test "accepts country_codes parameter" do
      params = %{"query" => "Paris", "country_codes" => "fr"}

      assert {:ok, _response} = Geocode.execute(params)
    end

    test "accepts viewbox parameter" do
      params = %{
        "query" => "Paris",
        "viewbox" => [-122.5, 37.7, -122.3, 37.8]
      }

      assert {:ok, _response} = Geocode.execute(params)
    end

    test "trims whitespace from query" do
      params = %{"query" => "  San Francisco  "}

      assert {:ok, response} = Geocode.execute(params)
      assert response.count == 1
    end
  end
end
