# Effect Runtime authority cutover

Gate 2 now has one init-time authority switch:

```text
effectRuntime=legacy    # safe rollback/default
effectRuntime=event-v1  # candidate Event Ring -> EffectPlayer authority
```

`effect_runtime_authority.lua` rejects a legacy adapter call when candidate
authority is selected and rejects a candidate call when legacy is selected. It
records both call classes and `dualPlaybackRejected`, so migration cannot
silently play both event sources. The publisher's per-slice switches inherit
the authority mode unless explicitly set at init.

The first old-path cleanup is complete in the repository: duplicate budget
begin ownership is removed, high-risk direct sound/death/engine calls are
facade-backed, and candidate slice consumption is isolated behind the frozen
authority gate. Specialised renderer implementations remain as approved
fallbacks until live S0–S7/soak evidence proves their adapter call count is zero.

Rollback is atomic: set `effectRuntime=legacy` (and per-slice presentation
switches to `legacy`) before the next context init. Do not restore individual
latest-event or callback paths while candidate authority is active.
