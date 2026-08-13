from __future__ import annotations

import copy
import json
from pathlib import Path
import tempfile
import unittest

from upgrade_todo_plan import upgrade
from validate_todo_plan import validate


ROOT = Path(__file__).resolve().parents[4]


class TodoPlanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.todo = json.loads((ROOT / "TEARDOWN_SHIP_PLATFORM_TODO.json").read_text(encoding="utf-8-sig"))

    def test_authoritative_plan_is_valid(self) -> None:
        self.assertEqual(validate(self.todo), [])

    def test_rejects_missing_contract(self) -> None:
        value = copy.deepcopy(self.todo)
        del value["tasks"][0]["verification"]
        self.assertTrue(any("Step 0.1.verification" in item for item in validate(value)))

    def test_rejects_reordered_business_steps(self) -> None:
        value = copy.deepcopy(self.todo)
        value["tasks"][0], value["tasks"][1] = value["tasks"][1], value["tasks"][0]
        self.assertTrue(any("IDs/order" in item for item in validate(value)))

    def test_rejects_stale_contract_after_business_edit(self) -> None:
        value = copy.deepcopy(self.todo)
        value["tasks"][0]["expected_outcome"] += " changed"
        self.assertTrue(any("behavior_under_test" in item or "plan_fingerprint" in item for item in validate(value)))

    def test_rejects_unconfirmed_unable(self) -> None:
        value = copy.deepcopy(self.todo)
        value["developer_confirmed_unable"]["task_ids"].remove("Step 0.1")
        self.assertTrue(any("Step 0.1" in item and "developer confirmation" in item for item in validate(value)))

    def test_upgrade_is_idempotent_and_preserves_history(self) -> None:
        once = upgrade(self.todo)
        twice = upgrade(once)
        self.assertEqual(once, twice)
        before = [(task["id"], task["implementation_status"], task["evidence"]) for task in self.todo["tasks"]]
        after = [(task["id"], task["implementation_status"], task["evidence"]) for task in twice["tasks"]]
        self.assertEqual(before, after)


if __name__ == "__main__":
    unittest.main()
