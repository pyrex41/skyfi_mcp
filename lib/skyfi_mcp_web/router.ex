defmodule SkyfiMcpWeb.Router do
  use SkyfiMcpWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", SkyfiMcpWeb do
    pipe_through :api
  end

  # Health check endpoint (no authentication required)
  scope "/", SkyfiMcpWeb do
    pipe_through :api

    get "/health", HealthController, :check
  end

  # MCP endpoints (authentication required via plug)
  scope "/mcp", SkyfiMcpWeb do
    pipe_through :api

    get "/sse", McpController, :sse
    post "/message", McpController, :message
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:skyfi_mcp, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: SkyfiMcpWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
