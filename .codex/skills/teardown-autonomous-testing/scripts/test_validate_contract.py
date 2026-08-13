from __future__ import annotations

import unittest

from validate_contract import validate


def valid_contract() -> dict:
    return {
        "schema": "cm2.verification-contract/2",
        "plan_fingerprint": "a" * 64,
        "task": "Example",
        "behavior_under_test": "One real input changes authoritative state",
        "profiles": ["SCENE", "REAL_INPUT", "TELEMETRY", "VISUAL", "LOG"],
        "eyes": ["EYE_TELEMETRY", "EYE_SCREENSHOT", "EYE_LOG"],
        "hands": ["HAND_REAL_INPUT", "HAND_TEST_SETUP"],
        "setup": {
            "description": "Pre-place attacker and target in one Mod scene",
            "fixture": "weapons/direct_fire",
            "determinism": "fixed transform and HP",
            "forbidden_shortcuts": ["damage_probe cannot prove weapon behavior"],
        },
        "reload": {"mode": "F4_TO_F5", "reason": "Lua changed", "session_reset_expected": True},
        "trigger": ["press LMB"],
        "telemetry_assertions": ["input_edge", "hp_changed"],
        "state_assertions": ["HP decreases"],
        "visual_assertions": ["effect visible"],
        "log_assertions": ["no error"],
        "cleanup_assertions": ["release input"],
        "regression": ["registration"],
        "evidence": ["result.json"],
        "automation_level": "FULL_AUTO",
        "automation_gaps": [],
    }


class ContractTests(unittest.TestCase):
    def test_accepts_complete_contract(self) -> None:
        self.assertEqual(validate(valid_contract()), [])

    def test_rejects_unknown_profile(self) -> None:
        value = valid_contract()
        value["profiles"] = ["CHEAT"]
        self.assertTrue(any("unknown profiles" in item for item in validate(value)))

    def test_rejects_eye_profile_mismatch(self) -> None:
        value = valid_contract()
        value["eyes"].remove("EYE_TELEMETRY")
        self.assertTrue(any("EYE_TELEMETRY" in item for item in validate(value)))

    def test_rejects_real_input_without_hand(self) -> None:
        value = valid_contract()
        value["hands"].remove("HAND_REAL_INPUT")
        self.assertTrue(any("HAND_REAL_INPUT" in item for item in validate(value)))

    def test_rejects_visual_without_assertion(self) -> None:
        value = valid_contract()
        value["visual_assertions"] = []
        self.assertTrue(any("VISUAL" in item for item in validate(value)))

    def test_rejects_partial_without_gap(self) -> None:
        value = valid_contract()
        value["automation_level"] = "PARTIAL_AUTO"
        self.assertTrue(any("automation_gaps" in item for item in validate(value)))

    def test_rejects_missing_cleanup(self) -> None:
        value = valid_contract()
        value["cleanup_assertions"] = []
        self.assertTrue(any("cleanup" in item for item in validate(value)))


if __name__ == "__main__":
    unittest.main()
