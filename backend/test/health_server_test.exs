defmodule TailscaleCommanderEliteBackend.HealthServerTest do
  use ExUnit.Case, async: false
  alias TailscaleCommanderEliteBackend.{Application, HealthServer}

  defp request(method, path, host \\ "127.0.0.1:45900"), do: "#{method} #{path} HTTP/1.1\r\nHost: #{host}\r\n\r\n"
  test "health contract and default deny" do
    assert {"200 OK", body} = HealthServer.handle_request(request("GET", "/health"))
    assert body =~ ~s("status":"ok")
    assert body =~ ~s("service":"tailscale_commander_elite_backend")
    assert body =~ ~s("version":")
    for {method, path} <- [{"GET", "/anything"}, {"GET", "/health?x=1"}, {"POST", "/health"}] do
      assert {"404 Not Found", _} = HealthServer.handle_request(request(method, path))
    end
    assert {"404 Not Found", ""} = HealthServer.handle_request(request("HEAD", "/health"))
    assert {"200 OK", _} = HealthServer.handle_request("GET /health HTTP/1.0\r\n\r\n")
  end

  test "reject absent, duplicate, malformed and foreign Host and unsupported body" do
    for raw <- ["GET /health HTTP/1.1\r\n\r\n", request("GET", "/health", "evil.example"),
                "GET /health HTTP/1.1\r\nHost: localhost\r\nHost: localhost\r\n\r\n",
                "GET /health HTTP/1.1\r\nHost : localhost\r\n\r\n",
                "GET /health HTTP/1.1\r\nHost: localhost\r\nContent-Length: 1\r\n\r\n",
                "GET /health HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\n\r\n",
                "GET /health HTTP/1.1\r\nHost: localhost\r\n\r\nextra",
                "GET /health GARBAGE\r\n\r\n", "GET /health\r\n\r\n", <<255>>] do
      assert {"400 Bad Request", _} = HealthServer.handle_request(raw)
    end
  end

  test "size boundary" do
    base = "GET /health HTTP/1.1\r\nHost: localhost\r\nX-Pad: "
    suffix = "\r\n\r\n"
    pad = 8_192 - byte_size(base) - byte_size(suffix)
    assert {"200 OK", _} = HealthServer.handle_request(base <> String.duplicate("x", pad) <> suffix)
    assert {"413 Payload Too Large", _} = HealthServer.handle_request(base <> String.duplicate("x", pad + 1) <> suffix)
  end

  test "strict port parsing" do
    assert Application.parse_port(nil) == {:ok, 45_900}
    assert Application.parse_port("45900") == {:ok, 45_900}
    assert Application.parse_port("0") == {:ok, 0}
    for bad <- ["abc", "45900x", "-1", "99999", ""] do
      assert {:error, _} = Application.parse_port(bad)
    end
  end

  defp connect(port), do: :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false], 1_000)
  defp port, do: :sys.get_state(HealthServer).port
  defp exchange(port) do
    {:ok, socket} = connect(port)
    try do
      :ok = :gen_tcp.send(socket, request("GET", "/health", "localhost:#{port}"))
      response = receive_response(socket, 2_000)
      assert response =~ "HTTP/1.1 200 OK"
      assert response =~ ~s("status":"ok")
    after
      :gen_tcp.close(socket)
    end
  end

  # TCP does not preserve message boundaries; collect until connection close.
  defp receive_response(socket, timeout, acc \\ "") do
    case :gen_tcp.recv(socket, 0, timeout) do
      {:ok, chunk} -> receive_response(socket, timeout, acc <> chunk)
      {:error, :closed} -> acc
      {:error, reason} -> flunk("TCP response failed: #{inspect(reason)}")
    end
  end

  test "more than 32 consecutive TCP health checks do not exhaust workers" do
    p = port()
    for _ <- 1..80, do: exchange(p)
  end

  test "a slow TCP client does not block independent health checks" do
    p = port()
    {:ok, slow} = connect(p)
    try do
      :ok = :gen_tcp.send(slow, "GET /health HTTP/1.1\r\n")
      exchange(p)
      response = receive_response(slow, 7_000)
      assert response =~ "408 Request Timeout"
      exchange(p)
    after
      :gen_tcp.close(slow)
    end
  end

  defp await_workers(count, deadline) do
    state = :sys.get_state(HealthServer)
    cond do
      map_size(state.workers) == count -> :ok
      System.monotonic_time(:millisecond) >= deadline -> flunk("worker count: #{map_size(state.workers)}, expected #{count}")
      true -> Process.sleep(10); await_workers(count, deadline)
    end
  end

  test "bounded concurrent mixed TCP requests keep responses isolated and release workers" do
    p = port()
    await_workers(0, System.monotonic_time(:millisecond) + 2_000)
    cases = [
      {request("GET", "/health", "localhost:#{p}"), "200 OK"},
      {request("GET", "/unknown", "localhost:#{p}"), "404 Not Found"},
      {request("GET", "/health", "foreign.example"), "400 Bad Request"},
      {request("POST", "/health", "localhost:#{p}"), "404 Not Found"}
    ]

    results =
      List.duplicate(cases, 4)
      |> List.flatten()
      |> Task.async_stream(fn {raw, status} ->
        {:ok, socket} = connect(p)
        try do
          :ok = :gen_tcp.send(socket, raw)
          response = receive_response(socket, 2_000)
          assert String.starts_with?(response, "HTTP/1.1 #{status}\\r\\n")
          if status == "200 OK" do
            assert response =~ ~s("status":"ok")
          else
            refute response =~ ~s("status":"ok")
          end
          :verified
        after
          :gen_tcp.close(socket)
        end
      end, max_concurrency: 8, ordered: false, timeout: 5_000, on_timeout: :kill_task)
      |> Enum.to_list()

    assert length(results) == 16
    assert Enum.all?(results, &(&1 == {:ok, :verified}))
    await_workers(0, System.monotonic_time(:millisecond) + 2_000)
    exchange(p)
  end

  test "worker cap rejects excess connection and recovers after close" do
    p = port()
    {:ok, {{127, 0, 0, 1}, ^p}} = :inet.sockname(:sys.get_state(HealthServer).listen)
    await_workers(0, System.monotonic_time(:millisecond) + 2_000)
    sockets = for _ <- 1..32 do
      {:ok, socket} = connect(p)
      :ok = :gen_tcp.send(socket, "GET /health HTTP/1.1\r\n")
      socket
    end
    try do
      await_workers(32, System.monotonic_time(:millisecond) + 2_000)
      {:ok, excess} = connect(p)
      try do
        assert {:error, reason} = :gen_tcp.recv(excess, 0, 2_000)
        assert reason in [:closed, :econnreset]
      after
        :gen_tcp.close(excess)
      end
    after
      Enum.each(sockets, &:gen_tcp.close/1)
    end
    await_workers(0, System.monotonic_time(:millisecond) + 2_000)
    exchange(p)
  end

  test "oversized and malformed real TCP requests fail closed" do
    p = port()
    for {raw, status} <- [
      {"GET /health HTTP/1.1\r\n\r\n", "400 Bad Request"},
      {"GET /health HTTP/1.1\r\nHost: localhost\r\nX-Pad: " <> String.duplicate("a", 8_200) <> "\r\n\r\n", "413 Payload Too Large"},
      {"POST /health HTTP/1.1\r\nHost: localhost\r\n\r\n", "404 Not Found"}
    ] do
      {:ok, socket} = connect(p)
      try do
        :ok = :gen_tcp.send(socket, raw)
        assert receive_response(socket, 2_000) =~ "HTTP/1.1 #{status}"
      after
        :gen_tcp.close(socket)
      end
    end
    exchange(p)
  end
end
