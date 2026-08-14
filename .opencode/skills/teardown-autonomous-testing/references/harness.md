# Harness capability map

This reference describes the repository implementation, not an aspirational API.

## Targets and state

- `teardown_instances()` enumerates visible `teardown.exe` and `teardown_modtest.exe` windows. Each item includes stable `target_id=teardown:<pid>:<hwnd>`, PID, HWND, executable name, title, role hint, focus/minimize state, creation time and client rectangle.
- `teardown_status(target_id?)` reports one selected process/window, every instance, log cursor, held inputs and available input backends.
- `teardown_observe(restore=True, target_id?)` focuses one target, captures its complete client area, rejects black/near-constant or non-foreground capture, saves PNG and returns `frame_id`. A frame is bound to its target.
- `teardown_control(frame_id, actions, target_id?)` accepts at most 20 actions and five seconds of declared duration. It rejects stale frames, target mismatch and focus loss. Supported actions are wait, key down/up/tap, relative mouse move, client-coordinate `mouse_move_to`, mouse down/up/click. Virtual `gvinput` HID is preferred; SendInput is fallback.
- `teardown_emergency_release()` releases all keys/buttons tracked by this MCP, including the HID report. Call after interruption, failure, focus change, crash or session end.

`mouse_move_to` uses a closed-loop physical-HID convergence fallback because direct `SetCursorPos` is blocked in this environment. It returns actual screen coordinates and method.

## Structured telemetry

`teardown_telemetry_probe()` and `teardown_telemetry_read(after_seq)` use `CM2_TEST_V1` through a public game UI bridge:

1. save the user's clipboard text;
2. write a nonce-bearing request;
3. focus the selected Teardown target and press F8;
4. paste into `UiTextInput`;
5. select/copy until a validated response appears;
6. the game auto-closes the focused bridge shortly after a response is copied;
7. restore original text only if the clipboard still contains the request/response.

The game Lua never calls internal clipboard functions. A concurrent user copy is preserved and reported by `clipboard_restore_conflict=true`. Telemetry is dormant unless F8 is opened and a valid nonce request is pasted. A first exchange can occasionally time out; release input, re-observe, confirm the correct CM2 scenario/focus, then retry once.

Request:

```text
CM2_TEST_V1|request|nonce=<random>|command=read|after_seq=<server>|client_after_seq=<client>
```

Response begins `CM2_TEST_V1|response=` and must match protocol, type, command, nonce and a non-empty session. It returns `latest_seq`, `oldest_seq`, `next_after_seq`, `client_latest_seq`, `truncated`, snapshot and events.

Limits are a 512-slot server ring, 512-slot client ring, 64 returned events, 64 returned ships and approximately 48 KiB encoded response. `truncated=true` means continue from `next_after_seq`; a cursor older than the retained ring is also truncated. Client and server sequences are separate and deduplicated as `(source, seq, type)`. A changed session invalidates old cursors and evidence joins.

Snapshot fields:

- `scenario`: id, XML revision, Lua revision, ready;
- `player`: id, health, vehicle ID, body ID, transform position/quaternion, velocity;
- `camera`: position and quaternion;
- `input`: W/LMB down state, edge flags and client event sequence;
- each registered ship: body ID, ship type, interceptor class, owner body, position, quaternion, linear/angular velocity, shield/armor/body HP and maxima, destroyed and registered.

The ship list is the CM2 registry, not every physics body in the level.

Observed event vocabulary includes:

- lifecycle: `ship_registered`, `ship_destroyed`, `ship_unregistered`, `ship_cleanup`;
- input/command: `input_edge`, `weapon_input_evaluated`, `weapon_hold_sent`, `weapon_hold_received`, `weapon_hold_rejected`, `weapon_hold_applied`;
- weapon/presentation: `fire_request`, `weapon_released`, `presentation_event`;
- damage: `hit`, `damage_applied`, `hp_changed`;
- probe diagnostics: `damage_probe_requested`, `damage_probe_rejected`, `damage_probe_result`, `damage_dispatch_attempted`.

Do not require every event for every weapon. For example, lock-free weapons can report `target_body_id=0` at fire request and resolve body ID at `hit`.

`teardown_damage_probe(target_body_id, amount)` is bounded in code to a nonce, host player, positive amount no greater than 10,000,000, registered living ship and its owning ship-script damage authority. Its current live UI-to-ship dispatch timed out in the 2026-08-13 experiment, so its operational status is `UNAVAILABLE`. Do not use it in a passing contract until repaired and re-proven with rejection cases and layered HP deltas.

## Log and screenshot

- `teardown_log_read(cursor?)` reads `%LOCALAPPDATA%\Teardown\log.txt` by byte cursor and returns only complete newly appended lines, CM2/legacy markers, errors and warnings. Historical warning storms are not current failures.
- `DebugPrint` was probed with a nonce and did not appear in `log.txt` in Teardown 2.0.4. Log remains runtime-health evidence, not gameplay state.
- Screenshots include client size, mean luminance and variance and are saved outside the repository.

## Evidence layout

Each MCP process creates `%LOCALAPPDATA%\TeardownAI\runs\<run-id>\`, normally containing:

```text
run_metadata.json
status_initial.json
instances.json
frame_*.png
observation_*.json
observations.jsonl
actions.jsonl
log_reads.jsonl
telemetry.jsonl
telemetry_probe.json / .jsonl
telemetry_reads.jsonl
damage_probes.jsonl
emergency_release.jsonl
result.json
```

Starting a separate Python process creates a separate run ID. For a single acceptance record, use one long-lived MCP process or copy explicit cross-run references into the final result.

## Static Harness

Run repository checks through `$check`, which invokes `./harness/check-all.ps1`. It covers entry/source contracts, Lua, Teardown API, XML, weapon/component/ship definitions and checker self-tests. It does not replace live engine evidence and does not automatically cover unrelated disposable Mod roots. Check those explicitly with `check-lua`, `check-teardown-api` and `check-xml` where applicable.
