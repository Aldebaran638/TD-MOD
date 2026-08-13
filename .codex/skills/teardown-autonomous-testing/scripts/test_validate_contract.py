from __future__ import annotations

import unittest

from validate_contract import validate


def valid_contract() -> dict:
    return {
        "schema": "cm2.verification-contract/1",
        "task": "Example",
        "behavior_under_test": "One real input changes authoritative state",
        "test_profiles": ["SCENE", "REAL_INPUT", "TELEMETRY", "VISUAL", "LOG"],
        "setup": {"level": "fixture"},
        "trigger": ["press LMB"],
        "expected_telemetry": ["input_edge", "hp_changed"],
        "expected_state": ["HP decreases"],
        "expected_visual": ["effect visible"],
        "expected_log": ["no error"],
        "cleanup": ["release input"],
        "reload_requirement": "F4_TO_F5",
        "regression": ["registration"],
        "evidence": ["result.json"],
    }


class ContractTests(unittest.TestCase):
    def test_accepts_complete_contract(self) -> None:
        self.assertEqual(validate(valid_contract()), [])

    def test_rejects_unknown_profile(self) -> None:
        value = valid_contract()
        value["test_profiles"] = ["CHEAT"]
        self.assertTrue(any("unknown test profiles" in item for item in validate(value)))

    def test_rejects_visual_without_assertion(self) -> None:
        value = valid_contract()
        value["expected_visual"] = []
        self.assertTrue(any("VISUAL" in item for item in validate(value)))

    def test_rejects_missing_cleanup(self) -> None:
        value = valid_contract()
        value["cleanup"] = []
        self.assertTrue(any("cleanup" in item for item in validate(value)))


if __name__ == "__main__":
    unittest.main()
