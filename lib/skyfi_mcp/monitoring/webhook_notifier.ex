defmodule SkyfiMcp.Monitoring.WebhookNotifier do
  @moduledoc """
  Handles webhook delivery with retry logic for monitor notifications.

  Uses exponential backoff for retries to handle temporary network issues.
  """

  use Tesla
  require Logger

  @max_retries 3
  @initial_retry_delay 1000  # 1 second
  @max_retry_delay 30_000  # 30 seconds

  plug Tesla.Middleware.BaseUrl, ""
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Timeout, timeout: 10_000  # 10 second timeout

  @doc """
  Delivers a webhook notification for new satellite imagery.

  ## Parameters

    - `monitor` - The Monitor struct
    - `new_images` - List of new image data from SkyFi API

  ## Returns

    - `{:ok, :delivered}` - Webhook delivered successfully
    - `{:error, :max_retries_exceeded}` - Failed after all retry attempts
  """
  def deliver(monitor, new_images) when is_list(new_images) and length(new_images) > 0 do
    payload = build_payload(monitor, new_images)

    Logger.info(
      "WebhookNotifier: Delivering #{length(new_images)} new images to #{monitor.webhook_url}"
    )

    deliver_with_retry(monitor.webhook_url, payload, 0)
  end

  def deliver(_monitor, []) do
    {:ok, :no_new_images}
  end

  defp deliver_with_retry(url, payload, attempt) when attempt < @max_retries do
    case post(url, payload) do
      {:ok, %Tesla.Env{status: status}} when status in 200..299 ->
        Logger.info("WebhookNotifier: Successfully delivered to #{url} (status: #{status})")
        {:ok, :delivered}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        Logger.warning(
          "WebhookNotifier: Webhook returned status #{status}: #{inspect(body)}"
        )

        retry_delivery(url, payload, attempt)

      {:error, reason} ->
        Logger.warning("WebhookNotifier: Delivery failed - #{inspect(reason)}")
        retry_delivery(url, payload, attempt)
    end
  end

  defp deliver_with_retry(url, _payload, _attempt) do
    Logger.error("WebhookNotifier: Max retries (#{@max_retries}) exceeded for #{url}")
    {:error, :max_retries_exceeded}
  end

  defp retry_delivery(url, payload, attempt) do
    delay = calculate_backoff(attempt)

    Logger.info(
      "WebhookNotifier: Retrying in #{delay}ms (attempt #{attempt + 1}/#{@max_retries})"
    )

    Process.sleep(delay)
    deliver_with_retry(url, payload, attempt + 1)
  end

  defp calculate_backoff(attempt) do
    # Exponential backoff: 1s, 2s, 4s, 8s, ... (capped at 30s)
    (@initial_retry_delay * :math.pow(2, attempt))
    |> min(@max_retry_delay)
    |> round()
  end

  defp build_payload(monitor, new_images) do
    %{
      monitor_id: monitor.id,
      aoi: monitor.aoi,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      new_images: format_images(new_images),
      image_count: length(new_images),
      criteria: monitor.criteria
    }
  end

  defp format_images(images) do
    Enum.map(images, fn img ->
      %{
        id: img["id"],
        capture_date: img["capture_date"],
        cloud_cover: img["cloud_cover"],
        thumbnail_url: img["thumbnail_url"],
        preview_url: img["preview_url"],
        sensor_type: img["sensor_type"] || "optical",
        resolution: img["resolution"]
      }
    end)
  end
end
