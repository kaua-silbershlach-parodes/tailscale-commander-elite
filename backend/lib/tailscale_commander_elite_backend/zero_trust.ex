defmodule TailscaleCommanderEliteBackend.ZeroTrust do
  @moduledoc """
  Zero-trust policy core for Tailscale Commander Elite.

  Applied from "Planning for a Zero Trust Architecture" (NIST CSWP 20),
  book 1 of the project checklist:

  - Default deny: access is allowed only when a rule explicitly
    permits it and every condition is satisfied.
  - Per-request decisions: identity, device posture, resource and
    port are evaluated together, and the decision carries its reasons.
  - Risk categorization: HIGH resources require step-up approval.
  - Continuous evidence: every simulation is written to an audit log.

  A rule is a map: %{"identity" => ..., "resource" => ...,
  "port" => integer, "impact" => "LOW" | "MODERATE" | "HIGH"}.
  A request is a map: %{"identity" => ..., "resource" => ...,
  "port" => integer, "posture_ok" => boolean,
  "approved" => boolean}.
  """

  @doc "Evaluate one access request against the rule set. Default deny."
  def evaluate(request, rules) do
    identity = Map.get(request, "identity", "")
    resource = Map.get(request, "resource", "")
    port = Map.get(request, "port", 0)
    posture_ok = Map.get(request, "posture_ok", false)
    approved = Map.get(request, "approved", false)

    rule =
      Enum.find(rules, fn r ->
        Map.get(r, "identity") == identity and
          Map.get(r, "resource") == resource and
          Map.get(r, "port") == port
      end)

    cond do
      rule == nil ->
        %{"decision" => "deny", "reasons" => ["no rule permits this access (default deny)"]}

      not posture_ok ->
        %{
          "decision" => "quarantine",
          "reasons" => ["device posture check failed; restrict to remediation only"]
        }

      Map.get(rule, "impact") == "HIGH" and not approved ->
        %{
          "decision" => "step_up",
          "reasons" => ["HIGH-impact resource requires approver step-up"]
        }

      true ->
        %{
          "decision" => "allow",
          "reasons" => ["rule permits identity, resource and port; posture ok"]
        }
    end
  end

  @doc "Seed rules shipped with the base; replaced by tailnet policy later."
  def seed_rules do
    [
      %{"identity" => "admin", "resource" => "server", "port" => 22, "impact" => "HIGH"},
      %{"identity" => "operator", "resource" => "server", "port" => 443, "impact" => "MODERATE"}
    ]
  end
end

defmodule TailscaleCommanderEliteBackend.Audit do
  @moduledoc "Append-only audit log of zero-trust decisions (in-memory)."
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def record(event) do
    Agent.update(__MODULE__, fn events -> [event | events] end)
  end

  def list do
    Agent.get(__MODULE__, fn events -> Enum.reverse(events) end)
  end
end
