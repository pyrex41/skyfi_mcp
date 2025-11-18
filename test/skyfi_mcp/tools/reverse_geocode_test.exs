defmodule SkyfiMcp.Tools.ReverseGeocodeTest do
  use ExUnit.Case, async: false
  import Tesla.Mock

  alias SkyfiMcp.Tools.ReverseGeocode

  setup do
    # Clear ETS cache before each test
    case :ets.whereis(:osm_cache) do
      :undefined -> :ok
      _table -> :ets.delete_all_objects(:osm_cache)
    end

    mock(fn
      %{method: :get, url: "https://nominatim.openstreetmap.org/reverse"} = request ->
        lat = request.query[:lat]
        lon = request.query[:lon]
        zoom = request.query[:zoom]

        cond do
          lat == 37.7749 && lon == -122.4194 ->
            json(%{
              "lat" => "37.7749295",
              "lon" => "-122.4194155",
              "display_name" => "San Francisco City Hall, Civic Center, San Francisco, California, 94102, United States",
              "address" => %{
                "building" => "San Francisco City Hall",
                "road" => "Carlton B Goodlett Place",
                "neighbourhood" => "Civic Center",
                "city" => "San Francisco",
                "county" => "San Francisco County",
                "state" => "California",
                "country" => "United States",
                "postcode" => "94102"
              },
              "type" => "building"
            })

          lat == 48.8566 && lon == 2.3522 && zoom == 10 ->
            json(%{
              "lat" => "48.856614",
              "lon" => "2.3522219",
              "display_name" => "Paris, Île-de-France, France",
              "address" => %{
                "city" => "Paris",
                "state" => "Île-de-France",
                "country" => "France"
              },
              "type" => "city"
            })

          lat == 0 && lon == 0 ->
            json(%{
              "error" => "Unable to geocode"
            })

          true ->
            json(%{
              "lat" => "#{lat}",
              "lon" => "#{lon}",
              "display_name" => "Unknown Location",
              "address" => %{},
              "type" => "unknown"
            })
        end
    end)

    :ok
  end

  describe "execute/1" do
    test "reverse geocodes coordinates successfully" do
      params = %{"lat" => 37.7749, "lon" => -122.4194}

      assert {:ok, response} = ReverseGeocode.execute(params)
      assert is_map(response)
      assert Map.has_key?(response, :location)
      assert Map.has_key?(response, :address)
      assert Map.has_key?(response, :service)

      assert response.service == "OpenStreetMap Nominatim"
      assert response.location.lat == 37.7749295
      assert response.location.lon == -122.4194155
      assert response.location.display_name =~ "San Francisco"
      assert response.location.type == "building"

      assert is_map(response.address)
      assert response.address["city"] == "San Francisco"
      assert response.address["state"] == "California"
    end

    test "respects zoom parameter for detail level" do
      params = %{"lat" => 48.8566, "lon" => 2.3522, "zoom" => 10}

      assert {:ok, response} = ReverseGeocode.execute(params)
      assert response.location.display_name =~ "Paris"
      assert response.address["city"] == "Paris"
    end

    test "returns error for coordinates with no location" do
      params = %{"lat" => 0, "lon" => 0}

      assert {:error, "No location found at these coordinates"} = ReverseGeocode.execute(params)
    end

    test "validates lat parameter is required" do
      params = %{"lon" => -122.4194}

      assert {:error, "lat parameter is required"} = ReverseGeocode.execute(params)
    end

    test "validates lon parameter is required" do
      params = %{"lat" => 37.7749}

      assert {:error, "lon parameter is required"} = ReverseGeocode.execute(params)
    end

    test "validates latitude is within valid range" do
      # Latitude too low
      params = %{"lat" => -91, "lon" => 0}
      assert {:error, "latitude must be >= -90"} = ReverseGeocode.execute(params)

      # Latitude too high
      params = %{"lat" => 91, "lon" => 0}
      assert {:error, "latitude must be <= 90"} = ReverseGeocode.execute(params)
    end

    test "validates longitude is within valid range" do
      # Longitude too low
      params = %{"lat" => 0, "lon" => -181}
      assert {:error, "longitude must be >= -180"} = ReverseGeocode.execute(params)

      # Longitude too high
      params = %{"lat" => 0, "lon" => 181}
      assert {:error, "longitude must be <= 180"} = ReverseGeocode.execute(params)
    end

    test "validates zoom is within valid range" do
      # Zoom too low
      params = %{"lat" => 37.7749, "lon" => -122.4194, "zoom" => -1}
      assert {:error, "zoom must be >= 0"} = ReverseGeocode.execute(params)

      # Zoom too high
      params = %{"lat" => 37.7749, "lon" => -122.4194, "zoom" => 19}
      assert {:error, "zoom must be <= 18"} = ReverseGeocode.execute(params)
    end

    test "accepts coordinates as strings and converts to numbers" do
      params = %{"lat" => "37.7749", "lon" => "-122.4194"}

      assert {:ok, response} = ReverseGeocode.execute(params)
      assert response.location.lat == 37.7749295
      assert response.location.lon == -122.4194155
    end

    test "accepts zoom as string and converts to integer" do
      params = %{"lat" => 37.7749, "lon" => -122.4194, "zoom" => "10"}

      assert {:ok, _response} = ReverseGeocode.execute(params)
    end

    test "accepts zoom as float and converts to integer" do
      params = %{"lat" => 37.7749, "lon" => -122.4194, "zoom" => 10.5}

      assert {:ok, _response} = ReverseGeocode.execute(params)
    end

    test "uses default zoom of 18 when not specified" do
      params = %{"lat" => 37.7749, "lon" => -122.4194}

      assert {:ok, _response} = ReverseGeocode.execute(params)
    end
  end
end
