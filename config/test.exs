import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :skyfi_mcp, SkyfiMcp.Repo,
  adapter: Ecto.Adapters.SQLite3,
  database: "skyfi_mcp_test.db",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :skyfi_mcp, SkyfiMcpWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "Z0K2tEVTfDxHQVC8XlELvnDP4LP9YHYbccJMXaX3qOo/cTIxgkCsWCMWa9t5nhap",
  server: false

# In test we don't send emails
config :skyfi_mcp, SkyfiMcp.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :skyfi_mcp, env: :test

# Use Tesla Mock adapter for tests
config :tesla, adapter: Tesla.Mock
