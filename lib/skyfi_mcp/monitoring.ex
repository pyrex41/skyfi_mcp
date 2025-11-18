defmodule SkyfiMcp.Monitoring do
  @moduledoc """
  Business logic for monitoring satellite imagery.

  Provides functions for creating, managing, and querying monitors.
  """

  import Ecto.Query
  require Logger

  alias SkyfiMcp.{Repo, Monitor}

  @doc """
  Creates a new monitor with the given attributes.

  ## Examples

      iex> create_monitor(%{aoi: geojson, webhook_url: "https://example.com/hook", ...})
      {:ok, %Monitor{}}

      iex> create_monitor(%{invalid: "data"})
      {:error, %Ecto.Changeset{}}
  """
  def create_monitor(attrs) do
    %Monitor{}
    |> Monitor.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a single monitor by ID.

  Returns nil if the monitor does not exist.
  """
  def get_monitor(id), do: Repo.get(Monitor, id)

  @doc """
  Gets a monitor by ID, raising if not found.
  """
  def get_monitor!(id), do: Repo.get!(Monitor, id)

  @doc """
  Lists all monitors for a given user (by API key hash).
  """
  def list_monitors_by_user(api_key_hash) do
    from(m in Monitor,
      where: m.user_api_key_hash == ^api_key_hash,
      order_by: [desc: m.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Lists active monitors that are due for checking.

  A monitor is due for checking if:
  - It has never been checked (last_checked_at is nil), OR
  - The time since last_checked_at exceeds the check_interval

  Returns monitors ordered by last_checked_at (oldest first).
  """
  def list_active_monitors_due_for_check do
    now = DateTime.utc_now()

    from(m in Monitor,
      where: m.status == "active",
      where:
        is_nil(m.last_checked_at) or
          fragment(
            "datetime(?, 'unixepoch') <= datetime(?, 'unixepoch')",
            fragment("unixepoch(?) + ?", m.last_checked_at, m.check_interval),
            ^DateTime.to_unix(now)
          ),
      order_by: [asc: m.last_checked_at]
    )
    |> Repo.all()
  end

  @doc """
  Updates a monitor's check state after successfully checking for new imagery.

  Records the current time as last_checked_at and optionally updates the last_image_id.
  """
  def update_monitor_check(monitor, last_image_id \\ nil) do
    changes = %{
      last_checked_at: DateTime.utc_now(),
      status: "active"
    }

    changes =
      if last_image_id do
        Map.put(changes, :last_image_id, last_image_id)
      else
        changes
      end

    monitor
    |> Monitor.changeset(changes)
    |> Repo.update()
  end

  @doc """
  Marks a monitor as failed.

  Called when webhook delivery repeatedly fails or other critical errors occur.
  """
  def mark_monitor_failed(monitor, reason \\ nil) do
    if reason do
      Logger.warning("Marking monitor #{monitor.id} as failed: #{reason}")
    end

    monitor
    |> Monitor.changeset(%{status: "failed"})
    |> Repo.update()
  end

  @doc """
  Pauses a monitor (stops checking for new imagery).
  """
  def pause_monitor(monitor_id) do
    case get_monitor(monitor_id) do
      nil ->
        {:error, :not_found}

      monitor ->
        monitor
        |> Monitor.changeset(%{status: "paused"})
        |> Repo.update()
    end
  end

  @doc """
  Resumes a paused or failed monitor.
  """
  def resume_monitor(monitor_id) do
    case get_monitor(monitor_id) do
      nil ->
        {:error, :not_found}

      monitor ->
        monitor
        |> Monitor.changeset(%{status: "active"})
        |> Repo.update()
    end
  end

  @doc """
  Deletes a monitor.
  """
  def delete_monitor(monitor_id) do
    case get_monitor(monitor_id) do
      nil ->
        {:error, :not_found}

      monitor ->
        Repo.delete(monitor)
    end
  end

  @doc """
  Updates a monitor's check interval.
  """
  def update_check_interval(monitor_id, new_interval) when is_integer(new_interval) and new_interval > 0 do
    case get_monitor(monitor_id) do
      nil ->
        {:error, :not_found}

      monitor ->
        monitor
        |> Monitor.changeset(%{check_interval: new_interval})
        |> Repo.update()
    end
  end

  @doc """
  Counts total monitors, optionally filtered by status.
  """
  def count_monitors(status \\ nil) do
    query =
      if status do
        from(m in Monitor, where: m.status == ^status)
      else
        Monitor
      end

    Repo.aggregate(query, :count)
  end
end
