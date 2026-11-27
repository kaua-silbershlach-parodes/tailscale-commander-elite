defmodule TailscaleCommanderEliteBackend.HealthServer do
  @moduledoc "Loopback-only, bounded HTTP health service. No authenticated identity is asserted."
  use GenServer
  require Logger

  @max_request_bytes 8_192
  @read_deadline_ms 5_000
  @max_workers 32
  @accept_timeout_ms 50
  @token ~r/\A[!#$%&'*+.^_`|~0-9A-Za-z-]+\z/

  def start_link(port), do: GenServer.start_link(__MODULE__, port, name: __MODULE__)

  @impl true
  def init(port) do
    case :gen_tcp.listen(port, [:binary, packet: :raw, active: false, reuseaddr: true,
                               backlog: 64, send_timeout: 5_000, send_timeout_close: true,
                               ip: {127, 0, 0, 1}]) do
      {:ok, listen} ->
        {:ok, actual_port} = :inet.port(listen)
        Logger.info("health server listening on 127.0.0.1:#{actual_port}")
        send(self(), :accept)
        {:ok, %{listen: listen, port: actual_port, workers: %{}}}
      {:error, reason} ->
        Logger.error("health server listen failed: #{inspect(reason)}")
        {:stop, {:listen_failed, port, reason}}
    end
  end

  @impl true
  def handle_info(:accept, state) do
    # A bounded accept and mailbox rescheduling let DOWN messages be handled.
    case :gen_tcp.accept(state.listen, @accept_timeout_ms) do
      {:ok, socket} ->
        next = maybe_serve(socket, state)
        send(self(), :accept)
        {:noreply, next}
      {:error, :timeout} ->
        send(self(), :accept)
        {:noreply, state}
      {:error, reason} when reason in [:emfile, :enfile, :econnaborted] ->
        Logger.warning("health server transient accept failure: #{inspect(reason)}")
        Process.send_after(self(), :accept, 100)
        {:noreply, state}
      {:error, reason} ->
        {:stop, {:accept_failed, reason}, state}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state),
    do: {:noreply, %{state | workers: Map.delete(state.workers, ref)}}
  def handle_info(_, state), do: {:noreply, state}

  @impl true
  def terminate(_, state) do
    :gen_tcp.close(state.listen)
    Enum.each(state.workers, fn {_ref, pid} -> Process.exit(pid, :shutdown) end)
    :ok
  end

  defp maybe_serve(socket, state) when map_size(state.workers) >= @max_workers do
    :gen_tcp.close(socket)
    state
  end

  defp maybe_serve(socket, state) do
    parent = self()
    port = state.port
    {pid, ref} = spawn_monitor(fn ->
      # The socket must be handed over before the worker can read it.
      owner_ref = Process.monitor(parent)
      receive do
        {:socket, ^parent, owned_socket} ->
          try do
            serve(owned_socket, port)
          after
            :gen_tcp.close(owned_socket)
            Process.demonitor(owner_ref, [:flush])
          end
        {:DOWN, ^owner_ref, :process, ^parent, _} -> :ok
      after
        1_000 -> :ok
      end
    end)
    case :gen_tcp.controlling_process(socket, pid) do
      :ok ->
        send(pid, {:socket, parent, socket})
        %{state | workers: Map.put(state.workers, ref, pid)}
      {:error, reason} ->
        Process.exit(pid, :shutdown)
        Process.demonitor(ref, [:flush])
        :gen_tcp.close(socket)
        Logger.warning("health socket handoff failed: #{inspect(reason)}")
        state
    end
  end

  defp serve(socket, port) do
    deadline = System.monotonic_time(:millisecond) + @read_deadline_ms
    case read_request(socket, "", deadline) do
      {:ok, request} -> respond(socket, handle_request(request, port))
      {:error, :too_large} -> respond(socket, {"413 Payload Too Large", ~s({"error":"request too large"})})
      {:error, :timeout} -> respond(socket, {"408 Request Timeout", ~s({"error":"timeout"})})
      {:error, _} -> :ok
    end
  end

  defp respond(socket, {status, body}) do
    response = ["HTTP/1.1 ", status, "\r\ncontent-type: application/json\r\ncontent-length: ",
                Integer.to_string(byte_size(body)), "\r\ncache-control: no-store\r\nconnection: close\r\n\r\n", body]
    case :gen_tcp.send(socket, response) do
      :ok -> :ok
      {:error, reason} -> Logger.warning("health response failed: #{inspect(reason)}")
    end
  end

  defp read_request(socket, acc, deadline) do
    cond do
      byte_size(acc) > @max_request_bytes -> {:error, :too_large}
      :binary.match(acc, "\r\n\r\n") != :nomatch -> {:ok, acc}
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

  def handle_request(request, port \\ 45_900)
  def handle_request(request, _) when byte_size(request) > @max_request_bytes,
    do: {"413 Payload Too Large", ~s({"error":"request too large"})}
  def handle_request(request, port) do
    case parse_request(request, port) do
      {:ok, "GET", "/health"} -> {"200 OK", health_body()}
      {:ok, "HEAD", _} -> {"404 Not Found", ""}
      {:ok, _, _} -> {"404 Not Found", ~s({"error":"not found"})}
      :error -> {"400 Bad Request", ~s({"error":"bad request"})}
    end
  end

  defp parse_request(request, port) do
    with true <- String.valid?(request),
         [head, ""] <- String.split(request, "\r\n\r\n", parts: 2),
         [line | header_lines] <- String.split(head, "\r\n"),
         [method, target, version] <- String.split(line, " "),
         true <- Regex.match?(@token, method),
         true <- target != "" and Enum.all?(:binary.bin_to_list(target), &(&1 >= 33 and &1 <= 126)),
         true <- version in ["HTTP/1.0", "HTTP/1.1"],
         {:ok, headers} <- parse_headers(header_lines),
         true <- valid_host?(headers, version, port),
         true <- not Map.has_key?(headers, "transfer-encoding"),
         true <- Map.get(headers, "content-length", "0") == "0" do
      {:ok, method, target}
    else
      _ -> :error
    end
  end

  defp parse_headers(lines) do
    Enum.reduce_while(lines, {:ok, %{}}, fn line, {:ok, headers} ->
      case String.split(line, ":", parts: 2) do
        [name, value] ->
          key = String.downcase(name)
          valid_value = Enum.all?(:binary.bin_to_list(value), &(&1 == 9 or (&1 >= 32 and &1 <= 126)))
          if Regex.match?(@token, name) and valid_value and not Map.has_key?(headers, key) do
            {:cont, {:ok, Map.put(headers, key, String.trim(value))}}
          else
            {:halt, :error}
          end
        _ -> {:halt, :error}
      end
    end)
  end

  defp valid_host?(headers, version, port) do
    case Map.get(headers, "host") do
      nil -> version == "HTTP/1.0"
      host -> String.downcase(host) in ["127.0.0.1", "127.0.0.1:#{port}", "localhost", "localhost:#{port}"]
    end
  end

  defp health_body do
    version = case Application.spec(:tailscale_commander_elite_backend, :vsn) do
      nil -> "unknown"
      vsn -> to_string(vsn)
    end
    ~s({"status":"ok","service":"tailscale_commander_elite_backend","version":"#{version}"})
  end
end
