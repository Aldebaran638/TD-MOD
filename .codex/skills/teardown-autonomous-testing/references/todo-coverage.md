# CM2 80-Step test coverage audit

Generated from `TEARDOWN_SHIP_PLATFORM_TODO.json`. This file adds test policy; it does not mutate historical task status. Regenerate with `generate_todo_coverage.py` after the plan changes.

Inventory: 80 Steps; CURRENTLY COVERED=17; NEEDS REGRESSION=5; READY TO REASSESS=58

Every entry below supplies Profiles, Setup, Trigger, Assertions, Reload Mode, Regression and Evidence. Convert it into a concrete `cm2.verification-contract/1` before implementation.

## Step 0.1 — 修复当前 Content 主入口

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Load the formal CM2 entry and a disposable smoke level with telemetry enabled; preserve a pre-run log cursor.
- Trigger: Start through the real Mod Manager/editor path, exercise config/UI and one minimal gameplay action.
- Assertions: Every entry/include/resource loads, correct scenario/session appears, UI opens/closes through real input and no new runtime error occurs.
- Reload Mode: `RESTART_MOD_SESSION; REOPEN_LEVEL_XML for editor XML changes`
- Regression: Entry closure, source-of-truth, schema/compiler/catalog and relevant definition suites.
- Evidence: Contract JSON, fixture inputs, command trace, structured report, deterministic hashes and full Harness result.

## Step 0.2 — 把所有真实入口纳入验证闭包

- Historical status: `finish`
- Audit: **CURRENTLY COVERED — rerun the listed regression when adjacent contracts change.**
- Test Profiles: `STATIC`
- Setup: Use versioned golden source plus valid/invalid deterministic fixtures in an isolated output directory.
- Trigger: Run the owning checker/fixture twice; compare byte output and structured diagnostics.
- Assertions: Valid input is deterministic; invalid/missing/future/duplicate input fails closed with stable field diagnostics; source and generated authority do not diverge.
- Reload Mode: `NONE`
- Regression: Entry closure, source-of-truth, schema/compiler/catalog and relevant definition suites.
- Evidence: Contract JSON, fixture inputs, command trace, structured report, deterministic hashes and full Harness result.

## Step 0.3 — 建立最小 Teardown 实机 smoke matrix

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Load the formal CM2 entry and a disposable smoke level with telemetry enabled; preserve a pre-run log cursor.
- Trigger: Start through the real Mod Manager/editor path, exercise config/UI and one minimal gameplay action.
- Assertions: Every entry/include/resource loads, correct scenario/session appears, UI opens/closes through real input and no new runtime error occurs.
- Reload Mode: `RESTART_MOD_SESSION; REOPEN_LEVEL_XML for editor XML changes`
- Regression: Entry closure, source-of-truth, schema/compiler/catalog and relevant definition suites.
- Evidence: Contract JSON, fixture inputs, command trace, structured report, deterministic hashes and full Harness result.

## Step 0.4 — 加入低开销诊断计数器

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + SCENE + TELEMETRY + LOG`
- Setup: Use versioned golden source plus valid/invalid deterministic fixtures in an isolated output directory.
- Trigger: Run the owning checker/fixture twice; compare byte output and structured diagnostics.
- Assertions: Valid input is deterministic; invalid/missing/future/duplicate input fails closed with stable field diagnostics; source and generated authority do not diverge. Diagnostics are dormant by default, bounded when enabled and add no material disabled-path overhead.
- Reload Mode: `NONE`
- Regression: Entry closure, source-of-truth, schema/compiler/catalog and relevant definition suites.
- Evidence: Contract JSON, fixture inputs, command trace, structured report, deterministic hashes and full Harness result.

## Step 0.5 — 冻结架构决策与迁移账本

- Historical status: `finish`
- Audit: **CURRENTLY COVERED — rerun the listed regression when adjacent contracts change.**
- Test Profiles: `STATIC`
- Setup: Use versioned golden source plus valid/invalid deterministic fixtures in an isolated output directory.
- Trigger: Run the owning checker/fixture twice; compare byte output and structured diagnostics.
- Assertions: Valid input is deterministic; invalid/missing/future/duplicate input fails closed with stable field diagnostics; source and generated authority do not diverge.
- Reload Mode: `NONE`
- Regression: Entry closure, source-of-truth, schema/compiler/catalog and relevant definition suites.
- Evidence: Contract JSON, fixture inputs, command trace, structured report, deterministic hashes and full Harness result.

## Step 1.1 — 冻结 ID、版本和坐标基础合同

- Historical status: `finish`
- Audit: **CURRENTLY COVERED — rerun the listed regression when adjacent contracts change.**
- Test Profiles: `STATIC + FIXTURE`
- Setup: Use versioned golden source plus valid/invalid deterministic fixtures in an isolated output directory.
- Trigger: Run the owning checker/fixture twice; compare byte output and structured diagnostics.
- Assertions: Valid input is deterministic; invalid/missing/future/duplicate input fails closed with stable field diagnostics; source and generated authority do not diverge.
- Reload Mode: `NONE`
- Regression: Entry closure, source-of-truth, schema/compiler/catalog and relevant definition suites.
- Evidence: Contract JSON, fixture inputs, command trace, structured report, deterministic hashes and full Harness result.

## Step 1.2 — 定义 Source Envelope 与六类核心 Schema v1

- Historical status: `finish`
- Audit: **CURRENTLY COVERED — rerun the listed regression when adjacent contracts change.**
- Test Profiles: `STATIC + FIXTURE`
- Setup: Use versioned golden source plus valid/invalid deterministic fixtures in an isolated output directory.
- Trigger: Run the owning checker/fixture twice; compare byte output and structured diagnostics.
- Assertions: Valid input is deterministic; invalid/missing/future/duplicate input fails closed with stable field diagnostics; source and generated authority do not diverge.
- Reload Mode: `NONE`
- Regression: Entry closure, source-of-truth, schema/compiler/catalog and relevant definition suites.
- Evidence: Contract JSON, fixture inputs, command trace, structured report, deterministic hashes and full Harness result.

## Step 1.3 — 实现确定性 Definition Compiler MVP

- Historical status: `finish`
- Audit: **CURRENTLY COVERED — rerun the listed regression when adjacent contracts change.**
- Test Profiles: `STATIC + FIXTURE`
- Setup: Use versioned golden source plus valid/invalid deterministic fixtures in an isolated output directory.
- Trigger: Run the owning checker/fixture twice; compare byte output and structured diagnostics.
- Assertions: Valid input is deterministic; invalid/missing/future/duplicate input fails closed with stable field diagnostics; source and generated authority do not diverge.
- Reload Mode: `NONE`
- Regression: Entry closure, source-of-truth, schema/compiler/catalog and relevant definition suites.
- Evidence: Contract JSON, fixture inputs, command trace, structured report, deterministic hashes and full Harness result.

## Step 1.4 — 建立现有定义的语义清单和 Golden Snapshot

- Historical status: `finish`
- Audit: **CURRENTLY COVERED — rerun the listed regression when adjacent contracts change.**
- Test Profiles: `STATIC + FIXTURE`
- Setup: Use versioned golden source plus valid/invalid deterministic fixtures in an isolated output directory.
- Trigger: Run the owning checker/fixture twice; compare byte output and structured diagnostics.
- Assertions: Valid input is deterministic; invalid/missing/future/duplicate input fails closed with stable field diagnostics; source and generated authority do not diverge.
- Reload Mode: `NONE`
- Regression: Entry closure, source-of-truth, schema/compiler/catalog and relevant definition suites.
- Evidence: Contract JSON, fixture inputs, command trace, structured report, deterministic hashes and full Harness result.

## Step 1.5 — 用四个纵切片验证 Compiler

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + LOG`
- Setup: Use versioned golden source plus valid/invalid deterministic fixtures in an isolated output directory.
- Trigger: Run the owning checker/fixture twice; compare byte output and structured diagnostics.
- Assertions: Valid input is deterministic; invalid/missing/future/duplicate input fails closed with stable field diagnostics; source and generated authority do not diverge.
- Reload Mode: `NONE`
- Regression: Entry closure, source-of-truth, schema/compiler/catalog and relevant definition suites.
- Evidence: Contract JSON, fixture inputs, command trace, structured report, deterministic hashes and full Harness result.

## Step 1.6 — 冻结 Identity DTO 与 `WeaponPresentationEvent v1`

- Historical status: `finish`
- Audit: **NEEDS REGRESSION — completion is retained, but current policy requires missing live evidence.**
- Test Profiles: `STATIC + FIXTURE + MULTIPLAYER`
- Setup: Use versioned golden source plus valid/invalid deterministic fixtures in an isolated output directory.
- Trigger: Run the owning checker/fixture twice; compare byte output and structured diagnostics.
- Assertions: Valid input is deterministic; invalid/missing/future/duplicate input fails closed with stable field diagnostics; source and generated authority do not diverge. A published presentation_event has one visible consumer result and cleanup returns the fixed-capacity store to baseline.
- Reload Mode: `NONE`
- Regression: Entry closure, source-of-truth, schema/compiler/catalog and relevant definition suites.
- Evidence: Contract JSON, fixture inputs, command trace, structured report, deterministic hashes and full Harness result.

