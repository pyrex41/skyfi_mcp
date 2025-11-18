defmodule SkyfiMcp.Tools.SearchArchiveTest do
  use ExUnit.Case
  import Tesla.Mock

  alias SkyfiMcp.Tools.SearchArchive

  setup do
    mock(fn
      %{method: :post, url: "https://api.skyfi.com/archive/search"} ->
        json(%{
          data: [
            %{
              "id" => "img_1",
              "capture_date" => "2023-01-01T12:00:00Z",
              "cloud_cover" => 10,
              "thumbnail_url" => "http://example.com/thumb.jpg",
              "preview_url" => "http://example.com/preview.jpg",
              "resolution" => 0.5,
              "sensor_type" => "optical"
            }
          ]
        })
    end)

    :ok
  end

  test "executes search successfully with valid params" do
    params = %{
      "aoi" => [0, 0, 1, 1],
      "start_date" => "2023-01-01T00:00:00Z",
      "end_date" => "2023-01-31T23:59:59Z"
    }

    assert {:ok, results} = SearchArchive.execute(params)
    assert length(results) == 1
    first = List.first(results)
    assert first.id == "img_1"
    assert first.cloud_cover == 10
  end

  test "returns error when required params are missing" do
    assert {:error, "Missing required parameter: aoi"} = SearchArchive.execute(%{})
  end
end
