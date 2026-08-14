# Multiplayer testing playbook

## Supported paths

Official Teardown requires `version = 2` in `info.txt`; every participating Lua script starts `#version 2` and separates `server`, `client` and read-only synchronized `shared` responsibility. The host runs both server and a client. Content game modes start on `main.xml`; multiplayer Restart keeps the active game mode.

Normal online multiplayer uses published, unmodified mods; official FAQ says local mods are ignored. Do not claim an online compatibility pass from a local-only fixture.

The installed Teardown 2.0.4 Mod Manager offers One/Two/Four Player Local for a version 2 local Content Mod. Local UI source invokes `mods.testplay` for 2/4 players and the installed game includes `teardown_modtest.exe`.

## Local startup

1. main menu → Play → Mods;
2. select exact local version 2 Mod;
3. Play;
4. select 单人/双人/四人 (or localized equivalent);
5. Start;
6. wait, then call `teardown_instances`.

Live two-player result:

- original `teardown.exe` remains the Mod Manager/editor process;
- one `teardown_modtest.exe` window titled `TD - Host`;
- one `teardown_modtest.exe` window titled `TD - Client1`;
- separate PIDs/HWNDs and client rectangles.

Four-player is expected to add clients but was not run in this task; enumerate rather than assume count/title.

## Targeting and evidence

Always use returned `target_id`. Capture status/screenshot for every instance and record PID, HWND, title, role, creation time and focus. Host is server authority plus local client; client screenshots/presentation are per-instance. A multiplayer contract should distinguish event source, player ID, owner/generation/sequence and session.

The current Harness successfully focuses, screenshots and sends real W input to `TD - Host`. It enumerates `TD - Client1`, but on the tested dual-monitor system Windows/SDL retained Host as foreground and safe focus verification rejected Client capture/input. Current capability is therefore:

- multi-process/window discovery: `PASS`;
- Host targeted observe/control: `PASS`;
- Client PID/HWND identification: `PASS`;
- unattended per-Client observe/control: `BLOCKED` by foreground selection behavior;
- cross-client telemetry correlation: `NOT RUN` until Client targeting and CM2 multiplayer scenario transport are proven.

Do not disable the foreground guard. The next minimal extension should use a supported per-window local-test input/capture route or change the official test-window arrangement, then prove exact HWND focus before input.

## Required multiplayer assertions

Depending on the behavior, assert:

- Host validates commands and owns gameplay mutation;
- clients receive monotonic generation/sequence state without duplicate/stale resurrection;
- per-client presentation exists without becoming authority;
- join/late-join/reconnect receives a consistent snapshot;
- destruction/unregister/cleanup converge on every participant;
- ownership transfer/rejection has explicit events;
- queues, leases and entity counts return to bounds;
- Host and Client incremental logs have no new in-scope errors.

For online claims, additionally run the published/unmodified dependency path with a remote client. Local `teardown_modtest` is a development fixture, not proof of Workshop distribution.

## End session

Call emergency release, focus Host and exit through the session UI when possible. Officially, when the host leaves, the server closes and all players return to menu. In the live local test, Alt+F4 on exact Host caused both Host and Client1 test processes to exit and returned focus to the original `teardown.exe`. Verify `teardown_instances` contains no `teardown_modtest.exe`; call emergency release again. Kill exact leftover PIDs only for a hung/crashed test and preserve evidence first.
