defmodule TailscaleCommanderEliteBackend do
  @moduledoc """
  Minimal Elixir backend for Tailscale Commander Elite.

  Pure OTP, zero dependencies: a supervised TCP health server on
  127.0.0.1 that answers only `GET /health` with a small JSON body
  (status, service, version) and denies everything else by
  default. The backend is a separate OTP application with its own
  lifecycle and version; the shell does not spawn it.
  """
end
