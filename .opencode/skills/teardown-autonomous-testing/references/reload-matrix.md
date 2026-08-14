# Reload / refresh matrix

Evidence labels: `OFFICIAL` is Teardown documentation/API; `LOCAL-SOURCE` is installed 2.0.4 UI source; `EXPERIMENT` is the 2026-08-13 live run. Use the minimum verified mode, then confirm a telemetry session/revision or UI identity.

Reload modes, weakest to strongest:

- `NONE`: no game state affected.
- `F4_TO_F5`: return from editor play to editor, then start again.
- `RESTART_LEVEL`: pause menu Restart / `Restart()`.
- `REOPEN_LEVEL_XML`: F4, File → Open, select XML again, F5.
- `REOPEN_MOD_MANAGER`: return to main menu, close and reopen Mods.
- `RESTART_MOD_SESSION`: exit current Mod/game mode, select and Play again.
- `RESTART_TEARDOWN`: exit all Teardown processes and start the game again.
- `RESTART_MCP`: restart the local Python MCP process.

| Changed artifact | Minimum verified/safe mode | Evidence and notes |
|---|---|---|
| Lua used by editor-run level | `F4_TO_F5` | `OFFICIAL`: F5 starts, F4 returns. `EXPERIMENT`: Lua revision v1 remained live without reload; F4→F5 loaded v2. |
| Root/current level XML in editor | `REOPEN_LEVEL_XML` | `EXPERIMENT`: pause Restart created a new telemetry session but retained old XML params; reopen XML loaded new revision. |
| Newly created root level XML | reopen File → Open dialog | `EXPERIMENT`: appeared immediately in currently open editor dialog. Nested scenario XML was not enumerated, so executable test levels stay at Mod root. |
| `main.xml` launched by Mod Manager | `RESTART_MOD_SESSION`; escalate to `REOPEN_MOD_MANAGER` | `OFFICIAL`: Play loads `main.xml` and `main.lua`. Editor-memory Restart result must not be generalized to Mod Manager. |
| new Mod folder / `info.txt` discovery | `REOPEN_MOD_MANAGER` | `EXPERIMENT`: new consumer did not appear in an already open Mod Manager; main menu→Mods made it appear. |
| changed `info.txt` / classification metadata | `REOPEN_MOD_MANAGER` | Conservative; Mod list is the metadata reader. Re-select and confirm displayed identity/tags. |
| VOX/prefab/texture/sound asset | `REOPEN_LEVEL_XML` for editor; `RESTART_MOD_SESSION` for Play | Conservative; verify visually and by log. Asset cache behavior was not separately proven. |
| UI Lua / HUD | same as owning Lua context | In editor use `F4_TO_F5`; normal Play use `RESTART_LEVEL` first and escalate to session restart if revision cannot be proven. |
| Global Mod script/options | return to menu, toggle/re-enter gameplay | Not live-proven in this task; use a registry revision and escalate to `RESTART_TEARDOWN` if stale. |
| multiplayer script/game mode | end all `teardown_modtest.exe`, relaunch player-count session | Server and every client must receive the new script. Never accept only Host refresh. |
| MCP `server.py`/protocol helper | `RESTART_MCP` | Game remains running. A new MCP process creates a new evidence run ID. |
| Harness/schema/compiler fixture | `NONE` | Rerun the owning checker/fixture; launch Teardown only if the contract makes a runtime claim. |

`Restart()` means “Restart level” in the official API. In an active multiplayer game mode, Restart keeps the active mode. It does not promise disk XML reparse in editor play mode.

Use `RESTART_TEARDOWN` only for engine/process/plugin changes, unrecoverable stale state, crash recovery, or when a weaker refresh has been positively disproven. Record why escalation was necessary.
