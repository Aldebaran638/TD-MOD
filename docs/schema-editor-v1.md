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

The disposable non-3D presentation host is
`Content Mod 2/_ai_scenario_definition_editor.xml`. Open it from Level Editor
and press F5. It displays the same five schema forms and field metadata validated
by the headless report. Controls are:

- Left/Right: select form;
- Up/Down: select field;
- Space: apply the deterministic valid edit;
- Delete: inject the field's deterministic invalid value;
- Enter: validate before save;
- Backspace/Insert: undo/redo the source snapshot.

The live host is intentionally presentation-only: it cannot write source, invoke
the Compiler, modify generated artifacts, spawn entities, apply damage or mutate
Runtime state. Headless fixtures remain authoritative for bytes, hashes and save
gates; screenshots prove only that the real Teardown input/UI path exposes those
results. The first valid weapon path remains the five-minute fixture target.
