# Effect Lab MVP

Effect Lab is a synthetic-context preview entrypoint, not a second renderer. It
uses the production `EffectPlayer` and `PresentationBudget` modules with a
stable `lab:synthetic` owner and explicit origin, direction, hit point, normal
and target anchor. It never reads the ship registry or engine body handles.

The MVP API supports `init`, generated-definition selection, `play`, `pause`,
`stop`, `replay`, `tick`, `getReport` and `reset`. Seed, near/far LOD and budget
profile are captured in every bounded trace entry. The report includes the
EffectPlayer active/free invariant, budget accepted/degraded/rejected counts,
instance count and replay trace.

The four Gate 1 slices use the same generated candidate catalog paths recorded
in `harness/data/presentation/effect-lab-fixtures.json`. The preview can be
driven by a small host script or future Editor; hot reload is intentionally not
required. A preview failure rolls back by disabling the preview entrypoint and
does not affect Runtime.