## Step 1.7 — 建立候选 Catalog 的 Shadow 模式

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + LOG`
- Setup: Use versioned golden source plus valid/invalid deterministic fixtures in an isolated output directory.
- Trigger: Run the owning checker/fixture twice; compare byte output and structured diagnostics.
- Assertions: Valid input is deterministic; invalid/missing/future/duplicate input fails closed with stable field diagnostics; source and generated authority do not diverge.
- Reload Mode: `NONE`
- Regression: Entry closure, source-of-truth, schema/compiler/catalog and relevant definition suites.
- Evidence: Contract JSON, fixture inputs, command trace, structured report, deterministic hashes and full Harness result.

## Step 2.1 — 增加 Presentation Publisher 与 Legacy Adapter

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Build a representative legacy/candidate pair and a deterministic scene containing only the affected definitions/effects.
- Trigger: Run static parity first, reload the scenario, then use the minimum real fire/preview action required by the profile.
- Assertions: Compiled identity and legacy semantic golden match or have an approved diff; telemetry names the versioned definition; presentation instances stay within budget and visual output is present; no legacy double-publish. A published presentation_event has one visible consumer result and cleanup returns the fixed-capacity store to baseline.
- Reload Mode: `F4_TO_F5 for Lua; REOPEN_LEVEL_XML for XML/catalog placement`
- Regression: Four vertical slices, 109-weapon definition snapshot, presentation sequence/generation guards and legacy fallback.
- Evidence: Compiler/parity reports, telemetry event chain, budget counters, screenshots, log slice and Harness.

## Step 2.2 — 建立固定容量、可观测的 Presentation Event Ring

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Build a representative legacy/candidate pair and a deterministic scene containing only the affected definitions/effects.
- Trigger: Run static parity first, reload the scenario, then use the minimum real fire/preview action required by the profile.
- Assertions: Compiled identity and legacy semantic golden match or have an approved diff; telemetry names the versioned definition; presentation instances stay within budget and visual output is present; no legacy double-publish. A published presentation_event has one visible consumer result and cleanup returns the fixed-capacity store to baseline.
- Reload Mode: `F4_TO_F5 for Lua; REOPEN_LEVEL_XML for XML/catalog placement`
- Regression: Four vertical slices, 109-weapon definition snapshot, presentation sequence/generation guards and legacy fallback.
- Evidence: Compiler/parity reports, telemetry event chain, budget counters, screenshots, log slice and Harness.

## Step 2.3 — 实现 `EffectPlayer` 和固定容量实例存储

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Build a representative legacy/candidate pair and a deterministic scene containing only the affected definitions/effects.
- Trigger: Run static parity first, reload the scenario, then use the minimum real fire/preview action required by the profile.
- Assertions: Compiled identity and legacy semantic golden match or have an approved diff; telemetry names the versioned definition; presentation instances stay within budget and visual output is present; no legacy double-publish. A published presentation_event has one visible consumer result and cleanup returns the fixed-capacity store to baseline.
- Reload Mode: `F4_TO_F5 for Lua; REOPEN_LEVEL_XML for XML/catalog placement`
- Regression: Four vertical slices, 109-weapon definition snapshot, presentation sequence/generation guards and legacy fallback.
- Evidence: Compiler/parity reports, telemetry event chain, budget counters, screenshots, log slice and Harness.

## Step 2.4 — 收口 Particle、Light、Sprite、Line、Audio 与 Shake 预算

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Build a representative legacy/candidate pair and a deterministic scene containing only the affected definitions/effects.
- Trigger: Run static parity first, reload the scenario, then use the minimum real fire/preview action required by the profile.
- Assertions: Compiled identity and legacy semantic golden match or have an approved diff; telemetry names the versioned definition; presentation instances stay within budget and visual output is present; no legacy double-publish.
- Reload Mode: `F4_TO_F5 for Lua; REOPEN_LEVEL_XML for XML/catalog placement`
- Regression: Four vertical slices, 109-weapon definition snapshot, presentation sequence/generation guards and legacy fallback.
- Evidence: Compiler/parity reports, telemetry event chain, budget counters, screenshots, log slice and Harness.

## Step 2.5 — 迁移四条代表性纵切片

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + LOG`
- Setup: Build a representative legacy/candidate pair and a deterministic scene containing only the affected definitions/effects.
- Trigger: Run static parity first, reload the scenario, then use the minimum real fire/preview action required by the profile.
- Assertions: Compiled identity and legacy semantic golden match or have an approved diff; telemetry names the versioned definition; presentation instances stay within budget and visual output is present; no legacy double-publish.
- Reload Mode: `F4_TO_F5 for Lua; REOPEN_LEVEL_XML for XML/catalog placement`
- Regression: Four vertical slices, 109-weapon definition snapshot, presentation sequence/generation guards and legacy fallback.
- Evidence: Compiler/parity reports, telemetry event chain, budget counters, screenshots, log slice and Harness.

## Step 2.6 — 迁移剩余武器表现、音频、舰载机与舰船效果

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Build a representative legacy/candidate pair and a deterministic scene containing only the affected definitions/effects.
- Trigger: Run static parity first, reload the scenario, then use the minimum real fire/preview action required by the profile.
- Assertions: Compiled identity and legacy semantic golden match or have an approved diff; telemetry names the versioned definition; presentation instances stay within budget and visual output is present; no legacy double-publish. A published presentation_event has one visible consumer result and cleanup returns the fixed-capacity store to baseline.
- Reload Mode: `F4_TO_F5 for Lua; REOPEN_LEVEL_XML for XML/catalog placement`
- Regression: Four vertical slices, 109-weapon definition snapshot, presentation sequence/generation guards and legacy fallback.
- Evidence: Compiler/parity reports, telemetry event chain, budget counters, screenshots, log slice and Harness.

## Step 2.7 — 建立 Creator Preview 的 Effect Lab MVP

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Build a representative legacy/candidate pair and a deterministic scene containing only the affected definitions/effects.
- Trigger: Run static parity first, reload the scenario, then use the minimum real fire/preview action required by the profile.
- Assertions: Compiled identity and legacy semantic golden match or have an approved diff; telemetry names the versioned definition; presentation instances stay within budget and visual output is present; no legacy double-publish. A published presentation_event has one visible consumer result and cleanup returns the fixed-capacity store to baseline.
- Reload Mode: `F4_TO_F5 for Lua; REOPEN_LEVEL_XML for XML/catalog placement`
- Regression: Four vertical slices, 109-weapon definition snapshot, presentation sequence/generation guards and legacy fallback.
- Evidence: Compiler/parity reports, telemetry event chain, budget counters, screenshots, log slice and Harness.

## Step 2.8 — 切换 Effect Runtime 权威并删除第一批旧路径

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Build a representative legacy/candidate pair and a deterministic scene containing only the affected definitions/effects.
- Trigger: Run static parity first, reload the scenario, then use the minimum real fire/preview action required by the profile.
- Assertions: Compiled identity and legacy semantic golden match or have an approved diff; telemetry names the versioned definition; presentation instances stay within budget and visual output is present; no legacy double-publish. A published presentation_event has one visible consumer result and cleanup returns the fixed-capacity store to baseline.
- Reload Mode: `F4_TO_F5 for Lua; REOPEN_LEVEL_XML for XML/catalog placement`
- Regression: Four vertical slices, 109-weapon definition snapshot, presentation sequence/generation guards and legacy fallback.
- Evidence: Compiler/parity reports, telemetry event chain, budget counters, screenshots, log slice and Harness.

## Step 3.1 — 将全部现有 Effect Profile 转为版本化来源

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Build a representative legacy/candidate pair and a deterministic scene containing only the affected definitions/effects.
- Trigger: Run static parity first, reload the scenario, then use the minimum real fire/preview action required by the profile.
- Assertions: Compiled identity and legacy semantic golden match or have an approved diff; telemetry names the versioned definition; presentation instances stay within budget and visual output is present; no legacy double-publish. A published presentation_event has one visible consumer result and cleanup returns the fixed-capacity store to baseline.
- Reload Mode: `F4_TO_F5 for Lua; REOPEN_LEVEL_XML for XML/catalog placement`
- Regression: Four vertical slices, 109-weapon definition snapshot, presentation sequence/generation guards and legacy fallback.
- Evidence: Compiler/parity reports, telemetry event chain, budget counters, screenshots, log slice and Harness.

## Step 3.2 — 迁移 109 个 Weapon 与 Projectile

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Build a representative legacy/candidate pair and a deterministic scene containing only the affected definitions/effects.
- Trigger: Run static parity first, reload the scenario, then use the minimum real fire/preview action required by the profile.
- Assertions: Compiled identity and legacy semantic golden match or have an approved diff; telemetry names the versioned definition; presentation instances stay within budget and visual output is present; no legacy double-publish.
- Reload Mode: `F4_TO_F5 for Lua; REOPEN_LEVEL_XML for XML/catalog placement`
- Regression: Four vertical slices, 109-weapon definition snapshot, presentation sequence/generation guards and legacy fallback.
- Evidence: Compiler/parity reports, telemetry event chain, budget counters, screenshots, log slice and Harness.

