defmodule TailscaleCommanderEliteBackend.MixProject do
  use Mix.Project

  def project do
    [
      app: :tailscale_commander_elite_backend,
      version: "1.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {TailscaleCommanderEliteBackend.Application, []}
    ]
  end
end
