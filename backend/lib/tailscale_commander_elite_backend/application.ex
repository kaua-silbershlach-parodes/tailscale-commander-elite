defmodule TailscaleCommanderEliteBackend.Application do
  use Application

  @impl true
  def start(_type, _args) do
    port =
      case System.get_env("TAILSCALE_COMMANDER_ELITE_BACKEND_PORT") do
        nil -> 45_900
        value -> String.to_integer(value)
      end

    children = [
      {TailscaleCommanderEliteBackend.HealthServer, port}
    ]

    opts = [strategy: :one_for_one, name: TailscaleCommanderEliteBackend.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