## Step 3.3 — 迁移 Vehicle、Mount、Component 和 AI Interceptor 定义

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + LOG`
- Setup: Build a representative legacy/candidate pair and a deterministic scene containing only the affected definitions/effects.
- Trigger: Run static parity first, reload the scenario, then use the minimum real fire/preview action required by the profile.
- Assertions: Compiled identity and legacy semantic golden match or have an approved diff; telemetry names the versioned definition; presentation instances stay within budget and visual output is present; no legacy double-publish.
- Reload Mode: `F4_TO_F5 for Lua; REOPEN_LEVEL_XML for XML/catalog placement`
- Regression: Four vertical slices, 109-weapon definition snapshot, presentation sequence/generation guards and legacy fallback.
- Evidence: Compiler/parity reports, telemetry event chain, budget counters, screenshots, log slice and Harness.

## Step 3.4 — 建立版本化 Loadout/Configuration 合同

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + LOG`
- Setup: Build a representative legacy/candidate pair and a deterministic scene containing only the affected definitions/effects.
- Trigger: Load V0/V1 valid and invalid loadouts, exercise one real selection/fire, save/reload and compare normalized state.
- Assertions: Compiled identity and legacy semantic golden match or have an approved diff; telemetry names the versioned definition; presentation instances stay within budget and visual output is present; no legacy double-publish. Migration is idempotent; selected group/mount survives reload; invalid references fail closed.
- Reload Mode: `F4_TO_F5 for Lua; REOPEN_LEVEL_XML for XML/catalog placement`
- Regression: Four vertical slices, 109-weapon definition snapshot, presentation sequence/generation guards and legacy fallback.
- Evidence: Compiler/parity reports, telemetry event chain, budget counters, screenshots, log slice and Harness.

## Step 3.5 — 迁移 Harness 合同并切换 Generated Catalog

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + LOG`
- Setup: Build a representative legacy/candidate pair and a deterministic scene containing only the affected definitions/effects.
- Trigger: Run static parity first, reload the scenario, then use the minimum real fire/preview action required by the profile.
- Assertions: Compiled identity and legacy semantic golden match or have an approved diff; telemetry names the versioned definition; presentation instances stay within budget and visual output is present; no legacy double-publish.
- Reload Mode: `F4_TO_F5 for Lua; REOPEN_LEVEL_XML for XML/catalog placement`
- Regression: Four vertical slices, 109-weapon definition snapshot, presentation sequence/generation guards and legacy fallback.
- Evidence: Compiler/parity reports, telemetry event chain, budget counters, screenshots, log slice and Harness.

## Step 3.6 — 冻结 Catalog 并移除 Runtime Legacy Definition 权威

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + LOG`
- Setup: Build a representative legacy/candidate pair and a deterministic scene containing only the affected definitions/effects.
- Trigger: Run static parity first, reload the scenario, then use the minimum real fire/preview action required by the profile.
- Assertions: Compiled identity and legacy semantic golden match or have an approved diff; telemetry names the versioned definition; presentation instances stay within budget and visual output is present; no legacy double-publish.
- Reload Mode: `F4_TO_F5 for Lua; REOPEN_LEVEL_XML for XML/catalog placement`
- Regression: Four vertical slices, 109-weapon definition snapshot, presentation sequence/generation guards and legacy fallback.
- Evidence: Compiler/parity reports, telemetry event chain, budget counters, screenshots, log slice and Harness.

## Step 4.1 — 先做“两船、两 Context、一个 Host”技术 Spike

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + LOG + MULTIPLAYER`
- Setup: Use a two-ship, two-context fixture with one Host and at least one Client; fixed ownership, generations and command sequence.
- Trigger: Start official two-player local mode; issue one real command from the owning player and one invalid/non-owner command.
- Assertions: Host alone mutates world state; invalid owner/capability/generation/sequence is rejected; Host/Client converge without duplicate presentation, damage or stale resurrection.
- Reload Mode: `RESTART_MOD_SESSION (terminate and relaunch every teardown_modtest instance)`
- Regression: Single-player authority, presentation ordering, registry lifecycle and multiplayer reconnect/late-join where claimed.
- Evidence: Per-window PID/HWND/status, Host and Client traces/screenshots, event generations/sequences, logs, cleanup counts and Harness.

## Step 4.2 — 定义 World Protocol、Owner Lease 和 Capability

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + LOG + MULTIPLAYER`
- Setup: Use a two-ship, two-context fixture with one Host and at least one Client; fixed ownership, generations and command sequence.
- Trigger: Start official two-player local mode; issue one real command from the owning player and one invalid/non-owner command.
- Assertions: Host alone mutates world state; invalid owner/capability/generation/sequence is rejected; Host/Client converge without duplicate presentation, damage or stale resurrection.
- Reload Mode: `RESTART_MOD_SESSION (terminate and relaunch every teardown_modtest instance)`
- Regression: Single-player authority, presentation ordering, registry lifecycle and multiplayer reconnect/late-join where claimed.
- Evidence: Per-window PID/HWND/status, Host and Client traces/screenshots, event generations/sequences, logs, cleanup counts and Harness.

## Step 4.3 — 建立 World Host Skeleton 与 Ship Instance Adapter

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + LOG + MULTIPLAYER`
- Setup: Use a two-ship, two-context fixture with one Host and at least one Client; fixed ownership, generations and command sequence.
- Trigger: Start official two-player local mode; issue one real command from the owning player and one invalid/non-owner command.
- Assertions: Host alone mutates world state; invalid owner/capability/generation/sequence is rejected; Host/Client converge without duplicate presentation, damage or stale resurrection.
- Reload Mode: `RESTART_MOD_SESSION (terminate and relaunch every teardown_modtest instance)`
- Regression: Single-player authority, presentation ordering, registry lifecycle and multiplayer reconnect/late-join where claimed.
- Evidence: Per-window PID/HWND/status, Host and Client traces/screenshots, event generations/sequences, logs, cleanup counts and Harness.

## Step 4.4 — 把 Presentation 与 Audio Ownership 移到 Host

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG + MULTIPLAYER`
- Setup: Use a two-ship, two-context fixture with one Host and at least one Client; fixed ownership, generations and command sequence.
- Trigger: Start official two-player local mode; issue one real command from the owning player and one invalid/non-owner command.
- Assertions: Host alone mutates world state; invalid owner/capability/generation/sequence is rejected; Host/Client converge without duplicate presentation, damage or stale resurrection. A published presentation_event has one visible consumer result and cleanup returns the fixed-capacity store to baseline.
- Reload Mode: `RESTART_MOD_SESSION (terminate and relaunch every teardown_modtest instance)`
- Regression: Single-player authority, presentation ordering, registry lifecycle and multiplayer reconnect/late-join where claimed.
- Evidence: Per-window PID/HWND/status, Host and Client traces/screenshots, event generations/sequences, logs, cleanup counts and Harness.

## Step 4.5 — 建立 Registry Snapshot、Scheduler 与 Damage Inbox

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + LOG + MULTIPLAYER`
- Setup: Use a two-ship, two-context fixture with one Host and at least one Client; fixed ownership, generations and command sequence.
- Trigger: Start official two-player local mode; issue one real command from the owning player and one invalid/non-owner command.
- Assertions: Host alone mutates world state; invalid owner/capability/generation/sequence is rejected; Host/Client converge without duplicate presentation, damage or stale resurrection.
- Reload Mode: `RESTART_MOD_SESSION (terminate and relaunch every teardown_modtest instance)`
- Regression: Single-player authority, presentation ordering, registry lifecycle and multiplayer reconnect/late-join where claimed.
- Evidence: Per-window PID/HWND/status, Host and Client traces/screenshots, event generations/sequences, logs, cleanup counts and Harness.

## Step 4.6 — 版本化多人 Command/Snapshot 边界

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + LOG + MULTIPLAYER`
- Setup: Use a two-ship, two-context fixture with one Host and at least one Client; fixed ownership, generations and command sequence.
- Trigger: Start official two-player local mode; issue one real command from the owning player and one invalid/non-owner command.
- Assertions: Host alone mutates world state; invalid owner/capability/generation/sequence is rejected; Host/Client converge without duplicate presentation, damage or stale resurrection. Server/Client source, player, generation and sequence are explicit in evidence.
- Reload Mode: `RESTART_MOD_SESSION (terminate and relaunch every teardown_modtest instance)`
- Regression: Single-player authority, presentation ordering, registry lifecycle and multiplayer reconnect/late-join where claimed.
- Evidence: Per-window PID/HWND/status, Host and Client traces/screenshots, event generations/sequences, logs, cleanup counts and Harness.

