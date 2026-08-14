# Establishing experiments — 2026-08-13, Teardown 2.0.4

These experiments are reproducible observations, not universal engine guarantees.

## State and transport

- `teardown.exe` PID 30296 and its visible `Teardown` window were identified; status reported focus, client rectangle and virtual HID.
- screenshot capture rejected occluded/non-foreground content and saved validated PNGs.
- direct Mod clipboard functions emitted engine warnings, so CM2 was moved to public F8 `UiTextInput`; nonce read/probe succeeded and restored the original clipboard.
- a unique `DebugPrint` log probe did not enter `log.txt`; structured state therefore uses the UI bridge, while log remains error/warning authority.

## Reload

- scenario Lua revision v1 stayed live without reload; F4→F5 loaded v2.
- editing XML parameters then pause→Restart created a new telemetry session but retained old values.
- F4→File/Open same root XML→F5 loaded `scenario.id=weapon_direct_fire`, XML revision `direct-fire-xml-v2` and Lua revision `scenario-controller-v2`.
- root test XML appeared in the active Open dialog; nested XML did not.
- a new Mod did not appear in an already open Mod Manager; main menu→Mods refreshed it.

## Full real weapon path

Evidence: `%LOCALAPPDATA%\TeardownAI\runs\20260813T084813Z-fe00410c\` and the post-fix rerun `%LOCALAPPDATA%\TeardownAI\runs\20260813T100753Z-e50b6e23\`.

The deterministic direct-fire scenario registered Titan body 6 and target body 13. Real HID LMB press/release produced client input/ready/send events; server receive/fire/apply/release events; authoritative hit/damage/HP events. Target shield fell from 11,700 to 1,213.332275 while armor/body stayed at 11,700/10,000. Three recorded applied-damage portions were 7,583.647255, 2,502.603594 and 400.416575, all shield layer. No new errors/warnings appeared in that run slice.

The rerun fixed a discovered cross-session client-event bug and proved every returned server/client event used response session `0-d08ba117`. Real LMB produced 23 correlated events; target shield fell from 11,700 to 4,732.219238 while armor/body stayed unchanged, the post-release screenshot captured a transient colored impact/beam trace and weapon cooldown, and the incremental run log had zero errors/warnings. This proves one production LMB → Perdition Beam → registered target → layered HP path. It does not prove destruction cleanup because the target survived; that remains a separate contract.

## Damage probe

Validation and authority constraints exist in code, but the F8 damage request never completed the client-to-owning-ship dispatch in live testing. No `damage_dispatch_attempted` event or HP change appeared before timeout; clipboard recovery succeeded. Status: `UNAVAILABLE`, not pass.

## Consumer and multiplayer

- `_AI Test Consumer Basic` became discoverable after reopening Mod Manager and started in single-player.
- Its UI showed `WAITING FOR PUBLIC CM2 CONTRACT`, exposing the current absence of a stable independent Content-Mod dependency/broker signal.
- two-player local created `teardown_modtest.exe` windows `TD - Host` and `TD - Client1`, each with distinct PID/HWND; Host screenshot/input passed.
- Client1 was enumerated but foreground focus was rejected by Windows/SDL; safety rules prevented input.
- Alt+F4 on exact Host terminated both test processes; original `teardown.exe` remained and emergency release was clean.

Relevant multiplayer evidence runs include `20260813T093614Z-7ad39333`, `20260813T093643Z-caad370e`, `20260813T094136Z-dd2efad9` and `20260813T094208Z-b639659c`.
