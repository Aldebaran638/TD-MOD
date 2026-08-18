# Global Mod Broker Spike v1 — not adopted

The Broker hypothesis would let a Content package declare a dependency on a
Global Mod Core. That is not a proven Teardown capability, so this step keeps
the protocol disabled and models the decision boundary instead of adding a
loader or changing Content/Global ownership.

`docs/global-mod-broker-spike-v1.json` records seven scenarios:

- Content-before-Global and Global-before-Content load order;
- missing Core and Core version mismatch;
- package unload and generated/runtime cleanup;
- multiplayer host/remote authority and replication;
- multiple packages with capability conflicts.

The deterministic policy is fail-fast: missing/mismatched Core uses
builtin-only fallback, unload/multiplayer remain blocked until live evidence,
and capability conflicts reject the package. Unknown packages never mutate the
runtime catalog. Adoption requires the listed S0/S8, host-remote, two-package,
missing/version-mismatch and no-leftover evidence; the current conclusion is
“do not adopt”.

## Reproduction

```powershell
& .\tools\cm2-broker\check-global-mod-broker-spike-v1.ps1
& .\tools\cm2-broker\run-global-mod-broker-spike-v1.ps1
& .\tools\cm2-broker\test-global-mod-broker-spike-v1.ps1
```

The runner is a headless state machine. It reports all decisions and package
capability conflicts but never registers a broker, writes Runtime Lua, edits a
catalog or assumes a load-order hook. The current machine result is recorded
in `docs/candidates/global-mod-broker-spike-v1.result.json`.

Teardown is available on the current machine, but this verification run did not
start live load-order, unload or multiplayer playback because the exact
responding target was not the foreground window. The target-specific focus guard
therefore blocked input, telemetry, screenshot and log capture. The result is
recorded as environment-blocked rather than as live Broker evidence. Rollback is
simply to remove the experiment result and keep the Broker disabled; Content
remains the source and Global remains the generated target.