## Step 5.1 — 把实体索引从 Registry 全表压缩改为本地 Dense Store

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + LOG`
- Setup: Construct low/high-density deterministic battlefield fixtures with fixed projectiles, ships, cells, mounts and budgets.
- Trigger: Run identical seeded actions at baseline and pressure scale; collect authoritative counts/timings without manual flight.
- Assertions: Semantic hit/selection/collision parity holds; stores/queries remain bounded; no P×S fallback or stale handle; p95/p99 and allocation/GC metrics meet the declared budget.
- Reload Mode: `F4_TO_F5; REOPEN_LEVEL_XML when entity density/placement changes`
- Regression: Direct/guided/PD/interceptor collision golden, lifecycle cleanup and S0–S8 performance baselines.
- Evidence: Seed/config, telemetry counts, before/after performance samples, hit traces, screenshots, logs and Harness.

## Step 5.2 — 建立 Scene Target Catalog 与简单 Uniform Grid

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + LOG`
- Setup: Construct low/high-density deterministic battlefield fixtures with fixed projectiles, ships, cells, mounts and budgets.
- Trigger: Run identical seeded actions at baseline and pressure scale; collect authoritative counts/timings without manual flight.
- Assertions: Semantic hit/selection/collision parity holds; stores/queries remain bounded; no P×S fallback or stale handle; p95/p99 and allocation/GC metrics meet the declared budget.
- Reload Mode: `F4_TO_F5; REOPEN_LEVEL_XML when entity density/placement changes`
- Regression: Direct/guided/PD/interceptor collision golden, lifecycle cleanup and S0–S8 performance baselines.
- Evidence: Seed/config, telemetry counts, before/after performance samples, hit traces, screenshots, logs and Harness.

## Step 5.3 — 重构 Point Defense 为“每舰一次候选 + Mount 分配”

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Construct low/high-density deterministic battlefield fixtures with fixed projectiles, ships, cells, mounts and budgets.
- Trigger: Run identical seeded actions at baseline and pressure scale; collect authoritative counts/timings without manual flight.
- Assertions: Semantic hit/selection/collision parity holds; stores/queries remain bounded; no P×S fallback or stale handle; p95/p99 and allocation/GC metrics meet the declared budget.
- Reload Mode: `F4_TO_F5; REOPEN_LEVEL_XML when entity density/placement changes`
- Regression: Direct/guided/PD/interceptor collision golden, lifecycle cleanup and S0–S8 performance baselines.
- Evidence: Seed/config, telemetry counts, before/after performance samples, hit traces, screenshots, logs and Harness.

## Step 5.4 — 建立统一 Projectile API 与 Logical Dense Store

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Construct low/high-density deterministic battlefield fixtures with fixed projectiles, ships, cells, mounts and budgets.
- Trigger: Run identical seeded actions at baseline and pressure scale; collect authoritative counts/timings without manual flight.
- Assertions: Semantic hit/selection/collision parity holds; stores/queries remain bounded; no P×S fallback or stale handle; p95/p99 and allocation/GC metrics meet the declared budget.
- Reload Mode: `F4_TO_F5; REOPEN_LEVEL_XML when entity density/placement changes`
- Regression: Direct/guided/PD/interceptor collision golden, lifecycle cleanup and S0–S8 performance baselines.
- Evidence: Seed/config, telemetry counts, before/after performance samples, hit traces, screenshots, logs and Harness.

## Step 5.5 — 消除普通弹丸的 `P×S` 护盾扫描

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Construct low/high-density deterministic battlefield fixtures with fixed projectiles, ships, cells, mounts and budgets.
- Trigger: Run identical seeded actions at baseline and pressure scale; collect authoritative counts/timings without manual flight.
- Assertions: Semantic hit/selection/collision parity holds; stores/queries remain bounded; no P×S fallback or stale handle; p95/p99 and allocation/GC metrics meet the declared budget.
- Reload Mode: `F4_TO_F5; REOPEN_LEVEL_XML when entity density/placement changes`
- Regression: Direct/guided/PD/interceptor collision golden, lifecycle cleanup and S0–S8 performance baselines.
- Evidence: Seed/config, telemetry counts, before/after performance samples, hit traces, screenshots, logs and Harness.

## Step 5.6 — 将 Guided Collision 从五 Query 常态改为受预算连续扫掠

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Construct low/high-density deterministic battlefield fixtures with fixed projectiles, ships, cells, mounts and budgets.
- Trigger: Run identical seeded actions at baseline and pressure scale; collect authoritative counts/timings without manual flight.
- Assertions: Semantic hit/selection/collision parity holds; stores/queries remain bounded; no P×S fallback or stale handle; p95/p99 and allocation/GC metrics meet the declared budget.
- Reload Mode: `F4_TO_F5; REOPEN_LEVEL_XML when entity density/placement changes`
- Regression: Direct/guided/PD/interceptor collision golden, lifecycle cleanup and S0–S8 performance baselines.
- Evidence: Seed/config, telemetry counts, before/after performance samples, hit traces, screenshots, logs and Harness.

## Step 5.7 — 建立精简 Interceptor Runtime

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Construct low/high-density deterministic battlefield fixtures with fixed projectiles, ships, cells, mounts and budgets.
- Trigger: Run identical seeded actions at baseline and pressure scale; collect authoritative counts/timings without manual flight.
- Assertions: Semantic hit/selection/collision parity holds; stores/queries remain bounded; no P×S fallback or stale handle; p95/p99 and allocation/GC metrics meet the declared budget.
- Reload Mode: `F4_TO_F5; REOPEN_LEVEL_XML when entity density/placement changes`
- Regression: Direct/guided/PD/interceptor collision golden, lifecycle cleanup and S0–S8 performance baselines.
- Evidence: Seed/config, telemetry counts, before/after performance samples, hit traces, screenshots, logs and Harness.

