from __future__ import annotations

import json
import unittest

from telemetry_protocol import (
    PROTOCOL,
    build_request,
    clipboard_restore_allowed,
    deduplicate_events,
    next_server_sequence,
    parse_response,
    truncate_response,
)


class TelemetryProtocolTests(unittest.TestCase):
    def test_request_nonce_and_damage_fields_round_trip(self) -> None:
        request = build_request("abc123", "damage", 17, 42, 12.5)
        self.assertIn("nonce=abc123", request)
        self.assertNotIn("after_seq=", request)
        self.assertNotIn("client_after_seq=", request)
        self.assertIn("target_body_id=42", request)
        self.assertIn("amount=12.500000", request)
        self.assertLess(len(request), 128)

        read_request = build_request("abc123", "read", 17, client_after_seq=9)
        self.assertIn("after_seq=17", read_request)
        self.assertIn("client_after_seq=9", read_request)

    def test_response_parser_rejects_wrong_prefix_and_bad_json(self) -> None:
        self.assertIsNone(parse_response("other|response={}"))
        self.assertIsNone(parse_response(f"{PROTOCOL}|response={{bad"))
        self.assertEqual(parse_response(f'{PROTOCOL}|response={{"nonce":"x"}}'), {"nonce": "x"})

    def test_event_deduplication_and_server_cursor(self) -> None:
        events = [
            {"source": "server", "seq": 4, "type": "hit"},
            {"source": "server", "seq": 4, "type": "hit"},
            {"source": "client", "seq": 99, "type": "input_edge"},
            {"source": "server", "seq": 5, "type": "damage_applied"},
        ]
        unique = deduplicate_events(events)
        self.assertEqual(len(unique), 3)
        self.assertEqual(next_server_sequence(unique, 3), 5)

    def test_truncation_preserves_continuation_signal_and_limits(self) -> None:
        payload = {
            "nonce": "n",
            "events": [{"source": "server", "seq": i, "type": "x", "blob": "x" * 50} for i in range(1, 100)],
            "snapshot": {"ships": [{"body_id": i, "ship_type": "ship"} for i in range(100)]},
        }
        encoded, result = truncate_response(payload, max_bytes=4096, max_events=4, max_ships=2)
        self.assertLessEqual(len(encoded.encode("utf-8")), 4096)
        self.assertTrue(result["truncated"])
        self.assertLessEqual(len(result["events"]), 4)
        self.assertLessEqual(len(result["snapshot"]["ships"]), 2)
        self.assertEqual(result["events"][0]["seq"], 1)
        self.assertEqual(json.loads(encoded.split("=", 1)[1])["truncated"], True)

    def test_clipboard_conflict_never_restores_over_user_change(self) -> None:
        self.assertTrue(clipboard_restore_allowed("old", "request", "request", "response"))
        self.assertTrue(clipboard_restore_allowed("old", "request", "response", "response"))
        self.assertFalse(clipboard_restore_allowed("old", "request", "user text", ""))
        self.assertFalse(clipboard_restore_allowed("old", "request", "response", "response", True))


if __name__ == "__main__":
    unittest.main()
