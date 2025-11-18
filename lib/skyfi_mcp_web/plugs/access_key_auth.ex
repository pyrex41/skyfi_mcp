defmodule SkyfiMcpWeb.Plugs.AccessKeyAuth do
  @moduledoc """
  Plug for authenticating MCP requests using access keys.

  Validates the Authorization header contains a valid access key
  and extracts the user's SkyFi API key from X-SkyFi-API-Key header.
  """

  import Plug.Conn
  require Logger

  alias SkyfiMcp.{Repo, AccessKey}
  import Ecto.Query

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, access_key_token} <- extract_access_key(conn),
         {:ok, access_key} <- validate_access_key(access_key_token),
         {:ok, skyfi_api_key} <- extract_skyfi_api_key(conn) do
      # Update last_used_at and increment request_count
      update_access_key_usage(access_key)

      conn
      |> assign(:access_key, access_key)
      |> assign(:skyfi_api_key, skyfi_api_key)
    else
      {:error, :missing_authorization} ->
        conn
        |> send_unauthorized("Missing Authorization header")
        |> halt()

      {:error, :invalid_format} ->
        conn
        |> send_unauthorized("Invalid Authorization format. Expected: Bearer sk_mcp_...")
        |> halt()

      {:error, :invalid_access_key} ->
        conn
        |> send_unauthorized("Invalid or inactive access key")
        |> halt()

      {:error, :missing_skyfi_key} ->
        conn
        |> send_bad_request("Missing X-SkyFi-API-Key header")
        |> halt()
    end
  end

  defp extract_access_key(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        {:ok, token}

      [_other] ->
        {:error, :invalid_format}

      [] ->
        {:error, :missing_authorization}
    end
  end

  defp validate_access_key(token) do
    query =
      from a in AccessKey,
        where: a.key == ^token and a.active == true

    case Repo.one(query) do
      nil ->
        Logger.warning("Invalid access key attempt: #{token}")
        {:error, :invalid_access_key}

      access_key ->
        {:ok, access_key}
    end
  end

  defp extract_skyfi_api_key(conn) do
    case get_req_header(conn, "x-skyfi-api-key") do
      [api_key] when byte_size(api_key) > 0 ->
        {:ok, api_key}

      _ ->
        {:error, :missing_skyfi_key}
    end
  end

  defp update_access_key_usage(access_key) do
    # Async update to not block the request
    Task.start(fn ->
      from(a in AccessKey, where: a.id == ^access_key.id)
      |> Repo.update_all(
        inc: [request_count: 1],
        set: [last_used_at: DateTime.utc_now()]
      )
    end)
  end

  defp send_unauthorized(conn, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: message}))
  end

  defp send_bad_request(conn, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(400, Jason.encode!(%{error: message}))
  end
end