## Step 5.8 — 清理剩余固定浪费和 GC 热点

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + LOG`
- Setup: Construct low/high-density deterministic battlefield fixtures with fixed projectiles, ships, cells, mounts and budgets.
- Trigger: Run identical seeded actions at baseline and pressure scale; collect authoritative counts/timings without manual flight.
- Assertions: Semantic hit/selection/collision parity holds; stores/queries remain bounded; no P×S fallback or stale handle; p95/p99 and allocation/GC metrics meet the declared budget.
- Reload Mode: `F4_TO_F5; REOPEN_LEVEL_XML when entity density/placement changes`
- Regression: Direct/guided/PD/interceptor collision golden, lifecycle cleanup and S0–S8 performance baselines.
- Evidence: Seed/config, telemetry counts, before/after performance samples, hit traces, screenshots, logs and Harness.

## Step 6.1 — 用 VehicleInstance 包装现有单根 Body

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Setup: Use single-body and minimal multi-body/joint fixtures with named parts/anchors, fixed transforms and spawn/dispose repetitions.
- Trigger: Resolve anchors, move/fire once where relevant, then repeatedly spawn and dispose the entity graph.
- Assertions: Stable entity/part identity and parent-local transforms resolve correctly; no root-body authority fallback remains; all bodies/joints/anchors/register entries are disposed exactly once.
- Reload Mode: `REOPEN_LEVEL_XML for graph/prefab changes; F4_TO_F5 for resolver Lua`
- Regression: Existing single-body ships, weapon muzzle/effect/camera anchors, damage and lifecycle cleanup.
- Evidence: Graph snapshot, transform tolerances, spawn/dispose event trace, screenshots, logs and Harness.

## Step 6.2 — 建立 EntityGraph 与稳定 Part/Anchor Resolver

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Setup: Use single-body and minimal multi-body/joint fixtures with named parts/anchors, fixed transforms and spawn/dispose repetitions.
- Trigger: Resolve anchors, move/fire once where relevant, then repeatedly spawn and dispose the entity graph.
- Assertions: Stable entity/part identity and parent-local transforms resolve correctly; no root-body authority fallback remains; all bodies/joints/anchors/register entries are disposed exactly once.
- Reload Mode: `REOPEN_LEVEL_XML for graph/prefab changes; F4_TO_F5 for resolver Lua`
- Regression: Existing single-body ships, weapon muzzle/effect/camera anchors, damage and lifecycle cleanup.
- Evidence: Graph snapshot, transform tolerances, spawn/dispose event trace, screenshots, logs and Harness.

## Step 6.3 — 建立统一 Transform/Anchor API

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Setup: Use single-body and minimal multi-body/joint fixtures with named parts/anchors, fixed transforms and spawn/dispose repetitions.
- Trigger: Resolve anchors, move/fire once where relevant, then repeatedly spawn and dispose the entity graph.
- Assertions: Stable entity/part identity and parent-local transforms resolve correctly; no root-body authority fallback remains; all bodies/joints/anchors/register entries are disposed exactly once.
- Reload Mode: `REOPEN_LEVEL_XML for graph/prefab changes; F4_TO_F5 for resolver Lua`
- Regression: Existing single-body ships, weapon muzzle/effect/camera anchors, damage and lifecycle cleanup.
- Evidence: Graph snapshot, transform tolerances, spawn/dispose event trace, screenshots, logs and Harness.

## Step 6.4 — 按顺序把现有系统迁移到 AnchorResolver

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Setup: Use single-body and minimal multi-body/joint fixtures with named parts/anchors, fixed transforms and spawn/dispose repetitions.
- Trigger: Resolve anchors, move/fire once where relevant, then repeatedly spawn and dispose the entity graph.
- Assertions: Stable entity/part identity and parent-local transforms resolve correctly; no root-body authority fallback remains; all bodies/joints/anchors/register entries are disposed exactly once.
- Reload Mode: `REOPEN_LEVEL_XML for graph/prefab changes; F4_TO_F5 for resolver Lua`
- Regression: Existing single-body ships, weapon muzzle/effect/camera anchors, damage and lifecycle cleanup.
- Evidence: Graph snapshot, transform tolerances, spawn/dispose event trace, screenshots, logs and Harness.

## Step 6.5 — 引入最小多 Body/Joint Fixture，不做正式炮塔

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Setup: Use single-body and minimal multi-body/joint fixtures with named parts/anchors, fixed transforms and spawn/dispose repetitions.
- Trigger: Resolve anchors, move/fire once where relevant, then repeatedly spawn and dispose the entity graph.
- Assertions: Stable entity/part identity and parent-local transforms resolve correctly; no root-body authority fallback remains; all bodies/joints/anchors/register entries are disposed exactly once.
- Reload Mode: `REOPEN_LEVEL_XML for graph/prefab changes; F4_TO_F5 for resolver Lua`
- Regression: Existing single-body ships, weapon muzzle/effect/camera anchors, damage and lifecycle cleanup.
- Evidence: Graph snapshot, transform tolerances, spawn/dispose event trace, screenshots, logs and Harness.

## Step 6.6 — 建立 Vehicle Factory 与动态 Spawn/Dispose API

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Use single-body and minimal multi-body/joint fixtures with named parts/anchors, fixed transforms and spawn/dispose repetitions.
- Trigger: Resolve anchors, move/fire once where relevant, then repeatedly spawn and dispose the entity graph.
- Assertions: Stable entity/part identity and parent-local transforms resolve correctly; no root-body authority fallback remains; all bodies/joints/anchors/register entries are disposed exactly once.
- Reload Mode: `REOPEN_LEVEL_XML for graph/prefab changes; F4_TO_F5 for resolver Lua`
- Regression: Existing single-body ships, weapon muzzle/effect/camera anchors, damage and lifecycle cleanup.
- Evidence: Graph snapshot, transform tolerances, spawn/dispose event trace, screenshots, logs and Harness.

## Step 6.7 — 切换现有舰船并删除根 Body 坐标权威

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Use single-body and minimal multi-body/joint fixtures with named parts/anchors, fixed transforms and spawn/dispose repetitions.
- Trigger: Resolve anchors, move/fire once where relevant, then repeatedly spawn and dispose the entity graph.
- Assertions: Stable entity/part identity and parent-local transforms resolve correctly; no root-body authority fallback remains; all bodies/joints/anchors/register entries are disposed exactly once.
- Reload Mode: `REOPEN_LEVEL_XML for graph/prefab changes; F4_TO_F5 for resolver Lua`
- Regression: Existing single-body ships, weapon muzzle/effect/camera anchors, damage and lifecycle cleanup.
- Evidence: Graph snapshot, transform tolerances, spawn/dispose event trace, screenshots, logs and Harness.

## Step 7.1 — 编译 `TurretDefinition v1` 与炮塔 Fixture

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Place a turret fixture and target at known azimuth/elevation/range, including limits, LOD and joint-budget pressure cases.
- Trigger: Run solver golden, then use real aim/fire/movement; for network work repeat from Host and Client authority contexts.
- Assertions: Angles/limits/convergence match solver tolerance; visual/physical actuator follows logical state; muzzle anchor and hit align; network sequence is monotonic; joint fallback respects budget.
- Reload Mode: `REOPEN_LEVEL_XML for turret/joint fixture; F4_TO_F5 for solver/runtime Lua; multiplayer relaunch for network`
- Regression: Fixed-mount weapons, anchor resolver, projectile/hit chain, LOD and multiplayer ownership.
- Evidence: Solver vectors, telemetry angles/owners/hits, screenshots/video frames, budget metrics, logs and Harness.

## Step 7.2 — 实现纯逻辑 TurretSolver

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Setup: Place a turret fixture and target at known azimuth/elevation/range, including limits, LOD and joint-budget pressure cases.
- Trigger: Run solver golden, then use real aim/fire/movement; for network work repeat from Host and Client authority contexts.
- Assertions: Angles/limits/convergence match solver tolerance; visual/physical actuator follows logical state; muzzle anchor and hit align; network sequence is monotonic; joint fallback respects budget.
- Reload Mode: `REOPEN_LEVEL_XML for turret/joint fixture; F4_TO_F5 for solver/runtime Lua; multiplayer relaunch for network`
- Regression: Fixed-mount weapons, anchor resolver, projectile/hit chain, LOD and multiplayer ownership.
- Evidence: Solver vectors, telemetry angles/owners/hits, screenshots/video frames, budget metrics, logs and Harness.

## Step 7.3 — 增加 Visual Actuator 与 LOD

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Place a turret fixture and target at known azimuth/elevation/range, including limits, LOD and joint-budget pressure cases.
- Trigger: Run solver golden, then use real aim/fire/movement; for network work repeat from Host and Client authority contexts.
- Assertions: Angles/limits/convergence match solver tolerance; visual/physical actuator follows logical state; muzzle anchor and hit align; network sequence is monotonic; joint fallback respects budget.
- Reload Mode: `REOPEN_LEVEL_XML for turret/joint fixture; F4_TO_F5 for solver/runtime Lua; multiplayer relaunch for network`
- Regression: Fixed-mount weapons, anchor resolver, projectile/hit chain, LOD and multiplayer ownership.
- Evidence: Solver vectors, telemetry angles/owners/hits, screenshots/video frames, budget metrics, logs and Harness.

## Step 7.4 — 完成 Turret Network 与多人权威

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG + MULTIPLAYER`
- Setup: Place a turret fixture and target at known azimuth/elevation/range, including limits, LOD and joint-budget pressure cases.
- Trigger: Run solver golden, then use real aim/fire/movement; for network work repeat from Host and Client authority contexts.
- Assertions: Angles/limits/convergence match solver tolerance; visual/physical actuator follows logical state; muzzle anchor and hit align; network sequence is monotonic; joint fallback respects budget. Server/Client source, player, generation and sequence are explicit in evidence.
- Reload Mode: `REOPEN_LEVEL_XML for turret/joint fixture; F4_TO_F5 for solver/runtime Lua; multiplayer relaunch for network`
- Regression: Fixed-mount weapons, anchor resolver, projectile/hit chain, LOD and multiplayer ownership.
- Evidence: Solver vectors, telemetry angles/owners/hits, screenshots/video frames, budget metrics, logs and Harness.

## Step 7.5 — 用 Hero Fixture 验证 Physical Joint Actuator

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Place a turret fixture and target at known azimuth/elevation/range, including limits, LOD and joint-budget pressure cases.
- Trigger: Run solver golden, then use real aim/fire/movement; for network work repeat from Host and Client authority contexts.
- Assertions: Angles/limits/convergence match solver tolerance; visual/physical actuator follows logical state; muzzle anchor and hit align; network sequence is monotonic; joint fallback respects budget.
- Reload Mode: `REOPEN_LEVEL_XML for turret/joint fixture; F4_TO_F5 for solver/runtime Lua; multiplayer relaunch for network`
- Regression: Fixed-mount weapons, anchor resolver, projectile/hit chain, LOD and multiplayer ownership.
- Evidence: Solver vectors, telemetry angles/owners/hits, screenshots/video frames, budget metrics, logs and Harness.

## Step 7.6 — 建立 Scene-wide Joint Budget 与自动降级

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Place a turret fixture and target at known azimuth/elevation/range, including limits, LOD and joint-budget pressure cases.
- Trigger: Run solver golden, then use real aim/fire/movement; for network work repeat from Host and Client authority contexts.
- Assertions: Angles/limits/convergence match solver tolerance; visual/physical actuator follows logical state; muzzle anchor and hit align; network sequence is monotonic; joint fallback respects budget.
- Reload Mode: `REOPEN_LEVEL_XML for turret/joint fixture; F4_TO_F5 for solver/runtime Lua; multiplayer relaunch for network`
- Regression: Fixed-mount weapons, anchor resolver, projectile/hit chain, LOD and multiplayer ownership.
- Evidence: Solver vectors, telemetry angles/owners/hits, screenshots/video frames, budget metrics, logs and Harness.

