defmodule SkyfiMcp.ErrorHandler do
  @moduledoc """
  Centralized error handling for user-friendly error messages.

  Maps API errors, validation errors, and network errors to helpful messages
  that guide users toward resolving issues.
  """

  require Logger

  @doc """
  Handles Tesla HTTP errors from SkyFi API and returns user-friendly messages.
  """
  def handle_api_error({:error, %Tesla.Env{status: status, body: body}}) do
    case status do
      401 ->
        Logger.error("SkyFi API: Invalid API key (401)")
        {:error, "Invalid SkyFi API key. Please check your credentials."}

      403 ->
        Logger.error("SkyFi API: Access denied (403)")
        {:error, "Access denied. Please verify your API key has the required permissions."}

      404 ->
        Logger.error("SkyFi API: Resource not found (404)")
        {:error, "Resource not found. The requested data may have been removed."}

      429 ->
        Logger.warning("SkyFi API: Rate limit exceeded (429)")
        {:error, "Rate limit exceeded. Please try again in a moment."}

      400 ->
        message = extract_error_message(body)
        Logger.warning("SkyFi API: Bad request (400): #{inspect(message)}")
        {:error, "Invalid request: #{message}"}

      status when status >= 500 and status < 600 ->
        message = extract_error_message(body)
        Logger.error("SkyFi API: Server error (#{status}): #{inspect(message)}")
        {:error, "SkyFi service temporarily unavailable (#{status}). Please try again later."}

      _ ->
        Logger.error("SkyFi API: Unexpected status (#{status})")
        {:error, "Unexpected API response (#{status}). Please contact support."}
    end
  end

  def handle_api_error({:error, :timeout}) do
    Logger.error("SkyFi API: Request timeout")
    {:error, "Request timed out. The SkyFi service may be slow. Please try again."}
  end

  def handle_api_error({:error, :econnrefused}) do
    Logger.error("SkyFi API: Connection refused")
    {:error, "Unable to connect to SkyFi. Please check your internet connection."}
  end

  def handle_api_error({:error, reason}) when is_atom(reason) do
    Logger.error("SkyFi API: Network error: #{reason}")
    {:error, "Network error: #{reason}. Please check your connection and try again."}
  end

  def handle_api_error({:error, reason}) do
    Logger.error("SkyFi API: Unknown error: #{inspect(reason)}")
    {:error, "An unexpected error occurred. Please try again."}
  end

  @doc """
  Handles Ecto validation errors and returns user-friendly messages.
  """
  def handle_validation_error(%Ecto.Changeset{} = changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)

    formatted_errors =
      errors
      |> Enum.map(fn {field, messages} ->
        "#{field}: #{Enum.join(messages, ", ")}"
      end)
      |> Enum.join("; ")

    {:error, "Validation failed: #{formatted_errors}"}
  end

  @doc """
  Handles OpenStreetMap API errors.
  """
  def handle_osm_error({:error, :rate_limited}) do
    {:error, "OpenStreetMap rate limit reached. Please wait a moment before searching again."}
  end

  def handle_osm_error({:error, :not_found}) do
    {:error, "Location not found. Please try a different search term or be more specific."}
  end

  def handle_osm_error({:error, reason}) when is_binary(reason) do
    {:error, reason}
  end

  def handle_osm_error({:error, reason}) do
    Logger.error("OSM API error: #{inspect(reason)}")
    {:error, "Geocoding service error. Please try again."}
  end

  @doc """
  Emits telemetry event for errors (useful for monitoring).
  """
  def emit_error_telemetry(tool_name, error_type) do
    :telemetry.execute(
      [:skyfi_mcp, :tool, :error],
      %{count: 1},
      %{tool: tool_name, error_type: error_type}
    )
  end

  # Private helpers

  defp extract_error_message(body) when is_map(body) do
    cond do
      Map.has_key?(body, "error") -> body["error"]
      Map.has_key?(body, "message") -> body["message"]
      Map.has_key?(body, "errors") -> Enum.join(body["errors"], ", ")
      true -> "Unknown error"
    end
  end

  defp extract_error_message(body) when is_binary(body), do: body
  defp extract_error_message(_), do: "Unknown error"
end
