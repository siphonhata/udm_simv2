defmodule UdmSim.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      UdmSimWeb.Telemetry,
      UdmSim.Repo,
      {DNSCluster, query: Application.get_env(:udm_sim, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: UdmSim.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: UdmSim.Finch},
      %{id: :sess_server, start: {SessionManager, :start_link, [[target: :sess]]}},
      # Start a worker by calling: UdmSim.Worker.start_link(arg)
      # {UdmSim.Worker, arg},
      # Start to serve requests, typically the last entry
      UdmSimWeb.Endpoint,

    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: UdmSim.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    UdmSimWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
