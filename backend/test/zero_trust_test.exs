defmodule TailscaleCommanderEliteBackend.ZeroTrustTest do
  use ExUnit.Case, async: true

  alias TailscaleCommanderEliteBackend.ZeroTrust

  defp req(overrides) do
    Map.merge(
      %{
        "identity" => "operator",
        "resource" => "server",
        "port" => 443,
        "posture_ok" => true,
        "approved" => false
      },
      overrides
    )
  end

  test "default deny when no rule permits the access" do
    result = ZeroTrust.evaluate(req(%{"identity" => "stranger"}), ZeroTrust.seed_rules())
    assert result["decision"] == "deny"
  end

  test "allow when rule matches and posture is ok" do
    result = ZeroTrust.evaluate(req(%{}), ZeroTrust.seed_rules())
    assert result["decision"] == "allow"
  end

  test "quarantine when posture fails" do
    result = ZeroTrust.evaluate(req(%{"posture_ok" => false}), ZeroTrust.seed_rules())
    assert result["decision"] == "quarantine"
  end

  test "step_up for HIGH resource without approval, allow with approval" do
    high = req(%{"identity" => "admin", "port" => 22})
    assert ZeroTrust.evaluate(high, ZeroTrust.seed_rules())["decision"] == "step_up"

    approved = req(%{"identity" => "admin", "port" => 22, "approved" => true})
    assert ZeroTrust.evaluate(approved, ZeroTrust.seed_rules())["decision"] == "allow"
  end
end
