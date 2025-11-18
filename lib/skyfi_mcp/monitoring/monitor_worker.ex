defmodule SkyfiMcp.Monitoring.MonitorWorker do
  @moduledoc """
  Background worker that periodically checks monitors and delivers webhook notifications.

  Runs every 60 seconds to check for monitors due for checking.
  """

  use GenServer
  require Logger

  alias SkyfiMcp.Monitoring
  alias SkyfiMcp.Monitoring.WebhookNotifier
  alias SkyfiMcp.SkyfiClient

  @check_interval 60_000  # Check every 60 seconds
  @initial_delay 5_000  # Wait 5 seconds after startup

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the current status of the worker.
  """
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @impl true
  def init(_opts) do
    Logger.info("MonitorWorker: Starting background monitor worker")
    schedule_check(@initial_delay)
    {:ok, %{checks_performed: 0, last_check: nil}}
  end

  @impl true
  def handle_info(:check_monitors, state) do
    Logger.debug("MonitorWorker: Checking for monitors due for checking")

    start_time = System.monotonic_time()

    monitors = Monitoring.list_active_monitors_due_for_check()

    Logger.info("MonitorWorker: Found #{length(monitors)} monitors to check")

    # Process each monitor
    results = Enum.map(monitors, &check_monitor/1)

    successes = Enum.count(results, &match?({:ok, _}, &1))
    failures = Enum.count(results, &match?({:error, _}, &1))

    elapsed_ms =
      System.convert_time_unit(
        System.monotonic_time() - start_time,
        :native,
        :millisecond
      )

    Logger.info(
      "MonitorWorker: Completed check cycle - " <>
        "#{successes} successful, #{failures} failed, #{elapsed_ms}ms elapsed"
    )

    # Schedule next check
    schedule_check(@check_interval)

    new_state = %{
      state
      | checks_performed: state.checks_performed + 1,
        last_check: DateTime.utc_now()
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, state, state}
  end

  defp schedule_check(delay) do
    Process.send_after(self(), :check_monitors, delay)
  end

  defp check_monitor(monitor) do
    Logger.debug("MonitorWorker: Checking monitor #{monitor.id}")

    with {:ok, new_images} <- fetch_new_images(monitor),
         {:ok, _} <- notify_if_new_images(monitor, new_images),
         {:ok, _} <- update_monitor_state(monitor, new_images) do
      {:ok, monitor.id}
    else
      {:error, reason} = error ->
        Logger.error(
          "MonitorWorker: Failed to check monitor #{monitor.id}: #{inspect(reason)}"
        )

        # Don't mark as failed immediately - could be temporary network issue
        # Only mark failed after repeated webhook delivery failures
        error
    end
  end

  defp fetch_new_images(monitor) do
    # Call SkyFi API to search for imagery matching monitor criteria
    params = build_search_params(monitor)

    case SkyfiClient.search_archive(params) do
      {:ok, response} ->
        images = extract_images(response)
        new_images = filter_new_images(images, monitor.last_image_id)
        {:ok, new_images}

      {:error, reason} ->
        Logger.warning(
          "MonitorWorker: SkyFi API error for monitor #{monitor.id}: #{inspect(reason)}"
        )

        {:error, {:api_error, reason}}
    end
  end

  defp build_search_params(monitor) do
    # Build params from monitor AOI and criteria
    %{
      "aoi" => monitor.aoi,
      "start_date" => get_search_start_date(monitor),
      "end_date" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "cloud_cover_max" => monitor.criteria["cloud_cover_max"] || 100
    }
  end

  defp get_search_start_date(monitor) do
    # Search from last check or past 30 days, whichever is more recent
    default_start = DateTime.utc_now() |> DateTime.add(-30, :day)

    case monitor.last_checked_at do
      nil -> DateTime.to_iso8601(default_start)
      last_check -> DateTime.to_iso8601(Enum.max([last_check, default_start], DateTime))
    end
  end

  defp extract_images(%{"data" => images}) when is_list(images), do: images
  defp extract_images(_), do: []

  defp filter_new_images(images, nil), do: images

  defp filter_new_images(images, last_image_id) do
    # Return only images captured after the last known image
    # This assumes images are sorted by capture date (newest first)
    Enum.take_while(images, fn img -> img["id"] != last_image_id end)
  end

  defp notify_if_new_images(_monitor, []), do: {:ok, :no_new_images}

  defp notify_if_new_images(monitor, new_images) when length(new_images) > 0 do
    WebhookNotifier.deliver(monitor, new_images)
  end

  defp update_monitor_state(monitor, images) do
    latest_image_id =
      case images do
        [first | _] -> first["id"]
        [] -> monitor.last_image_id
      end

    Monitoring.update_monitor_check(monitor, latest_image_id)
  end
end
