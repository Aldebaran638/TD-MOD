# GM New Framework

This folder is reserved for the next-generation GM framework.

Target direction:
- Framework core + concrete ship content
- Runtime state in Lua tables, not registry-heavy state storage
- Scene/tag scanning and ship assembly similar to AVF-style integration
- Small sync/event surface between server and client

Suggested layering:
- `shared/`: shared constants, enums, utility helpers
- `defs/`: ship, weapon, mount, and effect definitions
- `assembly/`: scene scanning, tag parsing, hardpoint discovery, ship instance build
- `runtime/`: authoritative runtime state stores
- `server/`: movement, weapons, damage, recovery, AI, orchestration
- `client/`: HUD, camera, FX, sound, client cache
- `sync/`: thin request/event/state bridge between server and client

Migration rule:
- New framework code goes here first.
- Old `script/` stays as reference/compatibility layer until systems are replaced one by one.
