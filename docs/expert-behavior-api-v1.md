# Expert Custom Behavior API v1 — deferred design

This is a security-reviewed design/Spike boundary, not a Runtime feature.
`docs/expert-behavior-api-v1.json` is intentionally `enabled=false` and
`status=deferred`; it is not a prerequisite for the Data-only Creator SDK.

The proposed surface is default-deny. Arbitrary Lua/dynamic code, filesystem,
network/raw RPC, native code, reflection, process spawning and direct engine
handles are denied. A future allow-list would require an opaque reviewed
capability, owner/generation lifecycle, server-authority rules, typed events,
bounded tick/instruction/memory/event budgets and explicit major-version
migration. Timeout, crash, memory, permission and leak failures terminate or
disable only the behavior instance and fall back to builtin behavior.

The threat model covers code execution, file/network exfiltration, engine-handle
escape, CPU/memory denial of service, stale lifecycle handles, multiplayer
authority confusion, version confusion and crash propagation. The review gates
are recorded in the policy and each deprecation/removal requires an owner,
replacement, date and evidence.

## Design-only gate

`tools/cm2-expert/evaluate-expert-behavior-v1.ps1` evaluates request fixtures
without executing any code. It returns stable decisions (`deferred`, `deny`,
`isolate`) and always records `execution=not-run`. This is a safe place to
exercise capability, timeout and crash policies before an implementation exists.

Run the checker and Spike:

```powershell
& .\tools\cm2-expert\check-expert-behavior-policy-v1.ps1
& .\tools\cm2-expert\test-expert-behavior-policy-v1.ps1
```

The self-test covers ordinary deferred requests, arbitrary-Lua/filesystem/
network/engine-handle denials, timeout/crash isolation, and rejection of a
policy that is accidentally enabled before review. The current result is in
`docs/candidates/expert-behavior-api-v1.result.json`.

Rollback is deliberately simple: keep the policy disabled, remove any
experimental registration, and use builtin/data-only packages. No Runtime Lua,
engine handle, filesystem or network capability is added by this step.
