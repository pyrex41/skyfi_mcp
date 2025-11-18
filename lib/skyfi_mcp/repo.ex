defmodule SkyfiMcp.Repo do
  use Ecto.Repo,
    otp_app: :skyfi_mcp,
    adapter: Ecto.Adapters.SQLite3
end
