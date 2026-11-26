defmodule TailscaleCommanderEliteBackend.HealthServerTest do
  use ExUnit.Case, async: true

  alias TailscaleCommanderEliteBackend.HealthServer

  test "GET /health is allowed" do
    {status, body} = HealthServer.handle_request("GET /health HTTP/1.1\r\n\r\n")
    assert status == "200 OK"
    assert body =~ ~s("status":"ok")
  end

  test "unknown paths are denied by default" do
    {status, _body} = HealthServer.handle_request("GET /anything HTTP/1.1\r\n\r\n")
    assert status == "404 Not Found"
  end

  test "non-GET methods are denied" do
    {status, _body} = HealthServer.handle_request("POST /health HTTP/1.1\r\n\r\n")
    assert status == "404 Not Found"
  end

  test "oversized requests are rejected" do
    big = "GET /health HTTP/1.1\r\n" <> String.duplicate("x", 9_000)
    {status, _body} = HealthServer.handle_request(big)
    assert status == "413 Payload Too Large"
  end
end
