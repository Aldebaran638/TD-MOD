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
manifest. Live VOX rendering, gizmo interaction and Teardown marker screenshots
remain deferred because Teardown.exe is unavailable on this machine.
