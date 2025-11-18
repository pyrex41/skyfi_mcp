# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :skyfi_mcp,
  ecto_repos: [SkyfiMcp.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :skyfi_mcp, SkyfiMcpWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: SkyfiMcpWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: SkyfiMcp.PubSub,
  live_view: [signing_salt: "bN8tDNnY"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :skyfi_mcp, SkyfiMcp.Mailer, adapter: Swoosh.Adapters.Local

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Register MIME types for SSE
config :mime, :types, %{
  "text/event-stream" => ["event-stream"]
}

config :tesla, disable_deprecated_builder_warning: true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
