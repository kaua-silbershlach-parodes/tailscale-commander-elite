defmodule TailscaleCommanderEliteBackend.HealthServerTest do
  use ExUnit.Case, async: true

  alias TailscaleCommanderEliteBackend.{Application, HealthServer}

  test "GET /health is allowed with the full JSON contract" do
    {status, body} = HealthServer.handle_request("GET /health HTTP/1.1\r\nHost: 127.0.0.1:45900\r\n\r\n")
    assert status == "200 OK"
    assert body =~ ~s("status":"ok")
    assert body =~ ~s("service":"tailscale_commander_elite_backend")
    assert body =~ ~s("version":")
  end

  test "HTTP/1.0 without Host is allowed" do
    {status, _body} = HealthServer.handle_request("GET /health HTTP/1.0\r\n\r\n")
    assert status == "200 OK"
  end

  test "unknown paths are denied by default" do
    {status, _body} = HealthServer.handle_request("GET /anything HTTP/1.1\r\n\r\n")
    assert status == "404 Not Found"
  end

  test "query-string target is denied" do
    {status, _body} = HealthServer.handle_request("GET /health?x=1 HTTP/1.1\r\n\r\n")
    assert status == "404 Not Found"
  end

  test "non-GET methods are denied" do
    {status, _body} = HealthServer.handle_request("POST /health HTTP/1.1\r\n\r\n")
    assert status == "404 Not Found"
  end

  test "HEAD is denied without a body" do
    {status, body} = HealthServer.handle_request("HEAD /health HTTP/1.1\r\n\r\n")
    assert status == "404 Not Found"
    assert body == ""
  end

  test "non-loopback Host is rejected" do
    {status, _body} =
      HealthServer.handle_request("GET /health HTTP/1.1\r\nHost: evil.example\r\n\r\n")

    assert status == "400 Bad Request"
  end

  test "malformed request lines get 400" do
    assert {"400 Bad Request", _} = HealthServer.handle_request("GET /health GARBAGE\r\n\r\n")
    assert {"400 Bad Request", _} = HealthServer.handle_request("GET /health\r\n\r\n")
    assert {"400 Bad Request", _} = HealthServer.handle_request("garbage\r\n\r\n")
  end

  test "size cap boundary: 8192 allowed through, 8193 rejected" do
    base = "GET /health HTTP/1.1\r\nX-Pad: "
    suffix = "\r\n\r\n"
    pad = 8_192 - byte_size(base) - byte_size(suffix)
    exact = base <> String.duplicate("x", pad) <> suffix
    assert byte_size(exact) == 8_192
    assert {"200 OK", _} = HealthServer.handle_request(exact)

    over = base <> String.duplicate("x", pad + 1) <> suffix
    assert {"413 Payload Too Large", _} = HealthServer.handle_request(over)
  end

  test "port parsing is strict" do
    assert Application.parse_port(nil) == {:ok, 45_900}
    assert Application.parse_port("45900") == {:ok, 45_900}
    assert Application.parse_port("0") == {:ok, 0}
    assert {:error, _} = Application.parse_port("abc")
    assert {:error, _} = Application.parse_port("45900x")
    assert {:error, _} = Application.parse_port("-1")
    assert {:error, _} = Application.parse_port("99999")
    assert {:error, _} = Application.parse_port("")
  end
end
