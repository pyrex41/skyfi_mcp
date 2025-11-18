defmodule SkyfiMcp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        SkyfiMcpWeb.Telemetry,
        SkyfiMcp.Repo,
        {DNSCluster, query: Application.get_env(:skyfi_mcp, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: SkyfiMcp.PubSub}
      ] ++
        # Only start MonitorWorker in non-test environments
        monitor_worker_children() ++
        [
          # Start to serve requests, typically the last entry
          SkyfiMcpWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SkyfiMcp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp monitor_worker_children do
    cond do
      Application.get_env(:skyfi_mcp, :env) == :test -> []
      Application.get_env(:skyfi_mcp, :stdio_mode, false) -> []
      true -> [SkyfiMcp.Monitoring.MonitorWorker]
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SkyfiMcpWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