## Step 7.7 — 删除固定根 Body 炮口假设并开放炮塔内容

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Setup: Place a turret fixture and target at known azimuth/elevation/range, including limits, LOD and joint-budget pressure cases.
- Trigger: Run solver golden, then use real aim/fire/movement; for network work repeat from Host and Client authority contexts.
- Assertions: Angles/limits/convergence match solver tolerance; visual/physical actuator follows logical state; muzzle anchor and hit align; network sequence is monotonic; joint fallback respects budget.
- Reload Mode: `REOPEN_LEVEL_XML for turret/joint fixture; F4_TO_F5 for solver/runtime Lua; multiplayer relaunch for network`
- Regression: Fixed-mount weapons, anchor resolver, projectile/hit chain, LOD and multiplayer ownership.
- Evidence: Solver vectors, telemetry angles/owners/hits, screenshots/video frames, budget metrics, logs and Harness.

## Step 8.1 — 建立只读 Asset Importer 与 `AssetManifest v1`

- Historical status: `finish`
- Audit: **CURRENTLY COVERED — rerun the listed regression when adjacent contracts change.**
- Test Profiles: `STATIC + FIXTURE + CONSUMER_MOD`
- Setup: Use read-only source assets plus disposable editor/preview projects covering valid, invalid and round-trip cases.
- Trigger: Import/build/edit/wizard-generate twice, validate outputs, then open the generated artifact in the appropriate preview scene.
- Assertions: Source is unchanged; outputs are deterministic/cache-correct; schema and anchors/mounts are valid; UI operations round-trip; preview loads and renders without runtime errors.
- Reload Mode: `NONE for tools; RESTART_MCP/tool process for code; REOPEN_LEVEL_XML for Teardown preview`
- Regression: Asset manifest, provenance, compiler/schema, VOX orientation/anchors and preview budget.
- Evidence: Source/output hashes, cache report, generated definitions, UI screenshots, preview screenshot/log and Harness.

## Step 8.2 — 把 Asset Build 变成确定性、可缓存的 Pipeline

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + CONSUMER_MOD`
- Setup: Use read-only source assets plus disposable editor/preview projects covering valid, invalid and round-trip cases.
- Trigger: Import/build/edit/wizard-generate twice, validate outputs, then open the generated artifact in the appropriate preview scene.
- Assertions: Source is unchanged; outputs are deterministic/cache-correct; schema and anchors/mounts are valid; UI operations round-trip; preview loads and renders without runtime errors.
- Reload Mode: `NONE for tools; RESTART_MCP/tool process for code; REOPEN_LEVEL_XML for Teardown preview`
- Regression: Asset manifest, provenance, compiler/schema, VOX orientation/anchors and preview budget.
- Evidence: Source/output hashes, cache report, generated definitions, UI screenshots, preview screenshot/log and Harness.

## Step 8.3 — 把 Preview 扩展为 Effect Lab、Weapon Range 和 Ship Dock

- Historical status: `finish`
- Audit: **CURRENTLY COVERED — rerun the listed regression when adjacent contracts change.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + VISUAL + LOG`
- Setup: Use read-only source assets plus disposable editor/preview projects covering valid, invalid and round-trip cases.
- Trigger: Import/build/edit/wizard-generate twice, validate outputs, then open the generated artifact in the appropriate preview scene.
- Assertions: Source is unchanged; outputs are deterministic/cache-correct; schema and anchors/mounts are valid; UI operations round-trip; preview loads and renders without runtime errors. A published presentation_event has one visible consumer result and cleanup returns the fixed-capacity store to baseline.
- Reload Mode: `NONE for tools; RESTART_MCP/tool process for code; REOPEN_LEVEL_XML for Teardown preview`
- Regression: Asset manifest, provenance, compiler/schema, VOX orientation/anchors and preview budget.
- Evidence: Source/output hashes, cache report, generated definitions, UI screenshots, preview screenshot/log and Harness.

## Step 8.4 — 先做无 3D 的 Schema-driven Definition Editor MVP

- Historical status: `finish`
- Audit: **CURRENTLY COVERED — rerun the listed regression when adjacent contracts change.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + VISUAL + LOG`
- Setup: Use read-only source assets plus disposable editor/preview projects covering valid, invalid and round-trip cases.
- Trigger: Import/build/edit/wizard-generate twice, validate outputs, then open the generated artifact in the appropriate preview scene.
- Assertions: Source is unchanged; outputs are deterministic/cache-correct; schema and anchors/mounts are valid; UI operations round-trip; preview loads and renders without runtime errors.
- Reload Mode: `NONE for tools; RESTART_MCP/tool process for code; REOPEN_LEVEL_XML for Teardown preview`
- Regression: Asset manifest, provenance, compiler/schema, VOX orientation/anchors and preview budget.
- Evidence: Source/output hashes, cache report, generated definitions, UI screenshots, preview screenshot/log and Harness.

## Step 8.5 — 增加 VOX、Anchor、Mount 与 Turret 3D Editor

- Historical status: `finish`
- Audit: **CURRENTLY COVERED — rerun the listed regression when adjacent contracts change.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + VISUAL + LOG`
- Setup: Use read-only source assets plus disposable editor/preview projects covering valid, invalid and round-trip cases.
- Trigger: Import/build/edit/wizard-generate twice, validate outputs, then open the generated artifact in the appropriate preview scene.
- Assertions: Source is unchanged; outputs are deterministic/cache-correct; schema and anchors/mounts are valid; UI operations round-trip; preview loads and renders without runtime errors.
- Reload Mode: `NONE for tools; RESTART_MCP/tool process for code; REOPEN_LEVEL_XML for Teardown preview`
- Regression: Asset manifest, provenance, compiler/schema, VOX orientation/anchors and preview budget.
- Evidence: Source/output hashes, cache report, generated definitions, UI screenshots, preview screenshot/log and Harness.

## Step 8.6 — 实现 Creator Ship Wizard MVP

- Historical status: `finish`
- Audit: **CURRENTLY COVERED — rerun the listed regression when adjacent contracts change.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + VISUAL + LOG`
- Setup: Use read-only source assets plus disposable editor/preview projects covering valid, invalid and round-trip cases.
- Trigger: Import/build/edit/wizard-generate twice, validate outputs, then open the generated artifact in the appropriate preview scene.
- Assertions: Source is unchanged; outputs are deterministic/cache-correct; schema and anchors/mounts are valid; UI operations round-trip; preview loads and renders without runtime errors.
- Reload Mode: `NONE for tools; RESTART_MCP/tool process for code; REOPEN_LEVEL_XML for Teardown preview`
- Regression: Asset manifest, provenance, compiler/schema, VOX orientation/anchors and preview budget.
- Evidence: Source/output hashes, cache report, generated definitions, UI screenshots, preview screenshot/log and Harness.

## Step 9.1 — 定义 `PackageManifest v1` 与 Data-only Capability

- Historical status: `finish`
- Audit: **CURRENTLY COVERED — rerun the listed regression when adjacent contracts change.**
- Test Profiles: `STATIC + FIXTURE + CONSUMER_MOD`
- Setup: Install a clean-room disposable consumer package/Mod that depends only on the published manifest, SDK, schema or broker surface.
- Trigger: Build/install in a clean output, discover it in Mod Manager, start it and invoke one valid plus one invalid public operation.
- Assertions: No private CM2 path is copied; dependency/version/capability checks are explicit; compatible package runs; incompatible input fails closed; release contents and hashes match manifest.
- Reload Mode: `REOPEN_MOD_MANAGER for new/metadata Mod; RESTART_MOD_SESSION for runtime; NONE for CLI-only`
- Regression: Basic consumer fixture, package compatibility, clean-room build, Core-only and rollback package.
- Evidence: Consumer source, package manifest/hash, install trace, runtime telemetry/screenshot/log when applicable and Harness.

## Step 9.2 — 实现 Creator SDK CLI Alpha

- Historical status: `finish`
- Audit: **NEEDS REGRESSION — completion is retained, but current policy requires missing live evidence.**
- Test Profiles: `STATIC + FIXTURE + CONSUMER_MOD`
- Setup: Install a clean-room disposable consumer package/Mod that depends only on the published manifest, SDK, schema or broker surface.
- Trigger: Build/install in a clean output, discover it in Mod Manager, start it and invoke one valid plus one invalid public operation.
- Assertions: No private CM2 path is copied; dependency/version/capability checks are explicit; compatible package runs; incompatible input fails closed; release contents and hashes match manifest.
- Reload Mode: `REOPEN_MOD_MANAGER for new/metadata Mod; RESTART_MOD_SESSION for runtime; NONE for CLI-only`
- Regression: Basic consumer fixture, package compatibility, clean-room build, Core-only and rollback package.
- Evidence: Consumer source, package manifest/hash, install trace, runtime telemetry/screenshot/log when applicable and Harness.

## Step 9.3 — 完成真正独立的 `hello-ship` Clean-room 包

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG + CONSUMER_MOD`
- Setup: Install a clean-room disposable consumer package/Mod that depends only on the published manifest, SDK, schema or broker surface.
- Trigger: Build/install in a clean output, discover it in Mod Manager, start it and invoke one valid plus one invalid public operation.
- Assertions: No private CM2 path is copied; dependency/version/capability checks are explicit; compatible package runs; incompatible input fails closed; release contents and hashes match manifest.
- Reload Mode: `REOPEN_MOD_MANAGER for new/metadata Mod; RESTART_MOD_SESSION for runtime; NONE for CLI-only`
- Regression: Basic consumer fixture, package compatibility, clean-room build, Core-only and rollback package.
- Evidence: Consumer source, package manifest/hash, install trace, runtime telemetry/screenshot/log when applicable and Harness.

