# Backend - Elixir sidecar

A small native shell (Rust + the system WebView) with a local
**Elixir/BEAM backend** as a separate OTP application.

This folder carries a **minimal, working skeleton** - pure OTP,
zero dependencies:

| Path | Contents |
|---|---|
| `mix.exs` | The Mix project (`:tailscale_commander_elite_backend`, no deps) |
| `lib/tailscale_commander_elite_backend/application.ex` | The OTP application: strict port parsing, one supervised child |
| `lib/tailscale_commander_elite_backend/health_server.ex` | A supervised `:gen_tcp` HTTP health server on **127.0.0.1:45900** (port override: `TAILSCALE_COMMANDER_ELITE_BACKEND_PORT`) that answers only `GET /health` with `{"status":"ok","service":"tailscale_commander_elite_backend","version":"..."}`; malformed requests get 400, other valid requests 404, oversized requests 413 |

Run it:

```text
cd backend
mix run --no-halt
# Then, in another terminal:
curl http://127.0.0.1:45900/health
```

Test it:

```text
cd backend
# Set TAILSCALE_COMMANDER_ELITE_BACKEND_PORT=0 in the test environment.
mix test
```

## The contract

- The backend is an independent Elixir application (OTP) with its
  own lifecycle and version. The current shell does not spawn,
  restart, or bundle it; packaging and lifecycle management are
  handled outside this folder.
- The backend listens on **127.0.0.1 only** and implements HTTP
  health checks only. There is no WebSocket server, no Erlang
  distribution listener, and no hot-loading logic in this code.
- Versioning is independent: the shell shows its own version in
  the Updates panel; the backend reports its version on its
  health endpoint.

## Security and operational limits

The listener accepts at most 32 concurrent workers with an 8,192-byte request limit and a five-second read deadline. HTTP/1.1 requires a loopback Host value; HTTP/1.0 permits an absent Host. Duplicate headers, transfer encoding and nonzero content length are rejected. A timed-out request can return 408. The response is marked no-store and the connection closes.

This is an unauthenticated local liveness endpoint, not a trusted service-identity or authorization mechanism. Any local process can attempt to contact or impersonate it. Do not expose the port publicly or treat its response as proof of identity. See the root SECURITY_AUDIT.md for the release gate and residual risk.
