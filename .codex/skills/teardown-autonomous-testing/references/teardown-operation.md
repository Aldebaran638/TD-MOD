# Teardown operation and state recognition

Official references:

- <https://www.teardowngame.com/modding/>: Play → Mods; create/select/edit a local Content Mod; F5 starts editor level, F4 returns; Play loads `main.xml` and `main.lua`.
- <https://teardowngame.com/experimental/api.html>: `StartLevel`, `Restart` (“Restart level”), `Menu` (“Go to main menu”), logical inputs and client/server calls.
- <https://teardowngame.com/modding-mp/> and <https://teardowngame.com/faq.html>: version 2 multiplayer and host/client rules.

## Start and navigate

If no process exists, start the installed Teardown through Steam or the known executable. Then:

- Content Mod normal play: main menu → Play → Mods → Local Files → select Mod → Play → choose player count when version 2 UI offers it.
- Editor: main menu → Play → Mods → Local Files → select Content Mod → Edit. The editor opens its `main.xml`; File → Open selects another root XML.
- Editor run: F5; wait for loading and confirm running state. Return: F4.
- Normal running level: Esc opens pause. Use UI buttons or `Menu()` behavior to return, but re-observe after every page transition.

Never combine clicks for multiple UI pages under one stale screenshot. Observe after each modal/page transition.

## State classifier

Use at least two signals before acting when ambiguity matters.

| State | Strong signals | Safe next action |
|---|---|---|
| Desktop/no game | no Teardown targets; desktop screenshot | start game |
| Main Menu | `teardown.exe`, title Teardown, main-menu screenshot, no telemetry | select Play |
| Mods / Mod Manager | local/subscribed lists and Mod info panel | select exact Mod identity |
| Mod Editor | scene explorer/property panes/menu bar; no live scenario | File→Open or F5 |
| Level Editor running | gameplay image plus editor-return semantics; matching scenario telemetry | execute contract |
| Running single-player | gameplay screenshot, one main target, live session/player/ships | baseline/action/delta |
| Pause Menu | darkened gameplay and pause buttons | Restart/Main menu/resume only after screenshot |
| Player-count dialog | 单人/双人/四人 or equivalent radio modal | choose contract count |
| MP Host | `teardown_modtest.exe`, title `TD - Host`, Host HUD | target exact Host ID |
| MP Client | `teardown_modtest.exe`, title `TD - ClientN` | target exact Client ID; verify focus support |
| Loading | black/loading art, changing log/process, no stable telemetry | wait in short intervals; do not input |
| Error dialog | modal/error text plus log error | capture evidence, release, diagnose |
| Crash/hang | target disappears/not responding, log tail, stale screenshot | preserve evidence, restart exact session |

Window title alone cannot distinguish main menu/editor/single-player because the main executable title is normally `Teardown`. Screenshot identifies UI state; telemetry identifies CM2 runtime and scenario; log identifies health.

## Real input discipline

1. `teardown_instances` and select exact `target_id` when more than one window exists.
2. `teardown_status` confirms visible, not minimized and expected target.
3. `teardown_observe` focuses and returns fresh `frame_id`.
4. Send only the minimum action batch (20 actions / 5 seconds maximum).
5. Re-observe after any modal, menu, loading, focus or level transition.
6. On failure call emergency release before retry.

Available keys include letters/numbers, F1–F12, Enter/Escape/Tab/Space, modifiers, arrows, Home/End/Insert/Delete/PageUp/PageDown. Mouse supports relative movement, client-coordinate movement and LMB/RMB/MMB down/up/click.

## Recovery ladder

For stale frame, lost focus, wrong page or navigation failure:

```text
emergency release
→ instances/status
→ observe exact target
→ identify page/session/scenario
→ return to known menu/editor state if necessary
→ apply correct reload mode
→ establish fresh baseline
→ retry once
```

For black/loading capture: wait 1–3 seconds, check process/log, retry observe; after the contract timeout, collect current window/log/action history and escalate reload. For telemetry timeout: release, close/reopen bridge with a fresh observe and nonce; if still failing, confirm correct CM2 level/session rather than treating screenshots as state.

For crash: preserve last screenshot, telemetry, log slice and actions before restarting. For multiple processes or wrong window: never use the default target; address exact PID/HWND. For clipboard conflict: do not overwrite the new user content; report conflict and retry only after explicit fresh baseline.
