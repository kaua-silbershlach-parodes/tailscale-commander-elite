defmodule TailscaleCommanderEliteBackend.HealthServer do
  @moduledoc """
  A tiny supervised HTTP health endpoint on 127.0.0.1, pure :gen_tcp.

  Deliberately minimal: one request at a time, every path answers
  the same JSON health body. It exists so the shell (and the smoke
  tests) can prove the sidecar is alive and read its version.
  """
  use GenServer

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
        body = route(request)

        response =
          "HTTP/1.1 200 OK\r\n" <>
            "content-type: application/json\r\n" <>
            "content-length: #{byte_size(body)}\r\n" <>
            "connection: close\r\n\r\n" <> body

        :gen_tcp.send(socket, response)

      _other ->
        :ok
    end

    :gen_tcp.close(socket)
  end

  defp route(request) do
    cond do
      String.contains?(request, "POST /zero-trust/simulate") ->
        simulate(request)

      String.contains?(request, "GET /zero-trust/status") ->
        rules = TailscaleCommanderEliteBackend.ZeroTrust.seed_rules()
        audit = TailscaleCommanderEliteBackend.Audit.list()

        ~s({"status":"ok","policy":"default_deny","rules":#{length(rules)},"audit_events":#{length(audit)}})

      true ->
        version = Application.spec(:tailscale_commander_elite_backend, :vsn) |> to_string()
        ~s({"status":"ok","service":"tailscale_commander_elite_backend","version":"#{version}"})
    end
  end

  defp simulate(request) do
    body = request |> String.split("\r\n\r\n", parts: 2) |> List.last()

    req = %{
      "identity" => json_string(body, "identity"),
      "resource" => json_string(body, "resource"),
      "port" => json_int(body, "port"),
      "posture_ok" => json_bool(body, "posture_ok"),
      "approved" => json_bool(body, "approved")
    }

    result =
      TailscaleCommanderEliteBackend.ZeroTrust.evaluate(
        req,
        TailscaleCommanderEliteBackend.ZeroTrust.seed_rules()
      )

    TailscaleCommanderEliteBackend.Audit.record(%{
      "identity" => req["identity"],
      "resource" => req["resource"],
      "port" => req["port"],
      "decision" => result["decision"]
    })

    reasons = result["reasons"] |> Enum.map(&~s("#{&1}")) |> Enum.join(",")
    ~s({"decision":"#{result["decision"]}","reasons":[#{reasons}]})
  end

  defp json_string(body, key) do
    case Regex.run(~r/"#{key}"\s*:\s*"([^"]*)"/, body) do
      [_, value] -> value
      _ -> ""
    end
  end

  defp json_int(body, key) do
    case Regex.run(~r/"#{key}"\s*:\s*(\d+)/, body) do
      [_, value] -> String.to_integer(value)
      _ -> 0
    end
  end

  defp json_bool(body, key) do
    Regex.match?(~r/"#{key}"\s*:\s*true/, body)
  end
end
