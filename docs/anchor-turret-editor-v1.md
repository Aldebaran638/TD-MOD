# VOX / Anchor / Mount / Turret 3D Editor v1

This is the first 3D data-model slice, kept out of Runtime. It reads the
read-only AssetManifest produced by the Step 8.1 importer and uses the same
coordinate contract as `TransformAnchor v1` and `EntityGraph v1`:

- right-handed, Y-up, meters;
- logical↔VOX mappings are explicit;
- every saved transform is parent-local, while the editor can display local or
  derived world space;
- canonical forward/up/right axes, scale and mirror signs are visible in the
  gizmo model.

`Content Mod 2/script/world/adapter/anchor_turret_editor_v1.lua` is a candidate
adapter, not a new authority. It provides source operations for adding/moving/
mirroring/snapping anchors, adding mounts and turret bases/axes, selecting
fixed/logical/visual/joint mode, ordering multi-muzzles and sampling yaw/pitch
arc previews. Each operation appends a parent-local source patch. It refuses
duplicate/missing/cyclic graph references and reports Body/Shape/Joint budget
costs against the Runtime limits.

`tools/cm2-editor/run-anchor-turret-editor-v1.ps1` checks the gamma VOX manifest
hash, root/child/mirror/scale golden transforms, editor/runtime anchor equality,
turret axes/limits/speed/idle/arc, deterministic muzzle order and mode budget
parity. It also runs missing-parent, duplicate, cycle and over-budget negative
cases. `test-anchor-turret-editor-v1.ps1` mutates each boundary and expects a
non-zero result.

The adapter never writes `Content Mod 2/script` or `docs/generated`; the report
records the generated catalog hash before/after and `generatedArtifactMutation`
is always false. To roll back, disable the candidate 3D editor and return to the
Step 8.4 source editor; keep the previous source/catalog and the importer
manifest.

## Disposable live preview

`Content Mod 2/_ai_scenario_anchor_turret_editor.xml` and
`Content Mod 2/script/testing/scenario/anchor_turret_editor_controller.lua`
provide the isolated Step 8.5 live host. Open the XML in Level Editor and press
F5. The host loads the real read-only gamma VOX, derives marker placement from
the live Shape bounds, renders +X/right, +Y/up and -Z/forward axes, and exposes
the adapter through minimum real input:

- `A`, `Space`, `M`: create, move and mirror a parent-local Anchor;
- `K`, `Home`: create a Mount and a Turret base/yaw/pitch definition;
- `End`, arrow up/down: switch local/world view and mount budget mode;
- `Delete`, `Enter`: exercise the duplicate-ID build gate and validate source.

The scene owns no filesystem or generated-catalog write capability. On
2026-08-13 the complete input sequence passed in Teardown, including the real
VOX orientation, visible markers, seven-sample turret arc, source patch growth,
Runtime budget parity, duplicate rejection, F4 cleanup and empty held-input
state. The exact run, screenshots, hashes and attributed log slice are recorded
in `docs/evidence/step-8.5-anchor-turret-editor-v1.json`. Subjective creator
ergonomics and visual polish remain a human review item.