## Step 9.4 — 把 `sync-cm2-to-global.ps1` 演进为 Release Builder

- Historical status: `finish`
- Audit: **CURRENTLY COVERED — rerun the listed regression when adjacent contracts change.**
- Test Profiles: `STATIC + FIXTURE + CONSUMER_MOD`
- Setup: Install a clean-room disposable consumer package/Mod that depends only on the published manifest, SDK, schema or broker surface.
- Trigger: Build/install in a clean output, discover it in Mod Manager, start it and invoke one valid plus one invalid public operation.
- Assertions: No private CM2 path is copied; dependency/version/capability checks are explicit; compatible package runs; incompatible input fails closed; release contents and hashes match manifest.
- Reload Mode: `REOPEN_MOD_MANAGER for new/metadata Mod; RESTART_MOD_SESSION for runtime; NONE for CLI-only`
- Regression: Basic consumer fixture, package compatibility, clean-room build, Core-only and rollback package.
- Evidence: Consumer source, package manifest/hash, install trace, runtime telemetry/screenshot/log when applicable and Harness.

## Step 9.5 — 建立 Schema/Core/Package 兼容与废弃政策

- Historical status: `finish`
- Audit: **CURRENTLY COVERED — rerun the listed regression when adjacent contracts change.**
- Test Profiles: `STATIC + FIXTURE + CONSUMER_MOD`
- Setup: Install a clean-room disposable consumer package/Mod that depends only on the published manifest, SDK, schema or broker surface.
- Trigger: Build/install in a clean output, discover it in Mod Manager, start it and invoke one valid plus one invalid public operation.
- Assertions: No private CM2 path is copied; dependency/version/capability checks are explicit; compatible package runs; incompatible input fails closed; release contents and hashes match manifest.
- Reload Mode: `REOPEN_MOD_MANAGER for new/metadata Mod; RESTART_MOD_SESSION for runtime; NONE for CLI-only`
- Regression: Basic consumer fixture, package compatibility, clean-room build, Core-only and rollback package.
- Evidence: Consumer source, package manifest/hash, install trace, runtime telemetry/screenshot/log when applicable and Harness.

## Step 9.6 — 定义 Expert Custom Behavior API，延后开放

- Historical status: `finish`
- Audit: **CURRENTLY COVERED — rerun the listed regression when adjacent contracts change.**
- Test Profiles: `STATIC + FIXTURE + CONSUMER_MOD`
- Setup: Install a clean-room disposable consumer package/Mod that depends only on the published manifest, SDK, schema or broker surface.
- Trigger: Build/install in a clean output, discover it in Mod Manager, start it and invoke one valid plus one invalid public operation.
- Assertions: No private CM2 path is copied; dependency/version/capability checks are explicit; compatible package runs; incompatible input fails closed; release contents and hashes match manifest.
- Reload Mode: `REOPEN_MOD_MANAGER for new/metadata Mod; RESTART_MOD_SESSION for runtime; NONE for CLI-only`
- Regression: Basic consumer fixture, package compatibility, clean-room build, Core-only and rollback package.
- Evidence: Consumer source, package manifest/hash, install trace, runtime telemetry/screenshot/log when applicable and Harness.

## Step 9.7 — 独立验证 Global Mod Broker，允许结论为“不采用”

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG + MULTIPLAYER + CONSUMER_MOD`
- Setup: Install a clean-room disposable consumer package/Mod that depends only on the published manifest, SDK, schema or broker surface.
- Trigger: Build/install in a clean output, discover it in Mod Manager, start it and invoke one valid plus one invalid public operation.
- Assertions: No private CM2 path is copied; dependency/version/capability checks are explicit; compatible package runs; incompatible input fails closed; release contents and hashes match manifest.
- Reload Mode: `REOPEN_MOD_MANAGER for new/metadata Mod; RESTART_MOD_SESSION for runtime; NONE for CLI-only`
- Regression: Basic consumer fixture, package compatibility, clean-room build, Core-only and rollback package.
- Evidence: Consumer source, package manifest/hash, install trace, runtime telemetry/screenshot/log when applicable and Harness.

## Step 9.8 — Creator SDK Beta

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG + CONSUMER_MOD`
- Setup: Install a clean-room disposable consumer package/Mod that depends only on the published manifest, SDK, schema or broker surface.
- Trigger: Build/install in a clean output, discover it in Mod Manager, start it and invoke one valid plus one invalid public operation.
- Assertions: No private CM2 path is copied; dependency/version/capability checks are explicit; compatible package runs; incompatible input fails closed; release contents and hashes match manifest.
- Reload Mode: `REOPEN_MOD_MANAGER for new/metadata Mod; RESTART_MOD_SESSION for runtime; NONE for CLI-only`
- Regression: Basic consumer fixture, package compatibility, clean-room build, Core-only and rollback package.
- Evidence: Consumer source, package manifest/hash, install trace, runtime telemetry/screenshot/log when applicable and Harness.

## Step 10.1 — 先建立 AI 评测集、权限边界与 Provenance

- Historical status: `finish`
- Audit: **CURRENTLY COVERED — rerun the listed regression when adjacent contracts change.**
- Test Profiles: `STATIC + FIXTURE + CONSUMER_MOD`
- Setup: Use a fixed AI evaluation corpus and disposable consumer output; deny undeclared network/file/runtime authority.
- Trigger: Generate twice from identical prompt/input, run policy/schema/provenance checks, then preview/package the accepted artifact through production tools.
- Assertions: Deterministic normalized result, explicit provenance and manual fields; no path escape/private code/runtime Lua/budget bypass; output compiles and consumer preview matches declared semantics.
- Reload Mode: `NONE for generation; REOPEN_MOD_MANAGER/REOPEN_LEVEL_XML for consumer preview`
- Regression: AI eval negatives, compiler/schema, asset provenance, package security and Core semantic invariance.
- Evidence: Prompt/input hash, provider/provenance record, normalized outputs/diff, validator report, consumer preview screenshot/log and Harness.

## Step 10.2 — 实现 AI Weapon Assistant

- Historical status: `finish`
- Audit: **NEEDS REGRESSION — completion is retained, but current policy requires missing live evidence.**
- Test Profiles: `STATIC + FIXTURE + SCENE + VISUAL + LOG + CONSUMER_MOD`
- Setup: Use a fixed AI evaluation corpus and disposable consumer output; deny undeclared network/file/runtime authority.
- Trigger: Generate twice from identical prompt/input, run policy/schema/provenance checks, then preview/package the accepted artifact through production tools.
- Assertions: Deterministic normalized result, explicit provenance and manual fields; no path escape/private code/runtime Lua/budget bypass; output compiles and consumer preview matches declared semantics.
- Reload Mode: `NONE for generation; REOPEN_MOD_MANAGER/REOPEN_LEVEL_XML for consumer preview`
- Regression: AI eval negatives, compiler/schema, asset provenance, package security and Core semantic invariance.
- Evidence: Prompt/input hash, provider/provenance record, normalized outputs/diff, validator report, consumer preview screenshot/log and Harness.

## Step 10.3 — 实现 AI Effect Assistant

- Historical status: `finish`
- Audit: **NEEDS REGRESSION — completion is retained, but current policy requires missing live evidence.**
- Test Profiles: `STATIC + FIXTURE + SCENE + VISUAL + LOG + CONSUMER_MOD`
- Setup: Use a fixed AI evaluation corpus and disposable consumer output; deny undeclared network/file/runtime authority.
- Trigger: Generate twice from identical prompt/input, run policy/schema/provenance checks, then preview/package the accepted artifact through production tools.
- Assertions: Deterministic normalized result, explicit provenance and manual fields; no path escape/private code/runtime Lua/budget bypass; output compiles and consumer preview matches declared semantics. A published presentation_event has one visible consumer result and cleanup returns the fixed-capacity store to baseline.
- Reload Mode: `NONE for generation; REOPEN_MOD_MANAGER/REOPEN_LEVEL_XML for consumer preview`
- Regression: AI eval negatives, compiler/schema, asset provenance, package security and Core semantic invariance.
- Evidence: Prompt/input hash, provider/provenance record, normalized outputs/diff, validator report, consumer preview screenshot/log and Harness.

## Step 10.4 — 先实现 Existing-VOX Ship Import Assistant

