# Schema-driven Definition Editor MVP v1

This step is deliberately a source editor, not a 3D editor. The form model is
generated from `schemas/cm2/source-envelope-v1.json`; the same descriptors carry
field path, type, unit, range, default, reference kind and budget impact for
weapon, projectile, effect, vehicle and mount forms. A reference picker accepts
only namespaced IDs present in the package catalog/resource map.

`tools/cm2-editor/run-schema-editor-v1.ps1` exercises the contract against
`docs/candidates/schema-editor-v1.fixture.json`:

1. Open/copy a source envelope and edit runtime fields without touching a
   generated Lua file.
2. Validate required fields, enum/range/type/reference constraints and emit
   diagnostics containing `definitionId`, `fieldPath`, `expected`, `actual` and
   `suggestion`.
3. Keep source snapshots for diff, undo and redo. An explicit v0-to-v1 migration
   updates the schema/revision while round-tripping unknown Editor metadata.
4. Block save before invoking the Compiler when an invalid field is present.
5. Build two temporary source workspaces through the existing
   `tools/cm2-compiler/compile-definitions.ps1`; their generated catalogs must be
   byte-identical. The compiler's runtime projection is also the Preview DTO.

The editor writes only temporary source/compile workspaces and the machine report.
It refuses path traversal and records `generatedLuaManualEdit=forbidden`; the
runtime generated catalog hash is compared before and after. Runtime source and
catalog ownership therefore remain unchanged. If the editor fails, discard its
staging workspace and continue editing the previous source package; no generated
artifact is overwritten.

The first valid weapon path is measured as a five-minute fixture target. This is
headless evidence for the schema/compiler contract, not a claim about live UI
usability. Teardown.exe is unavailable, so a live Preview shot and performance
measurement remain a later runtime gate.
