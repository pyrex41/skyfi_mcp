defmodule SkyfiMcp.Tools.SearchArchiveTest do
  use ExUnit.Case
  import Tesla.Mock

  alias SkyfiMcp.Tools.SearchArchive

  setup do
    # Configure API key for tests
    Application.put_env(:skyfi_mcp, :skyfi_api_key, "test_api_key")

    on_exit(fn ->
      Application.delete_env(:skyfi_mcp, :skyfi_api_key)
    end)

    :ok
  end

  test "executes search successfully with valid params" do
    mock(fn %{method: :get, url: "https://api.skyfi.com/archives"} ->
      json(%{
        "data" => [
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
