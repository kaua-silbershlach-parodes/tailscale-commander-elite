defmodule TailscaleCommanderEliteBackend.HealthServer do
  @moduledoc """
  A tiny supervised HTTP health endpoint on 127.0.0.1, pure :gen_tcp.

  Hardened following "Planning for a Zero Trust Architecture"
  (book 1 of the project checklist), applied only to what exists
  here: the network is treated as contested even on localhost, so
  the server answers exactly one route (GET /health) and denies
  everything else by default. Oversized requests are rejected.
  No route, identity or resource is invented beyond the health
  endpoint the shell actually uses.
  """
  use GenServer

  @max_request_bytes 8_192

  def start_link(port) do
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end

  @impl true
  def init(port) do
    {:ok, listen} =
      :gen_tcp.listen(port, [
        :binary,
        packet: :raw,
        active: false,
        reuseaddr: true,
        ip: {127, 0, 0, 1}
      ])

    {:ok, %{listen: listen, port: port}, {:continue, :accept}}
  end

  @impl true
  def handle_continue(:accept, state) do
    case :gen_tcp.accept(state.listen) do
      {:ok, socket} ->
        serve(socket)
        {:noreply, state, {:continue, :accept}}

      {:error, _reason} ->
        {:noreply, state, {:continue, :accept}}
    end
  end

  defp serve(socket) do
    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, request} ->
        {status, body} = handle_request(request)

        response =
          "HTTP/1.1 #{status}\r\n" <>
            "content-type: application/json\r\n" <>
            "content-length: #{byte_size(body)}\r\n" <>
            "connection: close\r\n\r\n" <> body

        :gen_tcp.send(socket, response)

      _other ->
        :ok
    end

    :gen_tcp.close(socket)
  end

  @doc """
  Pure request handler: only GET /health is allowed; every other
  method or path is denied, and oversized requests are rejected.
  """
  def handle_request(request) when byte_size(request) > @max_request_bytes do
    {"413 Payload Too Large", ~s({"error":"request too large"})}
  end

  def handle_request(request) do
    case String.split(request, " ", parts: 3) do
      ["GET", "/health" | _] ->
        version = Application.spec(:tailscale_commander_elite_backend, :vsn) |> to_string()
        {"200 OK", ~s({"status":"ok","service":"tailscale_commander_elite_backend","version":"#{version}"})}

      _other ->
        {"404 Not Found", ~s({"error":"not found"})}
    end
  end
end
