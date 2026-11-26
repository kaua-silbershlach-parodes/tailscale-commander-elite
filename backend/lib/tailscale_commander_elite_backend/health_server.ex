defmodule TailscaleCommanderEliteBackend.HealthServer do
  @moduledoc """
  A tiny supervised HTTP health endpoint on 127.0.0.1, pure :gen_tcp.

  Hardened following book 1 of the project checklist, applied only
  to what exists here: the network is treated as contested even on
  localhost, so the server answers exactly one route (GET /health)
  and denies everything else by default. Requests are read with a
  bounded loop, malformed requests get 400, oversized requests get
  413, and each connection is served by its own bounded worker so
  one slow client cannot block later health checks. No route,
  identity or resource is invented beyond the health endpoint the
  shell actually uses.
  """
  use GenServer

  require Logger

  @max_request_bytes 8_192
  @read_deadline_ms 5_000
  @max_workers 32

  def start_link(port) do
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end

  @impl true
  def init(port) do
    case :gen_tcp.listen(port, [
           :binary,
           packet: :raw,
           active: false,
           reuseaddr: true,
           backlog: 64,
           send_timeout: 5_000,
           send_timeout_close: true,
           ip: {127, 0, 0, 1}
         ]) do
      {:ok, listen} ->
        {:ok, actual_port} = :inet.port(listen)
        Logger.info("health server listening on 127.0.0.1:#{actual_port}")
        {:ok, %{listen: listen, port: actual_port, workers: 0}, {:continue, :accept}}

      {:error, reason} ->
        Logger.error("health server listen failed on port #{port}: #{inspect(reason)}")
        {:stop, {:listen_failed, port, reason}}
    end
  end

  @impl true
  def handle_continue(:accept, state) do
    case :gen_tcp.accept(state.listen) do
      {:ok, socket} ->
        state = maybe_serve(socket, state)
        {:noreply, state, {:continue, :accept}}

      {:error, :closed} ->
        Logger.error("health server listen socket closed")
        {:stop, :listen_closed, state}

      {:error, reason} when reason in [:emfile, :enfile, :econnaborted] ->
        Logger.warning("health server accept transient error: #{inspect(reason)}")
        Process.sleep(100)
        {:noreply, state, {:continue, :accept}}

      {:error, reason} ->
        Logger.error("health server accept failed: #{inspect(reason)}")
        {:stop, {:accept_failed, reason}, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, %{state | workers: max(state.workers - 1, 0)}}
  end

  def handle_info(_other, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    :gen_tcp.close(state.listen)
    :ok
  end

  defp maybe_serve(socket, state) when state.workers >= @max_workers do
    :gen_tcp.close(socket)
    state
  end

  defp maybe_serve(socket, state) do
    server = self()
    port = state.port

    pid =
      spawn(fn ->
        serve(socket, port)
        send(server, {:worker_done, self()})
      end)

    Process.monitor(pid)
    :gen_tcp.controlling_process(socket, pid)
    %{state | workers: state.workers + 1}
  end

  defp serve(socket, port) do
    deadline = System.monotonic_time(:millisecond) + @read_deadline_ms

    case read_request(socket, "", deadline) do
      {:ok, request} ->
        {status, body} = handle_request(request, port)

        response =
          "HTTP/1.1 #{status}\r\n" <>
            "content-type: application/json\r\n" <>
            "content-length: #{byte_size(body)}\r\n" <>
            "cache-control: no-store\r\n" <>
            "connection: close\r\n\r\n" <> body

        case :gen_tcp.send(socket, response) do
          :ok -> :ok
          {:error, reason} -> Logger.warning("health server send failed: #{inspect(reason)}")
        end

      {:error, :too_large} ->
        Logger.warning("health server rejected oversized request")
        body = ~s({"error":"request too large"})

        :gen_tcp.send(
          socket,
          "HTTP/1.1 413 Payload Too Large\r\ncontent-type: application/json\r\n" <>
            "content-length: #{byte_size(body)}\r\ncache-control: no-store\r\nconnection: close\r\n\r\n" <>
            body
        )

      {:error, _reason} ->
        :ok
    end

    :gen_tcp.close(socket)
  end

  defp read_request(socket, acc, deadline) do
    cond do
      byte_size(acc) > @max_request_bytes ->
        {:error, :too_large}

      String.contains?(acc, "\r\n\r\n") ->
        {:ok, acc}

      true ->
        remaining = deadline - System.monotonic_time(:millisecond)

        if remaining <= 0 do
          {:error, :timeout}
        else
          case :gen_tcp.recv(socket, 0, remaining) do
            {:ok, data} -> read_request(socket, acc <> data, deadline)
            {:error, reason} -> {:error, reason}
          end
        end
    end
  end

  @doc """
  Pure request handler: only `GET /health` with a loopback Host is
  allowed. Malformed request lines get 400, valid but denied
  requests get 404, oversized requests get 413, and HEAD never
  returns a body.
  """
  def handle_request(request, port \\ 45_900)

  def handle_request(request, _port) when byte_size(request) > @max_request_bytes do
    {"413 Payload Too Large", ~s({"error":"request too large"})}
  end

  def handle_request(request, port) do
    case parse_request(request) do
      {:ok, %{method: "GET", target: "/health", host: host}} ->
        if loopback_host?(host, port) do
          {"200 OK", health_body()}
        else
          {"400 Bad Request", ~s({"error":"bad request"})}
        end

      {:ok, %{method: "HEAD"}} ->
        {"404 Not Found", ""}

      {:ok, _denied} ->
        {"404 Not Found", ~s({"error":"not found"})}

      :error ->
        {"400 Bad Request", ~s({"error":"bad request"})}
    end
  end

  defp parse_request(request) do
    with [request_line | header_lines] <- String.split(request, "\r\n"),
         [method, target, version] <- String.split(request_line, " "),
         true <- version in ["HTTP/1.0", "HTTP/1.1"],
         true <- method != "" and target != "" do
      host =
        Enum.find_value(header_lines, fn line ->
          case String.split(line, ":", parts: 2) do
            [name, value] ->
              if String.downcase(String.trim(name)) == "host",
                do: String.trim(value)

            _other ->
              nil
          end
        end)

      {:ok, %{method: method, target: target, host: host}}
    else
      _other -> :error
    end
  end

  defp loopback_host?(nil, _port), do: true

  defp loopback_host?(host, port) do
    String.downcase(host) in [
      "127.0.0.1",
      "127.0.0.1:#{port}",
      "localhost",
      "localhost:#{port}"
    ]
  end

  defp health_body do
    version =
      case Application.spec(:tailscale_commander_elite_backend, :vsn) do
        nil -> "unknown"
        vsn -> to_string(vsn)
      end

    ~s({"status":"ok","service":"tailscale_commander_elite_backend","version":"#{version}"})
  end
end
