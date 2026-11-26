defmodule TailscaleCommanderEliteBackend.Application do
  @moduledoc false
  use Application

  require Logger

  @default_port 45_900

  @impl true
  def start(_type, _args) do
    case parse_port(System.get_env("TAILSCALE_COMMANDER_ELITE_BACKEND_PORT")) do
      {:ok, port} ->
        children = [
          {TailscaleCommanderEliteBackend.HealthServer, port}
        ]

        opts = [
          strategy: :one_for_one,
          name: TailscaleCommanderEliteBackend.Supervisor,
          max_restarts: 3,
          max_seconds: 5
        ]

        Supervisor.start_link(children, opts)

      {:error, value} ->
        Logger.error("invalid TAILSCALE_COMMANDER_ELITE_BACKEND_PORT: #{inspect(value)}")
        {:error, {:invalid_port, value}}
    end
  end

  @doc """
  Strict port parsing: absent means the default port, "0" means an
  ephemeral port (tests), anything else must be a whole number in
  1..65535.
  """
  def parse_port(nil), do: {:ok, @default_port}

  def parse_port(value) do
    case Integer.parse(String.trim(value)) do
      {port, ""} when port >= 0 and port <= 65_535 -> {:ok, port}
      _other -> {:error, value}
    end
  end
end