- Historical status: `finish`
- Audit: **NEEDS REGRESSION — completion is retained, but current policy requires missing live evidence.**
- Test Profiles: `STATIC + FIXTURE + SCENE + VISUAL + LOG + CONSUMER_MOD`
- Setup: Use a fixed AI evaluation corpus and disposable consumer output; deny undeclared network/file/runtime authority.
- Trigger: Generate twice from identical prompt/input, run policy/schema/provenance checks, then preview/package the accepted artifact through production tools.
- Assertions: Deterministic normalized result, explicit provenance and manual fields; no path escape/private code/runtime Lua/budget bypass; output compiles and consumer preview matches declared semantics.
- Reload Mode: `NONE for generation; REOPEN_MOD_MANAGER/REOPEN_LEVEL_XML for consumer preview`
- Regression: AI eval negatives, compiler/schema, asset provenance, package security and Core semantic invariance.
- Evidence: Prompt/input hash, provider/provenance record, normalized outputs/diff, validator report, consumer preview screenshot/log and Harness.

## Step 10.5 — 接入图片/文本到 3D 的外部 Pipeline

- Historical status: `finish`
- Audit: **CURRENTLY COVERED — rerun the listed regression when adjacent contracts change.**
- Test Profiles: `STATIC + FIXTURE + SCENE + VISUAL + LOG + CONSUMER_MOD`
- Setup: Use a fixed AI evaluation corpus and disposable consumer output; deny undeclared network/file/runtime authority.
- Trigger: Generate twice from identical prompt/input, run policy/schema/provenance checks, then preview/package the accepted artifact through production tools.
- Assertions: Deterministic normalized result, explicit provenance and manual fields; no path escape/private code/runtime Lua/budget bypass; output compiles and consumer preview matches declared semantics.
- Reload Mode: `NONE for generation; REOPEN_MOD_MANAGER/REOPEN_LEVEL_XML for consumer preview`
- Regression: AI eval negatives, compiler/schema, asset provenance, package security and Core semantic invariance.
- Evidence: Prompt/input hash, provider/provenance record, normalized outputs/diff, validator report, consumer preview screenshot/log and Harness.

## Step 10.6 — AI Creator Beta 与质量阈值

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + VISUAL + LOG + CONSUMER_MOD`
- Setup: Use a fixed AI evaluation corpus and disposable consumer output; deny undeclared network/file/runtime authority.
- Trigger: Generate twice from identical prompt/input, run policy/schema/provenance checks, then preview/package the accepted artifact through production tools.
- Assertions: Deterministic normalized result, explicit provenance and manual fields; no path escape/private code/runtime Lua/budget bypass; output compiles and consumer preview matches declared semantics.
- Reload Mode: `NONE for generation; REOPEN_MOD_MANAGER/REOPEN_LEVEL_XML for consumer preview`
- Regression: AI eval negatives, compiler/schema, asset provenance, package security and Core semantic invariance.
- Evidence: Prompt/input hash, provider/provenance record, normalized outputs/diff, validator report, consumer preview screenshot/log and Harness.

## Step 11.1 — 建立 End-to-end Golden Packages

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG + CONSUMER_MOD`
- Setup: Use immutable versioned release candidates plus independent consumer Mods; include baseline/upgrade/rollback and declared S0–S8 or soak topology.
- Trigger: Run every gate from a clean install; execute live single-player and required Host/Client scenarios; repeat after upgrade and exact rollback.
- Assertions: All component gates and negative cases pass; live runtime/soak/performance samples are real, not fixtures; package/save compatibility and exact rollback hashes hold; no-go remains enforced for any missing evidence.
- Reload Mode: `RESTART_TEARDOWN between immutable package versions; RESTART_MOD_SESSION for each multiplayer/soak scenario`
- Regression: Golden packages, S0–S8, lifecycle/Save soak, p95/p99 budget, clean-room consumers, upgrade/rollback and support/security gates.
- Evidence: Immutable artifacts/hashes, machine/hardware identity, live telemetry/screenshots/logs/replays, per-gate reports, sign-off and Harness.

## Step 11.2 — 执行多人、存档和生命周期 Soak

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG + MULTIPLAYER + CONSUMER_MOD`
- Setup: Use immutable versioned release candidates plus independent consumer Mods; include baseline/upgrade/rollback and declared S0–S8 or soak topology.
- Trigger: Run every gate from a clean install; execute live single-player and required Host/Client scenarios; repeat after upgrade and exact rollback.
- Assertions: All component gates and negative cases pass; live runtime/soak/performance samples are real, not fixtures; package/save compatibility and exact rollback hashes hold; no-go remains enforced for any missing evidence. Server/Client source, player, generation and sequence are explicit in evidence.
- Reload Mode: `RESTART_TEARDOWN between immutable package versions; RESTART_MOD_SESSION for each multiplayer/soak scenario`
- Regression: Golden packages, S0–S8, lifecycle/Save soak, p95/p99 budget, clean-room consumers, upgrade/rollback and support/security gates.
- Evidence: Immutable artifacts/hashes, machine/hardware identity, live telemetry/screenshots/logs/replays, per-gate reports, sign-off and Harness.

## Step 11.3 — 建立持续性能回归门禁

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG + MULTIPLAYER + CONSUMER_MOD`
- Setup: Use immutable versioned release candidates plus independent consumer Mods; include baseline/upgrade/rollback and declared S0–S8 or soak topology.
- Trigger: Run every gate from a clean install; execute live single-player and required Host/Client scenarios; repeat after upgrade and exact rollback.
- Assertions: All component gates and negative cases pass; live runtime/soak/performance samples are real, not fixtures; package/save compatibility and exact rollback hashes hold; no-go remains enforced for any missing evidence. Diagnostics are dormant by default, bounded when enabled and add no material disabled-path overhead.
- Reload Mode: `RESTART_TEARDOWN between immutable package versions; RESTART_MOD_SESSION for each multiplayer/soak scenario`
- Regression: Golden packages, S0–S8, lifecycle/Save soak, p95/p99 budget, clean-room consumers, upgrade/rollback and support/security gates.
- Evidence: Immutable artifacts/hashes, machine/hardware identity, live telemetry/screenshots/logs/replays, per-gate reports, sign-off and Harness.

## Step 11.4 — 执行一次真实的版本升级与回滚演练

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG + CONSUMER_MOD`
- Setup: Use immutable versioned release candidates plus independent consumer Mods; include baseline/upgrade/rollback and declared S0–S8 or soak topology.
- Trigger: Run every gate from a clean install; execute live single-player and required Host/Client scenarios; repeat after upgrade and exact rollback.
- Assertions: All component gates and negative cases pass; live runtime/soak/performance samples are real, not fixtures; package/save compatibility and exact rollback hashes hold; no-go remains enforced for any missing evidence.
- Reload Mode: `RESTART_TEARDOWN between immutable package versions; RESTART_MOD_SESSION for each multiplayer/soak scenario`
- Regression: Golden packages, S0–S8, lifecycle/Save soak, p95/p99 budget, clean-room consumers, upgrade/rollback and support/security gates.
- Evidence: Immutable artifacts/hashes, machine/hardware identity, live telemetry/screenshots/logs/replays, per-gate reports, sign-off and Harness.

## Step 11.5 — 发布物与支持边界分离

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG + CONSUMER_MOD`
- Setup: Use immutable versioned release candidates plus independent consumer Mods; include baseline/upgrade/rollback and declared S0–S8 or soak topology.
- Trigger: Run every gate from a clean install; execute live single-player and required Host/Client scenarios; repeat after upgrade and exact rollback.
- Assertions: All component gates and negative cases pass; live runtime/soak/performance samples are real, not fixtures; package/save compatibility and exact rollback hashes hold; no-go remains enforced for any missing evidence.
- Reload Mode: `RESTART_TEARDOWN between immutable package versions; RESTART_MOD_SESSION for each multiplayer/soak scenario`
- Regression: Golden packages, S0–S8, lifecycle/Save soak, p95/p99 budget, clean-room consumers, upgrade/rollback and support/security gates.
- Evidence: Immutable artifacts/hashes, machine/hardware identity, live telemetry/screenshots/logs/replays, per-gate reports, sign-off and Harness.

## Step 11.6 — 正式平台发布门槛

- Historical status: `unable`
- Audit: **READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true.**
- Test Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG + MULTIPLAYER + CONSUMER_MOD`
- Setup: Use immutable versioned release candidates plus independent consumer Mods; include baseline/upgrade/rollback and declared S0–S8 or soak topology.
- Trigger: Run every gate from a clean install; execute live single-player and required Host/Client scenarios; repeat after upgrade and exact rollback.
- Assertions: All component gates and negative cases pass; live runtime/soak/performance samples are real, not fixtures; package/save compatibility and exact rollback hashes hold; no-go remains enforced for any missing evidence.
- Reload Mode: `RESTART_TEARDOWN between immutable package versions; RESTART_MOD_SESSION for each multiplayer/soak scenario`
- Regression: Golden packages, S0–S8, lifecycle/Save soak, p95/p99 budget, clean-room consumers, upgrade/rollback and support/security gates.
- Evidence: Immutable artifacts/hashes, machine/hardware identity, live telemetry/screenshots/logs/replays, per-gate reports, sign-off and Harness.
