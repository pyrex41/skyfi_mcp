defmodule SkyfiMcp.Monitor do
  @moduledoc """
  Schema for monitoring configurations.

  Monitors track specific areas of interest (AOI) and send webhook notifications
  when new satellite imagery matching the specified criteria becomes available.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_statuses ~w(active paused failed)
  @valid_sensor_types ~w(optical sar)

  schema "monitors" do
    field :user_api_key_hash, :string
    field :aoi, :map
    field :criteria, :map
    field :webhook_url, :string
    field :webhook_secret, :string
    field :check_interval, :integer, default: 86400  # seconds (default: daily)
    field :last_checked_at, :utc_datetime
    field :last_image_id, :string
    field :status, :string, default: "active"

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a monitor with validations.
  """
  def changeset(monitor, attrs) do
    monitor
    |> cast(attrs, [
      :user_api_key_hash,
      :aoi,
      :criteria,
      :webhook_url,
      :webhook_secret,
      :check_interval,
      :last_checked_at,
      :last_image_id,
      :status
    ])
    |> validate_required([:user_api_key_hash, :aoi, :criteria, :webhook_url])
    |> put_webhook_secret()
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:check_interval, greater_than: 0)
    |> validate_url(:webhook_url)
    |> validate_aoi()
    |> validate_criteria()
  end

  defp put_webhook_secret(changeset) do
    # Generate a webhook secret if not provided
    case get_field(changeset, :webhook_secret) do
      nil ->
        secret = generate_webhook_secret()
        put_change(changeset, :webhook_secret, secret)

      _secret ->
        changeset
    end
  end

  defp generate_webhook_secret do
    # Generate 32 bytes (256 bits) of random data, hex-encoded
    :crypto.strong_rand_bytes(32)
    |> Base.encode16(case: :lower)
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, url ->
      uri = URI.parse(url)

      if uri.scheme in ["http", "https"] and uri.host do
        []
      else
        [{field, "must be a valid HTTP(S) URL"}]
      end
    end)
  end

  defp validate_aoi(changeset) do
    validate_change(changeset, :aoi, fn _, aoi ->
      cond do
        not is_map(aoi) ->
          [aoi: "must be a map"]

        Map.get(aoi, "type") not in ["Polygon", "MultiPolygon"] ->
          [aoi: "must be a Polygon or MultiPolygon GeoJSON"]

        not is_list(Map.get(aoi, "coordinates")) ->
          [aoi: "must have coordinates array"]

        true ->
          []
      end
    end)
  end

  defp validate_criteria(changeset) do
    validate_change(changeset, :criteria, fn _, criteria ->
      errors = []

      # Validate cloud_cover_max
      errors =
        if cc = criteria["cloud_cover_max"] do
          if is_integer(cc) and cc >= 0 and cc <= 100 do
            errors
          else
            [{:criteria, "cloud_cover_max must be integer 0-100"} | errors]
          end
        else
          errors
        end

      # Validate sensor_types if present
      errors =
        if sensors = criteria["sensor_types"] do
          if is_list(sensors) and Enum.all?(sensors, &(&1 in @valid_sensor_types)) do
            errors
          else
            [{:criteria, "sensor_types must contain valid types: #{inspect(@valid_sensor_types)}"} | errors]
          end
        else
          errors
        end

      # Validate resolution_min if present
      errors =
        if res = criteria["resolution_min"] do
          if (is_integer(res) or is_float(res)) and res > 0 do
            errors
          else
            [{:criteria, "resolution_min must be a positive number"} | errors]
          end
        else
          errors
        end

      errors
    end)
  end
end
