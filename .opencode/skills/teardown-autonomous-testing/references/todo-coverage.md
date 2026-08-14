# CM2 executable 80-Step verification report

Generated from the authoritative `TEARDOWN_SHIP_PLATFORM_TODO.json` (`cm2.todo/2`). This Markdown is a read-only view; edit the root Todo, not this file.

Total: 80

- Implementation: not_started=0; in_progress=0; finish=22; unable=58
- Verification: verified=13; needs_regression=5; pending=58; human_visual_review=4
- Automation: FULL_AUTO=43; AUTO_WITH_VISUAL_REVIEW=17; PARTIAL_AUTO=20; MANUAL_REQUIRED=0

## Profile index

- `STATIC` (80): Step 0.1, Step 0.2, Step 0.3, Step 0.4, Step 0.5, Step 1.1, Step 1.2, Step 1.3, Step 1.4, Step 1.5, Step 1.6, Step 1.7, Step 2.1, Step 2.2, Step 2.3, Step 2.4, Step 2.5, Step 2.6, Step 2.7, Step 2.8, Step 3.1, Step 3.2, Step 3.3, Step 3.4, Step 3.5, Step 3.6, Step 4.1, Step 4.2, Step 4.3, Step 4.4, Step 4.5, Step 4.6, Step 5.1, Step 5.2, Step 5.3, Step 5.4, Step 5.5, Step 5.6, Step 5.7, Step 5.8, Step 6.1, Step 6.2, Step 6.3, Step 6.4, Step 6.5, Step 6.6, Step 6.7, Step 7.1, Step 7.2, Step 7.3, Step 7.4, Step 7.5, Step 7.6, Step 7.7, Step 8.1, Step 8.2, Step 8.3, Step 8.4, Step 8.5, Step 8.6, Step 9.1, Step 9.2, Step 9.3, Step 9.4, Step 9.5, Step 9.6, Step 9.7, Step 9.8, Step 10.1, Step 10.2, Step 10.3, Step 10.4, Step 10.5, Step 10.6, Step 11.1, Step 11.2, Step 11.3, Step 11.4, Step 11.5, Step 11.6
- `FIXTURE` (75): Step 1.1, Step 1.2, Step 1.3, Step 1.4, Step 1.5, Step 1.6, Step 1.7, Step 2.1, Step 2.2, Step 2.3, Step 2.4, Step 2.5, Step 2.6, Step 2.7, Step 2.8, Step 3.1, Step 3.2, Step 3.3, Step 3.4, Step 3.5, Step 3.6, Step 4.1, Step 4.2, Step 4.3, Step 4.4, Step 4.5, Step 4.6, Step 5.1, Step 5.2, Step 5.3, Step 5.4, Step 5.5, Step 5.6, Step 5.7, Step 5.8, Step 6.1, Step 6.2, Step 6.3, Step 6.4, Step 6.5, Step 6.6, Step 6.7, Step 7.1, Step 7.2, Step 7.3, Step 7.4, Step 7.5, Step 7.6, Step 7.7, Step 8.1, Step 8.2, Step 8.3, Step 8.4, Step 8.5, Step 8.6, Step 9.1, Step 9.2, Step 9.3, Step 9.4, Step 9.5, Step 9.6, Step 9.7, Step 9.8, Step 10.1, Step 10.2, Step 10.3, Step 10.4, Step 10.5, Step 10.6, Step 11.1, Step 11.2, Step 11.3, Step 11.4, Step 11.5, Step 11.6
- `SCENE` (65): Step 0.1, Step 0.3, Step 0.4, Step 1.5, Step 1.7, Step 2.1, Step 2.2, Step 2.3, Step 2.4, Step 2.5, Step 2.6, Step 2.7, Step 2.8, Step 3.1, Step 3.2, Step 3.3, Step 3.4, Step 3.5, Step 3.6, Step 4.1, Step 4.2, Step 4.3, Step 4.4, Step 4.5, Step 4.6, Step 5.1, Step 5.2, Step 5.3, Step 5.4, Step 5.5, Step 5.6, Step 5.7, Step 5.8, Step 6.1, Step 6.2, Step 6.3, Step 6.4, Step 6.5, Step 6.6, Step 6.7, Step 7.1, Step 7.2, Step 7.3, Step 7.4, Step 7.5, Step 7.6, Step 7.7, Step 8.3, Step 8.4, Step 8.5, Step 8.6, Step 9.3, Step 9.7, Step 9.8, Step 10.2, Step 10.3, Step 10.4, Step 10.5, Step 10.6, Step 11.1, Step 11.2, Step 11.3, Step 11.4, Step 11.5, Step 11.6
- `REAL_INPUT` (31): Step 0.1, Step 0.3, Step 2.1, Step 2.5, Step 2.6, Step 2.7, Step 2.8, Step 3.2, Step 3.4, Step 4.1, Step 4.2, Step 4.3, Step 4.4, Step 4.6, Step 6.4, Step 6.7, Step 7.4, Step 7.7, Step 8.3, Step 8.4, Step 8.5, Step 8.6, Step 9.3, Step 9.8, Step 10.2, Step 10.3, Step 10.4, Step 10.6, Step 11.1, Step 11.2, Step 11.6
- `TELEMETRY` (60): Step 0.1, Step 0.3, Step 0.4, Step 1.5, Step 1.7, Step 2.1, Step 2.2, Step 2.3, Step 2.4, Step 2.5, Step 2.6, Step 2.7, Step 2.8, Step 3.1, Step 3.2, Step 3.3, Step 3.4, Step 3.5, Step 3.6, Step 4.1, Step 4.2, Step 4.3, Step 4.4, Step 4.5, Step 4.6, Step 5.1, Step 5.2, Step 5.3, Step 5.4, Step 5.5, Step 5.6, Step 5.7, Step 5.8, Step 6.1, Step 6.2, Step 6.3, Step 6.4, Step 6.5, Step 6.6, Step 6.7, Step 7.1, Step 7.2, Step 7.3, Step 7.4, Step 7.5, Step 7.6, Step 7.7, Step 9.3, Step 9.7, Step 9.8, Step 10.2, Step 10.3, Step 10.4, Step 10.6, Step 11.1, Step 11.2, Step 11.3, Step 11.4, Step 11.5, Step 11.6
- `VISUAL` (53): Step 0.1, Step 0.3, Step 2.1, Step 2.3, Step 2.4, Step 2.5, Step 2.6, Step 2.7, Step 2.8, Step 3.1, Step 3.2, Step 3.3, Step 3.4, Step 4.1, Step 4.3, Step 4.4, Step 5.3, Step 5.4, Step 5.5, Step 5.6, Step 5.7, Step 6.1, Step 6.2, Step 6.3, Step 6.4, Step 6.5, Step 6.6, Step 6.7, Step 7.1, Step 7.2, Step 7.3, Step 7.4, Step 7.5, Step 7.6, Step 7.7, Step 8.3, Step 8.4, Step 8.5, Step 8.6, Step 9.3, Step 9.7, Step 9.8, Step 10.2, Step 10.3, Step 10.4, Step 10.5, Step 10.6, Step 11.1, Step 11.2, Step 11.3, Step 11.4, Step 11.5, Step 11.6
- `LOG` (65): Step 0.1, Step 0.3, Step 0.4, Step 1.5, Step 1.7, Step 2.1, Step 2.2, Step 2.3, Step 2.4, Step 2.5, Step 2.6, Step 2.7, Step 2.8, Step 3.1, Step 3.2, Step 3.3, Step 3.4, Step 3.5, Step 3.6, Step 4.1, Step 4.2, Step 4.3, Step 4.4, Step 4.5, Step 4.6, Step 5.1, Step 5.2, Step 5.3, Step 5.4, Step 5.5, Step 5.6, Step 5.7, Step 5.8, Step 6.1, Step 6.2, Step 6.3, Step 6.4, Step 6.5, Step 6.6, Step 6.7, Step 7.1, Step 7.2, Step 7.3, Step 7.4, Step 7.5, Step 7.6, Step 7.7, Step 8.3, Step 8.4, Step 8.5, Step 8.6, Step 9.3, Step 9.7, Step 9.8, Step 10.2, Step 10.3, Step 10.4, Step 10.5, Step 10.6, Step 11.1, Step 11.2, Step 11.3, Step 11.4, Step 11.5, Step 11.6
- `MULTIPLAYER` (11): Step 4.1, Step 4.2, Step 4.3, Step 4.4, Step 4.5, Step 4.6, Step 7.4, Step 9.7, Step 11.2, Step 11.3, Step 11.6
- `CONSUMER_MOD` (18): Step 9.1, Step 9.2, Step 9.3, Step 9.5, Step 9.6, Step 9.7, Step 9.8, Step 10.2, Step 10.3, Step 10.4, Step 10.5, Step 10.6, Step 11.1, Step 11.2, Step 11.3, Step 11.4, Step 11.5, Step 11.6

## Step contracts

### Step 0.1 — 修复当前 Content 主入口

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Load the formal CM2 entry and a disposable S0/S6/S7 smoke level with telemetry enabled; preserve a pre-run log cursor.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 将 `Content Mod 2/main.lua:8-9` 的 `script/weapon/client/config_ui/...` 修正为 `script/weapon/client/interaction/config/...`；[ ] 验证 `main.xml → main.lua → weapon config UI` 闭包；[ ] 验证 `shipMain.lua` 与 `ship/common/client/bootstrap.lua` 使用同一权威路径。 Run the owning checker or fixture twice and compare deterministic output plus structured diagnostics. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `RESTART_MOD_SESSION_OR_REOPEN_LEVEL_XML` — Restart the Mod session for entry/runtime changes and reopen the level XML when scene placement changes.
- State assertions: 内容地图可载入，武器配置 UI 可初始化/打开/关闭，输入、镜头和开火不被锁死。 [ ] 完整 Harness 通过；[ ] Teardown 初始化无 include/preprocess 错误；[ ] UI 开关后飞船控制正常；[ ] 不复制旧文件制造双源。 Valid input is deterministic; invalid, missing, future, duplicate, or out-of-range input fails closed with stable field diagnostics.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Entry closure, source-of-truth, schema/compiler/catalog, and affected definition suites.
- Evidence: Contract result, fixture inputs, command trace, structured diagnostics, hashes, and full Harness output.

### Step 0.2 — 把所有真实入口纳入验证闭包

- Implementation: `finish`
- Verification: `verified` — Existing static/fixture evidence satisfies the current contract; rerun the listed regression when an adjacent authority changes.
- Automation: `FULL_AUTO`
- Profiles: `STATIC`
- Eyes: `none`
- Hands: `none`
- Setup: Use versioned valid/invalid fixtures in an isolated output directory; do not mutate the last valid generated artifact.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 枚举 `main.xml`、prefab XML 的 `<script file>`、根 `main.lua`、`shipMain.lua` 和遗留 escort 入口；[ ] 新增 include 存在性、合法范围、循环和递归闭包 checker；[ ] 为根 include 缺失、prefab script 缺失、generated catalog 缺失、循环 include 增加负面 fixture；[ ] 将 checker 接入 `check-all.ps1` 早期阶段。 Run the owning checker or fixture twice and compare deterministic output plus structured diagnostics.
- Reload: `NONE` — Static and fixture execution does not load Teardown.
- State assertions: Harness 通过代表全部启动脚本可预处理，文件移动和构建缺产物能在进游戏前失败。 [ ] 当前项目通过；[ ] 四类 fixture 都被拒绝；[ ] 错误包含入口到坏 include 的路径链；[ ] checker 自测失败会阻断完整 Harness。 Valid input is deterministic; invalid, missing, future, duplicate, or out-of-range input fails closed with stable field diagnostics.
- Telemetry: not required
- Visual: not required
- Log: not required
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority.
- Regression: Entry closure, source-of-truth, schema/compiler/catalog, and affected definition suites.
- Evidence: Contract result, fixture inputs, command trace, structured diagnostics, hashes, and full Harness output.

### Step 0.3 — 建立最小 Teardown 实机 smoke matrix

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Load the formal CM2 entry and a disposable S0/S6/S7 smoke level with telemetry enabled; preserve a pre-run log cursor.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 固定 S0、S6、S7 的地图、舰船、装配、操作、观察点、截图/日志命名；[ ] 建立 smoke 结果模板；[ ] 对齐 `docs/weapon-configuration-plan.md` 的历史状态，标记旧路径 superseded；[ ] 要求入口、生命周期、网络、表现相关 PR 引用 smoke record。 Run the owning checker or fixture twice and compare deterministic output plus structured diagnostics. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `RESTART_MOD_SESSION_OR_REOPEN_LEVEL_XML` — Restart the Mod session for entry/runtime changes and reopen the level XML when scene placement changes.
- State assertions: “实机验证过”成为可重复证据，文档、目录和功能状态一致。 [ ] S0 记录一次；[ ] S6 证明死船武器/导弹/舰载机/回调停止；[ ] S7 完成 host/remote 配置、开火和死亡流程。 Valid input is deterministic; invalid, missing, future, duplicate, or out-of-range input fails closed with stable field diagnostics.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Entry closure, source-of-truth, schema/compiler/catalog, and affected definition suites.
- Evidence: Contract result, fixture inputs, command trace, structured diagnostics, hashes, and full Harness output.

### Step 0.4 — 加入低开销诊断计数器

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + SCENE + TELEMETRY + LOG`
- Eyes: `EYE_TELEMETRY + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Use versioned valid/invalid fixtures in an isolated output directory; do not mutate the last valid generated artifact.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 在 `script/net/network_debug.lua` 旁建立 counter/profiler API；[ ] 记录 subsystem tick、QueryRaycast/ClosestPoint/Find*、Registry、presentation event、active projectile/craft/effect/voice/joint；[ ] 非诊断构建可关闭，热路径只做整数累加；[ ] 每秒输出/快照而非逐帧拼接字符串。 Run the owning checker or fixture twice and compare deterministic output plus structured diagnostics.
- Reload: `RESTART_MOD_SESSION_OR_REOPEN_LEVEL_XML` — Restart the Mod session for entry/runtime changes and reopen the level XML when scene placement changes.
- State assertions: 可定位首个瓶颈和增长曲线，可验证 96 导弹、24 craft、500 弹场景预算。 [ ] 关闭诊断的回归低于测量噪声；[ ] 开启诊断有 overhead 记录；[ ] S0–S7 不持续增长/漏清零；[ ] active entity 有 owner/type/lifecycle 计数。 Valid input is deterministic; invalid, missing, future, duplicate, or out-of-range input fails closed with stable field diagnostics.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: not required
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Entry closure, source-of-truth, schema/compiler/catalog, and affected definition suites.
- Evidence: Contract result, fixture inputs, command trace, structured diagnostics, hashes, and full Harness output.
- Automation gaps: Authoritative frame-time, GC, query, and allocation telemetry must be completed and baselined before the performance claim is fully automatic.

### Step 0.5 — 冻结架构决策与迁移账本

- Implementation: `finish`
- Verification: `verified` — Existing static/fixture evidence satisfies the current contract; rerun the listed regression when an adjacent authority changes.
- Automation: `FULL_AUTO`
- Profiles: `STATIC`
- Eyes: `none`
- Hands: `none`
- Setup: Use versioned valid/invalid fixtures in an isolated output directory; do not mutate the last valid generated artifact.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 建立脚本 context、Definition source/build、坐标、world owner、extension packaging、性能预算 ADR；[ ] 登记旧 profile registry、具名 ClientCall、slot 状态机、Global Mod 副本、根 Body mount API；[ ] 声明 Content 为源码、Global 为生成目标；[ ] 记录功能冻结/解冻 Gate。 Run the owning checker or fixture twice and compare deterministic output plus structured diagnostics.
- Reload: `NONE` — Static and fixture execution does not load Teardown.
- State assertions: 每个兼容层都有存在理由、删除条件和 owner；文档和文件布局不会再次分叉。 [ ] ADR 有编号和评审记录；[ ] ledger 覆盖已知旧路径；[ ] source of truth 写入构建检查；[ ] Gate 冻结/解冻规则可执行。 Valid input is deterministic; invalid, missing, future, duplicate, or out-of-range input fails closed with stable field diagnostics.
- Telemetry: not required
- Visual: not required
- Log: not required
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority.
- Regression: Entry closure, source-of-truth, schema/compiler/catalog, and affected definition suites.
- Evidence: Contract result, fixture inputs, command trace, structured diagnostics, hashes, and full Harness output.

### Step 1.1 — 冻结 ID、版本和坐标基础合同

- Implementation: `finish`
- Verification: `verified` — Existing static/fixture evidence satisfies the current contract; rerun the listed regression when an adjacent authority changes.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE`
- Eyes: `none`
- Hands: `HAND_TEST_SETUP`
- Setup: Use versioned valid/invalid fixtures in an isolated output directory; do not mutate the last valid generated artifact.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 采用 `packageId:local-id` namespaced ID，定义大小写/字符集/alias/重复策略；[ ] 定义按 kind 的 `schemaVersion`；[ ] 固定 canonical frame `+X right, +Y up, -Z forward`、meter；[ ] 持久化只允许 `parentId + localTransform`；[ ] 作者态 Euler 转编译态 quaternion；[ ] 定义 unknown/deprecated/missing-reference/version-mismatch 等级。 Run the owning checker or fixture twice and compare deterministic output plus structured diagnostics.
- Reload: `NONE` — Static and fixture execution does not load Teardown.
- State assertions: schema、gizmo、AI、anchor 使用同一 ID/空间规则，异常方向在导入时转换或拒绝。 [ ] ADR 与最小示例；[ ] 跨机器 normalized ID/transform byte 一致；[ ] root/shape/parent/mirror mount golden cases。 Valid input is deterministic; invalid, missing, future, duplicate, or out-of-range input fails closed with stable field diagnostics.
- Telemetry: not required
- Visual: not required
- Log: not required
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority.
- Regression: Entry closure, source-of-truth, schema/compiler/catalog, and affected definition suites.
- Evidence: Contract result, fixture inputs, command trace, structured diagnostics, hashes, and full Harness output.

### Step 1.2 — 定义 Source Envelope 与六类核心 Schema v1

- Implementation: `finish`
- Verification: `verified` — Existing static/fixture evidence satisfies the current contract; rerun the listed regression when an adjacent authority changes.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE`
- Eyes: `none`
- Hands: `HAND_TEST_SETUP`
- Setup: Use versioned valid/invalid fixtures in an isolated output directory; do not mutate the last valid generated artifact.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 建立 `schemaVersion/id/kind/runtime/editor/ai/build` envelope；[ ] 定义 Weapon、Projectile、Effect、Vehicle、Mount、Turret；[ ] 补充 Part、Anchor、Damage、Sound、TargetFilter、Flight、Component；[ ] 为字段定义类型、单位、范围、默认、Runtime 必需性、引用 kind、预算影响；[ ] 错误包含 id、field path、expected、actual、suggestion。 Run the owning checker or fixture twice and compare deterministic output plus structured diagnostics.
- Reload: `NONE` — Static and fixture execution does not load Teardown.
- State assertions: Runtime metadata 与 Editor/AI/Build metadata 分离，当前简单射线、弹道、制导、战巡和 Titan 可表达。 [ ] 每类有 valid/missing/wrong-type/out-of-range/broken-reference/future-version fixture；[ ] Schema v1 不要求一次覆盖所有复杂效果。 Valid input is deterministic; invalid, missing, future, duplicate, or out-of-range input fails closed with stable field diagnostics.
- Telemetry: not required
- Visual: not required
- Log: not required
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority.
- Regression: Entry closure, source-of-truth, schema/compiler/catalog, and affected definition suites.
- Evidence: Contract result, fixture inputs, command trace, structured diagnostics, hashes, and full Harness output.

### Step 1.3 — 实现确定性 Definition Compiler MVP

- Implementation: `finish`
- Verification: `verified` — Existing static/fixture evidence satisfies the current contract; rerun the listed regression when an adjacent authority changes.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE`
- Eyes: `none`
- Hands: `HAND_TEST_SETUP`
- Setup: Use versioned valid/invalid fixtures in an isolated output directory; do not mutate the last valid generated artifact.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 读取 authoring source，执行 validation、migration、defaulting、ID/reference resolution、资源存在性和预算 lint；[ ] 输出稳定排序、无动态默认的 Lua catalog、manifest/hash；[ ] 输出人类可读与机器可读诊断；[ ] 相同输入 byte-for-byte 输出相同；[ ] generated 文件加禁止手工编辑 header；[ ] 临时输出成功后原子替换，失败不得覆盖上次产物。 Run the owning checker or fixture twice and compare deterministic output plus structured diagnostics.
- Reload: `NONE` — Static and fixture execution does not load Teardown.
- State assertions: Teardown 继续消费静态 catalog，第三方包也能使用同一 compiler。 [ ] 确定性构建测试；[ ] 坏引用/重复 ID/超版本/资源缺失在进游戏前失败；[ ] Runtime catalog 不含 editor/ai provenance 大字段。 Valid input is deterministic; invalid, missing, future, duplicate, or out-of-range input fails closed with stable field diagnostics.
- Telemetry: not required
- Visual: not required
- Log: not required
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority.
- Regression: Entry closure, source-of-truth, schema/compiler/catalog, and affected definition suites.
- Evidence: Contract result, fixture inputs, command trace, structured diagnostics, hashes, and full Harness output.

### Step 1.4 — 建立现有定义的语义清单和 Golden Snapshot

- Implementation: `finish`
- Verification: `verified` — Existing static/fixture evidence satisfies the current contract; rerun the listed regression when an adjacent authority changes.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE`
- Eyes: `none`
- Hands: `HAND_TEST_SETUP`
- Setup: Use versioned valid/invalid fixtures in an isolated output directory; do not mutate the last valid generated artifact.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 输出 109 个 Weapon 的 ID、slot、behavior、伤害、冷却、射程、Projectile/FX/Sound；[ ] 输出 5 个 Vehicle 的 HP、飞行、component、configuration、mount 和 normalized transform；[ ] 记录 mount resolve、numbered group、legacy alias、默认 loadout 派生；[ ] 记录非单位方向、magic offset、fallback 和隐式默认；[ ] 稳定排序并 hash。 Run the owning checker or fixture twice and compare deterministic output plus structured diagnostics.
- Reload: `NONE` — Static and fixture execution does not load Teardown.
- State assertions: 109/5 的差异可自动显示，奇怪但兼容的值被显式记录。 [ ] 109/109 Weapon、5/5 Vehicle 成功；[ ] 重复生成 byte 一致；[ ] diff 指向具体 ID/字段。 Valid input is deterministic; invalid, missing, future, duplicate, or out-of-range input fails closed with stable field diagnostics.
- Telemetry: not required
- Visual: not required
- Log: not required
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority.
- Regression: Entry closure, source-of-truth, schema/compiler/catalog, and affected definition suites.
- Evidence: Contract result, fixture inputs, command trace, structured diagnostics, hashes, and full Harness output.

### Step 1.5 — 用四个纵切片验证 Compiler

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + LOG`
- Eyes: `EYE_TELEMETRY + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Use versioned valid/invalid fixtures in an isolated output directory; do not mutate the last valid generated artifact.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 选择默认 ray/beam；[ ] 默认 logical projectile + impact；[ ] guided missile；[ ] tachyon 或 perdition 复杂 charge/beam/impact；[ ] 每条建立 Weapon/Projectile/Effect source、candidate catalog；[ ] 其余内容继续 legacy；[ ] 同 ID 的 generated/legacy ownership 必须显式决定。 Run the owning checker or fixture twice and compare deterministic output plus structured diagnostics.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for Lua and reopen the level XML for generated catalog placement changes.
- State assertions: Compiler 在真实内容上闭环，为 EffectPlayer 提供四个明确目标。 [ ] 四条 normalized definition 与当前语义一致；[ ] source 修改不手改 generated；[ ] 每条可独立回切 legacy；[ ] load time/memory 有基线。 Valid input is deterministic; invalid, missing, future, duplicate, or out-of-range input fails closed with stable field diagnostics.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: not required
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Entry closure, source-of-truth, schema/compiler/catalog, and affected definition suites.
- Evidence: Contract result, fixture inputs, command trace, structured diagnostics, hashes, and full Harness output.

### Step 1.6 — 冻结 Identity DTO 与 `WeaponPresentationEvent v1`

- Implementation: `finish`
- Verification: `verified` — Existing static/fixture evidence satisfies the current contract; rerun the listed regression when an adjacent authority changes.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE`
- Eyes: `none`
- Hands: `HAND_TEST_SETUP`
- Setup: Use versioned valid/invalid fixtures in an isolated output directory; do not mutate the last valid generated artifact.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 定义 DefinitionRef、EntityRef、AnchorRef、EffectInstanceRef；[ ] 定义 protocolVersion、sequence、source、weapon/effect、anchor/transform、target/hit、seed、priority、serverTime、payload；[ ] v1 覆盖 charge/muzzle/beam/projectile/impact/sound/shake/craft launch/recover；[ ] 禁止 callback、函数名、共享 table、未声明 engine handle；[ ] 实现 encode/decode/validate fixture，暂不替换旧网络路径。 Run the owning checker or fixture twice and compare deterministic output plus structured diagnostics.
- Reload: `NONE` — Static and fixture execution does not load Teardown.
- State assertions: Weapon behavior 与 renderer 解耦，后续 transport 有协议边界。 [ ] encode/decode 语义一致；[ ] stale generation、重复 sequence、未知必需版本拒绝；[ ] 未知可选字段按版本跳过。 Valid input is deterministic; invalid, missing, future, duplicate, or out-of-range input fails closed with stable field diagnostics.
- Telemetry: not required
- Visual: not required
- Log: not required
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority.
- Regression: Entry closure, source-of-truth, schema/compiler/catalog, and affected definition suites.
- Evidence: Contract result, fixture inputs, command trace, structured diagnostics, hashes, and full Harness output.

### Step 1.7 — 建立候选 Catalog 的 Shadow 模式

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + LOG`
- Eyes: `EYE_TELEMETRY + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Use versioned valid/invalid fixtures in an isolated output directory; do not mutate the last valid generated artifact.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 同时加载 legacy snapshot 与四条 candidate；[ ] 对 normalized fields、effect/projectile refs、mount/fire transform 做 shadow comparison；[ ] 差异写入诊断并阻止该纵切启用；[ ] feature switch 只在 init 解析 `legacy|candidate-v1`；[ ] generated catalog init 后冻结，禁止运行中覆盖。 Run the owning checker or fixture twice and compare deterministic output plus structured diagnostics.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for Lua and reopen the level XML for generated catalog placement changes.
- State assertions: 四条纵切可安全进入下一阶段，其余 105 个武器不受影响。 [ ] 差异在切换前可见；[ ] 四条纵切可独立开关；[ ] runtime 注册覆盖被拒绝；[ ] shadow 不进入热循环。 Valid input is deterministic; invalid, missing, future, duplicate, or out-of-range input fails closed with stable field diagnostics.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: not required
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Entry closure, source-of-truth, schema/compiler/catalog, and affected definition suites.
- Evidence: Contract result, fixture inputs, command trace, structured diagnostics, hashes, and full Harness output.

### Step 2.1 — 增加 Presentation Publisher 与 Legacy Adapter

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `AUTO_WITH_VISUAL_REVIEW`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Build a legacy/candidate pair and a deterministic two-ship scene containing only the affected definitions and presentation paths.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 新增服务端 `PresentationPublisher.publish(event)`；[ ] legacy 模式转回现有具名 ClientCall；[ ] event-v1 模式发送 DTO；[ ] 接入 ray、logical projectile、guided、strike craft、charged weapon 的真实发射/结束入口；[ ] 记录 sequence/publish/adapter count。 Run parity first, reload the scene, then issue only the minimum real fire or preview input required by the behavior. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for Lua and reopen the level XML for catalog/entity placement changes.
- State assertions: 行为只表达 charge/muzzle/beam/projectile/impact 事实，旧视觉仍可按 effect/weapon 回退。 [ ] legacy trace 与改造前一致；[ ] Publisher 不引用具体 renderer/function name；[ ] 单个 ID 可选择 legacy/event-v1。 Compiled identity and legacy semantic golden match or have an approved diff; no legacy/candidate double authority appears.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Four vertical slices, the 109-weapon snapshot, presentation sequence/generation guards, and legacy fallback.
- Evidence: Compiler/parity reports, telemetry chain, budget counters, screenshots, incremental log, and Harness.
- Automation gaps: AI owns objective visibility, count, clipping, alignment, and budget checks; subjective visual quality remains a human review.

### Step 2.2 — 建立固定容量、可观测的 Presentation Event Ring

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + LOG`
- Eyes: `EYE_TELEMETRY + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Build a legacy/candidate pair and a deterministic two-ship scene containing only the affected definitions and presentation paths.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 固定容量 ring，禁止无界 append；[ ] 区分 Critical（spawn/finish/impact/charge-stop）和 Ambient（trail/update）；[ ] Critical 不被 Ambient 覆盖，Ambient 可按 source/effect 合并；[ ] source+sequence 去重并统计 gap/duplicate/out-of-order/drop；[ ] owner dispose 清理未完成事件并发出 finish/cancel。 Run parity first, reload the scene, then issue only the minimum real fire or preview input required by the behavior.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for Lua and reopen the level XML for catalog/entity placement changes.
- State assertions: burst、延迟和压力行为有界且可诊断。 [ ] 100 个同帧 critical 全部恰好消费一次；[ ] 重复/乱序/缺口/满队列 fixture 符合策略；[ ] 满队列内存不增长且 Critical drop=0。 Compiled identity and legacy semantic golden match or have an approved diff; no legacy/candidate double authority appears.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: not required
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Four vertical slices, the 109-weapon snapshot, presentation sequence/generation guards, and legacy fallback.
- Evidence: Compiler/parity reports, telemetry chain, budget counters, screenshots, incremental log, and Harness.

### Step 2.3 — 实现 `EffectPlayer` 和固定容量实例存储

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `AUTO_WITH_VISUAL_REVIEW`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Build a legacy/candidate pair and a deterministic two-ship scene containing only the affected definitions and presentation paths.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 固定 API `play/update/stop/destroy`；[ ] generation handle + dense store/free-list；[ ] Instance 包含 effect、owner、anchor、clock、seed、LOD、priority、renderer state；[ ] lifecycle 幂等，owner/anchor 失效有策略；[ ] 复用资源 cache；[ ] renderer 保留专用热循环，不为每个粒子创建通用 ECS entity。 Run parity first, reload the scene, then issue only the minimum real fire or preview input required by the behavior.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for Lua and reopen the level XML for catalog/entity placement changes.
- State assertions: 所有效果共享 owner/时钟/终止条件，synthetic context 可独立播放。 [ ] 覆盖 play/update/fade/stop/destroy/owner-lost/scene-reload；[ ] `active + free = capacity`；[ ] 10 分钟 synthetic loop 进入内存平台期。 Compiled identity and legacy semantic golden match or have an approved diff; no legacy/candidate double authority appears.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Four vertical slices, the 109-weapon snapshot, presentation sequence/generation guards, and legacy fallback.
- Evidence: Compiler/parity reports, telemetry chain, budget counters, screenshots, incremental log, and Harness.
- Automation gaps: AI owns objective visibility, count, clipping, alignment, and budget checks; subjective visual quality remains a human review.

### Step 2.4 — 收口 Particle、Light、Sprite、Line、Audio 与 Shake 预算

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `AUTO_WITH_VISUAL_REVIEW`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Build a legacy/candidate pair and a deterministic two-ship scene containing only the affected definitions and presentation paths.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 每客户端每帧只允许一个 budget begin/reset owner；[ ] 为 Particle/PointLight/Sprite/Line/Audio voice/Camera Shake 建唯一 facade；[ ] 记录 effect/package/owner/priority/distance 与 accepted/degraded/rejected；[ ] 静态检查禁止 facade 白名单外直调底层表现 API；[ ] 优先接入死亡、guided/craft、tachyon/perdition；[ ] 超限只改变表现，不改变伤害、命中和生命周期。 Run parity first, reload the scene, then issue only the minimum real fire or preview input required by the behavior.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for Lua and reopen the level XML for catalog/entity placement changes.
- State assertions: 每个昂贵效果都有可解释的预算结果，S5 hard cap 可执行。 [ ] 每帧 begin 恰好一次；[ ] 计数与真实 API 调用一致；[ ] S5 三舰死亡不突破 hard cap；[ ] direct-call 负面 fixture 失败。 Compiled identity and legacy semantic golden match or have an approved diff; no legacy/candidate double authority appears.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Four vertical slices, the 109-weapon snapshot, presentation sequence/generation guards, and legacy fallback.
- Evidence: Compiler/parity reports, telemetry chain, budget counters, screenshots, incremental log, and Harness.
- Automation gaps: AI owns objective visibility, count, clipping, alignment, and budget checks; subjective visual quality remains a human review.

### Step 2.5 — 迁移四条代表性纵切片

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Build a legacy/candidate pair and a deterministic two-ship scene containing only the affected definitions and presentation paths.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 默认 ray beam；[ ] logical projectile + muzzle/trail/impact；[ ] guided missile spawn/correct/finish + loop/trail/impact；[ ] tachyon/perdition charge/beam/impact；[ ] 为每条保留 legacy/event-v1 对照与 shadow diff。 Run parity first, reload the scene, then issue only the minimum real fire or preview input required by the behavior. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for Lua and reopen the level XML for catalog/entity placement changes.
- State assertions: 四条纵切在新 Runtime 中行为、表现、预算和回退一致。 [ ] 发射、命中、结束、死亡、owner cleanup 全部通过；[ ] S0/S2/S5 记录 before/after；[ ] 任一条可单独回退。 Compiled identity and legacy semantic golden match or have an approved diff; no legacy/candidate double authority appears.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Four vertical slices, the 109-weapon snapshot, presentation sequence/generation guards, and legacy fallback.
- Evidence: Compiler/parity reports, telemetry chain, budget counters, screenshots, incremental log, and Harness.

### Step 2.6 — 迁移剩余武器表现、音频、舰载机与舰船效果

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `AUTO_WITH_VISUAL_REVIEW`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Build a legacy/candidate pair and a deterministic two-ship scene containing only the affected definitions and presentation paths.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 按四类纵切的模式迁移其余武器；[ ] 迁移音频、舰载机 launch/recover、舰船死亡/损伤/环境表现；[ ] 为每批次生成 event trace、budget report 和 semantic snapshot；[ ] 不改服务端伤害算法；[ ] 清理没有 owner 的 legacy effect。 Run parity first, reload the scene, then issue only the minimum real fire or preview input required by the behavior. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for Lua and reopen the level XML for catalog/entity placement changes.
- State assertions: 全部内容可由中性事件驱动，视觉与音频统一受预算和生命周期管理。 [ ] 逐批次 100% 通过对应 Harness；[ ] S0–S6 无行为回归；[ ] active effect/voice 在死亡后归零或有明确跨场景策略。 Compiled identity and legacy semantic golden match or have an approved diff; no legacy/candidate double authority appears.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. The real path reaches the applicable ordered boundaries: input_edge/fire_request → weapon_released → hit → damage_applied → hp_changed; omitted boundaries require a weapon-specific explanation.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant. Muzzle/beam/projectile/impact appears once at the authoritative anchor and target without obvious clipping or duplicate legacy playback.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Four vertical slices, the 109-weapon snapshot, presentation sequence/generation guards, and legacy fallback.
- Evidence: Compiler/parity reports, telemetry chain, budget counters, screenshots, incremental log, and Harness.
- Automation gaps: AI owns objective visibility, count, clipping, alignment, and budget checks; subjective visual quality remains a human review.

### Step 2.7 — 建立 Creator Preview 的 Effect Lab MVP

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `AUTO_WITH_VISUAL_REVIEW`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Build a legacy/candidate pair and a deterministic two-ship scene containing only the affected definitions and presentation paths.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 使用 synthetic context 播放 EffectDefinition；[ ] 支持固定 seed、near/far、LOD、预算 accepted/degraded/rejected；[ ] 展示事件时间线、owner 和资源引用；[ ] Preview 与 Runtime 使用同一 EffectPlayer/Compiler；[ ] 不引入第二套 renderer 语义。 Run parity first, reload the scene, then issue only the minimum real fire or preview input required by the behavior. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for Lua and reopen the level XML for catalog/entity placement changes.
- State assertions: Effect 可在低成本环境中预览、比较和回放。 [ ] 同 seed 可重复；[ ] Preview/Runtime 快照一致；[ ] 超预算可解释；[ ] 不依赖真实 ship registry 或伤害系统。 Compiled identity and legacy semantic golden match or have an approved diff; no legacy/candidate double authority appears.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant. The generated asset/editor surface opens through the real UI path and shows the expected orientation, scale, anchors, controls, and diagnostics.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Four vertical slices, the 109-weapon snapshot, presentation sequence/generation guards, and legacy fallback.
- Evidence: Compiler/parity reports, telemetry chain, budget counters, screenshots, incremental log, and Harness.
- Automation gaps: AI owns objective visibility, count, clipping, alignment, and budget checks; subjective visual quality remains a human review.

### Step 2.8 — 切换 Effect Runtime 权威并删除第一批旧路径

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `AUTO_WITH_VISUAL_REVIEW`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Build a legacy/candidate pair and a deterministic two-ship scene containing only the affected definitions and presentation paths.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 选定迁移完成的 effect/profile ownership；[ ] 默认走 EffectPlayer；[ ] 旧路径只保留有账本条目的兼容 adapter；[ ] 删除第一批重复 renderer、slot 私有数组和未使用 ClientCall；[ ] 更新迁移账本、目录边界和文档。 Run parity first, reload the scene, then issue only the minimum real fire or preview input required by the behavior. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for Lua and reopen the level XML for catalog/entity placement changes.
- State assertions: Effect Runtime 成为已迁移内容的单一权威，旧路径开始真实收缩。 [ ] legacy 只在显式开关下可用；[ ] 删除项无引用；[ ] S0–S7 和完整 Harness 通过；[ ] 有可执行回退开关。 Compiled identity and legacy semantic golden match or have an approved diff; no legacy/candidate double authority appears.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Four vertical slices, the 109-weapon snapshot, presentation sequence/generation guards, and legacy fallback.
- Evidence: Compiler/parity reports, telemetry chain, budget counters, screenshots, incremental log, and Harness.
- Automation gaps: AI owns objective visibility, count, clipping, alignment, and budget checks; subjective visual quality remains a human review.

### Step 3.1 — 将全部现有 Effect Profile 转为版本化来源

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `AUTO_WITH_VISUAL_REVIEW`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Build a legacy/candidate pair and a deterministic two-ship scene containing only the affected definitions and presentation paths.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 为每个现有 profile 建版本化 source；[ ] 显式迁移默认值、别名、资源引用、budget、LOD、owner/终止条件；[ ] 生成 normalized snapshot 并与 legacy 对比；[ ] 记录无法一比一表达的差异和人工批准。 Run parity first, reload the scene, then issue only the minimum real fire or preview input required by the behavior.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for Lua and reopen the level XML for catalog/entity placement changes.
- State assertions: 所有效果都有可审计、可编译、可预览的版本化来源。 [ ] 全部 profile 有 source ID/schemaVersion；[ ] snapshot 差异清零或有 ADR；[ ] 缺资源/超预算构建失败；[ ] 旧 profile registry 进入删除清单。 Compiled identity and legacy semantic golden match or have an approved diff; no legacy/candidate double authority appears.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Four vertical slices, the 109-weapon snapshot, presentation sequence/generation guards, and legacy fallback.
- Evidence: Compiler/parity reports, telemetry chain, budget counters, screenshots, incremental log, and Harness.
- Automation gaps: AI owns objective visibility, count, clipping, alignment, and budget checks; subjective visual quality remains a human review.

### Step 3.2 — 迁移 109 个 Weapon 与 Projectile

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Build a legacy/candidate pair and a deterministic two-ship scene containing only the affected definitions and presentation paths.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 按 snapshot 批次迁移全部 109 Weapon；[ ] 为每个 Projectile 建版本化定义；[ ] 保留 slot/loadout、fire transform、damage、cooldown、range、behavior、FX/Sound 引用；[ ] 每批运行 Compiler、shadow、Harness 和 S0–S5；[ ] 失败批次不得覆盖已通过 catalog。 Run parity first, reload the scene, then issue only the minimum real fire or preview input required by the behavior. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for Lua and reopen the level XML for catalog/entity placement changes.
- State assertions: 109/109 Weapon 和对应 Projectile 由 Generated Catalog 提供，语义变化可追踪。 [ ] 109/109 通过语义 snapshot；[ ] 所有引用解析成功；[ ] 随机/边界武器回放一致；[ ] 每批可回滚到上一个有效 catalog。 Compiled identity and legacy semantic golden match or have an approved diff; no legacy/candidate double authority appears.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. The real path reaches the applicable ordered boundaries: input_edge/fire_request → weapon_released → hit → damage_applied → hp_changed; omitted boundaries require a weapon-specific explanation.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant. Muzzle/beam/projectile/impact appears once at the authoritative anchor and target without obvious clipping or duplicate legacy playback.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Four vertical slices, the 109-weapon snapshot, presentation sequence/generation guards, and legacy fallback.
- Evidence: Compiler/parity reports, telemetry chain, budget counters, screenshots, incremental log, and Harness.

### Step 3.3 — 迁移 Vehicle、Mount、Component 和 AI Interceptor 定义

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Build a legacy/candidate pair and a deterministic two-ship scene containing only the affected definitions and presentation paths.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 迁移 Vehicle、Mount、Component、AI Interceptor source；[ ] 显式保存 HP、飞行、part/component、anchor、mount、target filter、flight 和 interceptor budget；[ ] 统一根/局部 transform；[ ] 运行 5/5 Vehicle snapshot 与 S1–S4 对照。 Run parity first, reload the scene, then issue only the minimum real fire or preview input required by the behavior.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for Lua and reopen the level XML for catalog/entity placement changes.
- State assertions: 舰船和拦截器定义与武器使用同一 source/compiler/catalog 生命周期。 [ ] 5/5 Vehicle 及所有 mount/component 引用通过；[ ] AI Interceptor 参数可回放；[ ] 坐标 golden 无未记录差异。 Compiled identity and legacy semantic golden match or have an approved diff; no legacy/candidate double authority appears.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. The real path reaches the applicable ordered boundaries: input_edge/fire_request → weapon_released → hit → damage_applied → hp_changed; omitted boundaries require a weapon-specific explanation. Registration and lifecycle reach a terminal ship_destroyed → ship_unregistered → ship_cleanup or the task's documented equivalent exactly once.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Four vertical slices, the 109-weapon snapshot, presentation sequence/generation guards, and legacy fallback.
- Evidence: Compiler/parity reports, telemetry chain, budget counters, screenshots, incremental log, and Harness.

### Step 3.4 — 建立版本化 Loadout/Configuration 合同

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Build a legacy/candidate pair and a deterministic two-ship scene containing only the affected definitions and presentation paths.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 定义 Loadout/Configuration schema、revision、slot、mount group、alias、默认值和缺失策略；[ ] 让 UI、Runtime、Compiler、存档使用同一 DTO；[ ] 为旧 configuration alias 提供一次性迁移；[ ] 禁止运行时随意注册/覆盖。 Run parity first, reload the scene, then issue only the minimum real fire or preview input required by the behavior. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for Lua and reopen the level XML for catalog/entity placement changes.
- State assertions: 配置可版本化、可迁移、可验证，UI 与 Runtime 不再各自解释字段。 [ ] 新旧 revision migration 幂等；[ ] 缺 weapon/mount 有清晰降级；[ ] 存档 golden 与运行时选择一致；[ ] schema 错误可定位 field path。 Compiled identity and legacy semantic golden match or have an approved diff; no legacy/candidate double authority appears.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Four vertical slices, the 109-weapon snapshot, presentation sequence/generation guards, and legacy fallback.
- Evidence: Compiler/parity reports, telemetry chain, budget counters, screenshots, incremental log, and Harness.

### Step 3.5 — 迁移 Harness 合同并切换 Generated Catalog

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + LOG`
- Eyes: `EYE_TELEMETRY + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Build a legacy/candidate pair and a deterministic two-ship scene containing only the affected definitions and presentation paths.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 让 Harness 从 schema/source/generated catalog 验证，而不是依赖旧 registry 细节；[ ] 增加 generated header/hash、manifest、所有入口闭包和引用完整性检查；[ ] 先在 shadow/双读模式比较，再切换默认；[ ] 记录 build output hash。 Run parity first, reload the scene, then issue only the minimum real fire or preview input required by the behavior.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for Lua and reopen the level XML for catalog/entity placement changes.
- State assertions: Harness、Compiler、Runtime 消费同一份 Generated Catalog，构建结果可追溯。 [ ] 完整 Harness 与所有负面 fixture 通过；[ ] catalog hash、入口和 manifest 一致；[ ] generated 缺失/过期会在早期失败。 Compiled identity and legacy semantic golden match or have an approved diff; no legacy/candidate double authority appears.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: not required
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Four vertical slices, the 109-weapon snapshot, presentation sequence/generation guards, and legacy fallback.
- Evidence: Compiler/parity reports, telemetry chain, budget counters, screenshots, incremental log, and Harness.

### Step 3.6 — 冻结 Catalog 并移除 Runtime Legacy Definition 权威

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + LOG`
- Eyes: `EYE_TELEMETRY + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Build a legacy/candidate pair and a deterministic two-ship scene containing only the affected definitions and presentation paths.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 初始化时加载并冻结 Generated Catalog；[ ] 删除运行中 definition register/override；[ ] 删除已无引用的 profile registry、旧 aliases 和双源副本；[ ] 保留仅有期限的只读迁移工具；[ ] 更新 ADR、目录边界和发布说明。 Run parity first, reload the scene, then issue only the minimum real fire or preview input required by the behavior.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for Lua and reopen the level XML for catalog/entity placement changes.
- State assertions: Definition/Catalog 单一事实来源，旧路径只在明确迁移工具中存在。 [ ] runtime 无 legacy definition authority；[ ] catalog immutable 检查通过；[ ] 全量 S0–S8/完整 Harness 通过；[ ] 删除项有引用扫描和回退标签。 Compiled identity and legacy semantic golden match or have an approved diff; no legacy/candidate double authority appears.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: not required
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Four vertical slices, the 109-weapon snapshot, presentation sequence/generation guards, and legacy fallback.
- Evidence: Compiler/parity reports, telemetry chain, budget counters, screenshots, incremental log, and Harness.

### Step 4.1 — 先做“两船、两 Context、一个 Host”技术 Spike

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG + MULTIPLAYER`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Use two pre-placed ships in two contexts with one identified Host and at least one Client; freeze owner, capability, generation, and command sequence.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 建立两个 ship instance、server/client 或两个模拟 context；[ ] 一个 host 负责 tick/registry/事件分发；[ ] 验证跨 context 只传 DTO，不共享函数/engine handle；[ ] 记录时序、错误、owner 和性能。 Start official local multiplayer; send one minimal real command from the owner and one invalid or non-owner command. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `RESTART_MOD_SESSION` — Terminate and relaunch every teardown_modtest Host/Client instance after multiplayer runtime changes.
- State assertions: 得到可运行的最小 Host 拓扑、边界和失败模式。 [ ] 两船可独立开火/死亡；[ ] host 可观察并隔离 owner；[ ] context 断开有可预测清理；[ ] Spike 结论写入 ADR。 Only Host authority mutates world state; rejected commands stay inert; Host and Client converge without duplicate effects, damage, or stale resurrection.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Host/Client source, player, owner, generation, and sequence are explicit and converge without duplicate authority mutation.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events. Terminate every test Host/Client child instance and re-enumerate processes to prove no multiplayer process remains.
- Regression: Single-player authority, presentation order, registry lifecycle, reconnect, and late join where claimed.
- Evidence: Per-window PID/HWND, Host/Client action and event traces, screenshots, logs, cleanup counts, and Harness.
- Automation gaps: Harness can enumerate Host/Client and control Host, but Client foreground input, screenshot, and per-client telemetry are not yet reliable.

### Step 4.2 — 定义 World Protocol、Owner Lease 和 Capability

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + LOG + MULTIPLAYER`
- Eyes: `EYE_TELEMETRY + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Use two pre-placed ships in two contexts with one identified Host and at least one Client; freeze owner, capability, generation, and command sequence.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 定义 world identity、protocolVersion、owner lease、generation、权限 capability 和过期策略；[ ] 区分 server authority、client presentation、preview/synthetic；[ ] 拒绝 stale owner、越权写和未知必需版本；[ ] 为 join/leave/reconnect 定义握手。 Start official local multiplayer; send one minimal real command from the owner and one invalid or non-owner command. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `RESTART_MOD_SESSION` — Terminate and relaunch every teardown_modtest Host/Client instance after multiplayer runtime changes.
- State assertions: 所有 world 操作都有可验证的身份、生命周期和权限。 [ ] 协议 fixture 覆盖 stale/duplicate/expired/unknown version；[ ] 权限错误可诊断；[ ] lease 过期不会泄漏实体/效果。 Only Host authority mutates world state; rejected commands stay inert; Host and Client converge without duplicate effects, damage, or stale resurrection.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Host/Client source, player, owner, generation, and sequence are explicit and converge without duplicate authority mutation.
- Visual: not required
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events. Terminate every test Host/Client child instance and re-enumerate processes to prove no multiplayer process remains.
- Regression: Single-player authority, presentation order, registry lifecycle, reconnect, and late join where claimed.
- Evidence: Per-window PID/HWND, Host/Client action and event traces, screenshots, logs, cleanup counts, and Harness.
- Automation gaps: Harness can enumerate Host/Client and control Host, but Client foreground input, screenshot, and per-client telemetry are not yet reliable.

### Step 4.3 — 建立 World Host Skeleton 与 Ship Instance Adapter

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG + MULTIPLAYER`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Use two pre-placed ships in two contexts with one identified Host and at least one Client; freeze owner, capability, generation, and command sequence.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 建立 host 生命周期、tick/postTick、registry、event dispatch；[ ] 用 Ship Instance Adapter 包装已有舰船入口；[ ] 旧 shipMain 通过 adapter 接入，不直接持有全局 host 状态；[ ] 提供 synthetic/preview adapter。 Start official local multiplayer; send one minimal real command from the owner and one invalid or non-owner command. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `RESTART_MOD_SESSION` — Terminate and relaunch every teardown_modtest Host/Client instance after multiplayer runtime changes.
- State assertions: 真实船、Preview 和测试 fixture 使用同一 host 抽象。 [ ] S0/S6 可在 host 下运行；[ ] adapter dispose 幂等；[ ] 不新增第二个全局 registry；[ ] old/new trace 可对照。 Only Host authority mutates world state; rejected commands stay inert; Host and Client converge without duplicate effects, damage, or stale resurrection.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Host/Client source, player, owner, generation, and sequence are explicit and converge without duplicate authority mutation.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events. Terminate every test Host/Client child instance and re-enumerate processes to prove no multiplayer process remains.
- Regression: Single-player authority, presentation order, registry lifecycle, reconnect, and late join where claimed.
- Evidence: Per-window PID/HWND, Host/Client action and event traces, screenshots, logs, cleanup counts, and Harness.
- Automation gaps: Harness can enumerate Host/Client and control Host, but Client foreground input, screenshot, and per-client telemetry are not yet reliable.

### Step 4.4 — 把 Presentation 与 Audio Ownership 移到 Host

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG + MULTIPLAYER`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Use two pre-placed ships in two contexts with one identified Host and at least one Client; freeze owner, capability, generation, and command sequence.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] Host 统一接收 PresentationEvent 和 Audio request；[ ] owner/scene/priority/距离预算由 host 统一裁决；[ ] client renderer 只消费批准事件；[ ] 舰船销毁、场景切换、远近 LOD 触发统一 stop/fade。 Start official local multiplayer; send one minimal real command from the owner and one invalid or non-owner command. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `RESTART_MOD_SESSION` — Terminate and relaunch every teardown_modtest Host/Client instance after multiplayer runtime changes.
- State assertions: 场景级表现、音频和 cleanup 都可观测、可限额。 [ ] S5 不突破 hard cap；[ ] S6 owner cleanup 归零；[ ] duplicate event/voice 有计数；[ ] Host/renderer 边界无底层 API 直调。 Only Host authority mutates world state; rejected commands stay inert; Host and Client converge without duplicate effects, damage, or stale resurrection.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Host/Client source, player, owner, generation, and sequence are explicit and converge without duplicate authority mutation.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events. Terminate every test Host/Client child instance and re-enumerate processes to prove no multiplayer process remains.
- Regression: Single-player authority, presentation order, registry lifecycle, reconnect, and late join where claimed.
- Evidence: Per-window PID/HWND, Host/Client action and event traces, screenshots, logs, cleanup counts, and Harness.
- Automation gaps: Harness can enumerate Host/Client and control Host, but Client foreground input, screenshot, and per-client telemetry are not yet reliable.

### Step 4.5 — 建立 Registry Snapshot、Scheduler 与 Damage Inbox

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + LOG + MULTIPLAYER`
- Eyes: `EYE_TELEMETRY + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Use two pre-placed ships in two contexts with one identified Host and at least one Client; freeze owner, capability, generation, and command sequence.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] Host 在固定边界生成 immutable registry snapshot；[ ] scheduler 统一安排 target/projectile/effect/craft/joint 工作；[ ] damage inbox 按 owner/sequence 接收并排序伤害；[ ] 禁止热循环修改遍历中的 registry；[ ] 记录队列深度、丢弃和延迟。 Start official local multiplayer; send one minimal real command from the owner and one invalid or non-owner command.
- Reload: `RESTART_MOD_SESSION` — Terminate and relaunch every teardown_modtest Host/Client instance after multiplayer runtime changes.
- State assertions: 目标、伤害和实体生命周期在 tick 内可预测，snapshot 可回放。 [ ] snapshot 在同一 tick 内稳定；[ ] damage 顺序可重放；[ ] owner dispose 清理 inbox；[ ] 队列满/过期策略有 fixture。 Only Host authority mutates world state; rejected commands stay inert; Host and Client converge without duplicate effects, damage, or stale resurrection.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Host/Client source, player, owner, generation, and sequence are explicit and converge without duplicate authority mutation.
- Visual: not required
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events. Terminate every test Host/Client child instance and re-enumerate processes to prove no multiplayer process remains.
- Regression: Single-player authority, presentation order, registry lifecycle, reconnect, and late join where claimed.
- Evidence: Per-window PID/HWND, Host/Client action and event traces, screenshots, logs, cleanup counts, and Harness.
- Automation gaps: Harness can enumerate Host/Client and control Host, but Client foreground input, screenshot, and per-client telemetry are not yet reliable.

### Step 4.6 — 版本化多人 Command/Snapshot 边界

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + LOG + MULTIPLAYER`
- Eyes: `EYE_TELEMETRY + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Use two pre-placed ships in two contexts with one identified Host and at least one Client; freeze owner, capability, generation, and command sequence.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 定义客户端 command、服务端 snapshot、ack、sequence、late join、重连和版本协商；[ ] 只传可序列化 DTO；[ ] 服务器拒绝越权 command 和过期 revision；[ ] 为缺包/版本不符定义清晰失败，不静默分叉。 Start official local multiplayer; send one minimal real command from the owner and one invalid or non-owner command. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `RESTART_MOD_SESSION` — Terminate and relaunch every teardown_modtest Host/Client instance after multiplayer runtime changes.
- State assertions: S7 的配置、开火、锁定、死亡和重连行为有可回放协议。 [ ] host/remote/late join fixture；[ ] duplicate/out-of-order/unknown version 策略通过；[ ] network bytes 和 queue depth 进入诊断。 Only Host authority mutates world state; rejected commands stay inert; Host and Client converge without duplicate effects, damage, or stale resurrection.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Host/Client source, player, owner, generation, and sequence are explicit and converge without duplicate authority mutation.
- Visual: not required
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events. Terminate every test Host/Client child instance and re-enumerate processes to prove no multiplayer process remains.
- Regression: Single-player authority, presentation order, registry lifecycle, reconnect, and late join where claimed.
- Evidence: Per-window PID/HWND, Host/Client action and event traces, screenshots, logs, cleanup counts, and Harness.
- Automation gaps: Harness can enumerate Host/Client and control Host, but Client foreground input, screenshot, and per-client telemetry are not yet reliable.

### Step 5.1 — 把实体索引从 Registry 全表压缩改为本地 Dense Store

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + LOG`
- Eyes: `EYE_TELEMETRY + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Construct seeded low/high-density battlefield fixtures with fixed ships, projectiles, cells, mounts, targets, and budgets; never fly to create load.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 为 projectile、craft、effect、joint 等高频实体建立 capacity/active/free-list/generation dense store；[ ] registry 只保存跨系统索引和 snapshot；[ ] 拒绝 stale handle；[ ] 记录 active/free/capacity 和重用次数；[ ] 比较 table iteration、内存和 GC。 Run identical seeded actions at baseline and pressure scale and collect authoritative counts and timings.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for runtime Lua and reopen XML when density or placement changes.
- State assertions: 高频更新为连续数组、可预测容量和 O(1) 删除/重用。 [ ] `active + free = capacity`；[ ] S2–S4 不增长泄漏；[ ] handle generation fixture 通过；[ ] before/after p95/p99 有数据。 Selection, hit, and collision semantics remain equal while stores and queries stay bounded; no P×S fallback, stale handle, or unbounded allocation remains.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: not required
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Direct/guided/PD/interceptor collision golden, lifecycle cleanup, and S0–S8 performance baselines.
- Evidence: Seed/config, telemetry counters, before/after p95/p99 samples, hit traces, screenshots, logs, and Harness.
- Automation gaps: Authoritative frame-time, GC, query, and allocation telemetry must be completed and baselined before the performance claim is fully automatic.

### Step 5.2 — 建立 Scene Target Catalog 与简单 Uniform Grid

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + LOG`
- Eyes: `EYE_TELEMETRY + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Construct seeded low/high-density battlefield fixtures with fixed ships, projectiles, cells, mounts, targets, and budgets; never fly to create load.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 每个 scene 维护可攻击目标 snapshot；[ ] 按固定 cell size 建 uniform grid；[ ] 更新只在 spawn/move/disable 时进行；[ ] target filter 在目录层预筛选 faction/type/capability；[ ] 查询返回 stable entity/generation。 Run identical seeded actions at baseline and pressure scale and collect authoritative counts and timings.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for runtime Lua and reopen XML when density or placement changes.
- State assertions: S1/S3 的候选查询成本与目标数量局部相关。 [ ] 网格边界、移动和销毁 fixture；[ ] candidate 结果与 legacy golden 一致；[ ] query 次数/耗时进入诊断。 Selection, hit, and collision semantics remain equal while stores and queries stay bounded; no P×S fallback, stale handle, or unbounded allocation remains.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: not required
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Direct/guided/PD/interceptor collision golden, lifecycle cleanup, and S0–S8 performance baselines.
- Evidence: Seed/config, telemetry counters, before/after p95/p99 samples, hit traces, screenshots, logs, and Harness.
- Automation gaps: Authoritative frame-time, GC, query, and allocation telemetry must be completed and baselined before the performance claim is fully automatic.

### Step 5.3 — 重构 Point Defense 为“每舰一次候选 + Mount 分配”

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Construct seeded low/high-density battlefield fixtures with fixed ships, projectiles, cells, mounts, targets, and budgets; never fly to create load.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 每舰/每 tick 一次目标候选构建；[ ] 在船内为 mount 分配目标和 fire budget；[ ] 复用 target catalog/grid 结果；[ ] 明确距离、优先级、冷却、武器类型和重复锁定策略；[ ] 记录候选数、分配数、拒绝数。 Run identical seeded actions at baseline and pressure scale and collect authoritative counts and timings.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for runtime Lua and reopen XML when density or placement changes.
- State assertions: Point Defense 在 12 船/24 mount 和 24 craft 场景中预算可控。 [ ] 结果与旧逻辑 golden 一致；[ ] S3 query/CPU p95 达标；[ ] 过载时降级顺序确定；[ ] mount dispose 不留锁定。 Selection, hit, and collision semantics remain equal while stores and queries stay bounded; no P×S fallback, stale handle, or unbounded allocation remains.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. The real path reaches the applicable ordered boundaries: input_edge/fire_request → weapon_released → hit → damage_applied → hp_changed; omitted boundaries require a weapon-specific explanation.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Direct/guided/PD/interceptor collision golden, lifecycle cleanup, and S0–S8 performance baselines.
- Evidence: Seed/config, telemetry counters, before/after p95/p99 samples, hit traces, screenshots, logs, and Harness.
- Automation gaps: Authoritative frame-time, GC, query, and allocation telemetry must be completed and baselined before the performance claim is fully automatic.

### Step 5.4 — 建立统一 Projectile API 与 Logical Dense Store

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Construct seeded low/high-density battlefield fixtures with fixed ships, projectiles, cells, mounts, targets, and budgets; never fly to create load.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 定义 spawn/update/collide/finish/destroy/owner/lifetime DTO；[ ] 物理 projectile 和 logical projectile 共用生命周期合同；[ ] 进入 dense store/free-list；[ ] 统一 seed、速度、flight、target、damage、impact event；[ ] 允许 synthetic/replay。 Run identical seeded actions at baseline and pressure scale and collect authoritative counts and timings.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for runtime Lua and reopen XML when density or placement changes.
- State assertions: Projectile 行为可由统一 API、snapshot 和 EffectEvent 驱动。 [ ] 生命周期幂等；[ ] stale owner/handle 被拒绝；[ ] S2/S4 结果与 golden 一致；[ ] active/memory 平台化。 Selection, hit, and collision semantics remain equal while stores and queries stay bounded; no P×S fallback, stale handle, or unbounded allocation remains.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. The real path reaches the applicable ordered boundaries: input_edge/fire_request → weapon_released → hit → damage_applied → hp_changed; omitted boundaries require a weapon-specific explanation.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant. Muzzle/beam/projectile/impact appears once at the authoritative anchor and target without obvious clipping or duplicate legacy playback.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Direct/guided/PD/interceptor collision golden, lifecycle cleanup, and S0–S8 performance baselines.
- Evidence: Seed/config, telemetry counters, before/after p95/p99 samples, hit traces, screenshots, logs, and Harness.
- Automation gaps: Authoritative frame-time, GC, query, and allocation telemetry must be completed and baselined before the performance claim is fully automatic.

### Step 5.5 — 消除普通弹丸的 `P×S` 护盾扫描

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Construct seeded low/high-density battlefield fixtures with fixed ships, projectiles, cells, mounts, targets, and budgets; never fly to create load.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 找出 projectile × shield 的全量扫描；[ ] 利用目标目录、空间候选和 shield snapshot 预筛；[ ] 对普通弹丸建立一次命中/护盾候选流程；[ ] 保留特殊穿透/多段伤害的明确例外；[ ] 对比命中、伤害和 Query。 Run identical seeded actions at baseline and pressure scale and collect authoritative counts and timings.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for runtime Lua and reopen XML when density or placement changes.
- State assertions: S4/压力场景 Query 和 server p95 显著下降，伤害语义保持一致。 [ ] 普通弹不再逐 shield 全表扫描；[ ] 特殊弹有 explicit path；[ ] 伤害 golden、边界和排序一致；[ ] 无漏命中。 Selection, hit, and collision semantics remain equal while stores and queries stay bounded; no P×S fallback, stale handle, or unbounded allocation remains.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. The real path reaches the applicable ordered boundaries: input_edge/fire_request → weapon_released → hit → damage_applied → hp_changed; omitted boundaries require a weapon-specific explanation.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant. Muzzle/beam/projectile/impact appears once at the authoritative anchor and target without obvious clipping or duplicate legacy playback.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Direct/guided/PD/interceptor collision golden, lifecycle cleanup, and S0–S8 performance baselines.
- Evidence: Seed/config, telemetry counters, before/after p95/p99 samples, hit traces, screenshots, logs, and Harness.
- Automation gaps: Authoritative frame-time, GC, query, and allocation telemetry must be completed and baselined before the performance claim is fully automatic.

### Step 5.6 — 将 Guided Collision 从五 Query 常态改为受预算连续扫掠

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Construct seeded low/high-density battlefield fixtures with fixed ships, projectiles, cells, mounts, targets, and budgets; never fly to create load.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 为 guided projectile 维护上次位置/速度/flight state；[ ] 使用受预算的连续 sweep 或分段采样；[ ] 只有接近目标/发生状态变化时增加 Query；[ ] 固定 seed/阈值/最大步长；[ ] 记录 Query、命中漏检和降级。 Run identical seeded actions at baseline and pressure scale and collect authoritative counts and timings.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for runtime Lua and reopen XML when density or placement changes.
- State assertions: Guided 平均 ≤3000、硬上限 ≤6000 Query/s 的目标可测量，命中语义可回放。 [ ] S2 Query 与 p95/p99 达标；[ ] 直线、急转、近撞、超速 golden；[ ] 超预算时有明确连续性策略；[ ] 无无限重试。 Selection, hit, and collision semantics remain equal while stores and queries stay bounded; no P×S fallback, stale handle, or unbounded allocation remains.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. The real path reaches the applicable ordered boundaries: input_edge/fire_request → weapon_released → hit → damage_applied → hp_changed; omitted boundaries require a weapon-specific explanation.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Direct/guided/PD/interceptor collision golden, lifecycle cleanup, and S0–S8 performance baselines.
- Evidence: Seed/config, telemetry counters, before/after p95/p99 samples, hit traces, screenshots, logs, and Harness.
- Automation gaps: Authoritative frame-time, GC, query, and allocation telemetry must be completed and baselined before the performance claim is fully automatic.

### Step 5.7 — 建立精简 Interceptor Runtime

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Construct seeded low/high-density battlefield fixtures with fixed ships, projectiles, cells, mounts, targets, and budgets; never fly to create load.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 把 AI Interceptor 拆为 target selection、flight、intercept、impact、presentation；[ ] 使用 Target Catalog/Projectile API；[ ] 固定 think/update 预算；[ ] 统一 owner、generation、finish 和失效目标策略；[ ] 通过 synthetic replay。 Run identical seeded actions at baseline and pressure scale and collect authoritative counts and timings.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for runtime Lua and reopen XML when density or placement changes.
- State assertions: Interceptor 是可观测、可限额、可回收的轻量 runtime。 [ ] S3 目标选择/拦截/回收通过；[ ] target lost、owner dead、budget exhausted 有确定结果；[ ] no stale entities。 Selection, hit, and collision semantics remain equal while stores and queries stay bounded; no P×S fallback, stale handle, or unbounded allocation remains.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. The real path reaches the applicable ordered boundaries: input_edge/fire_request → weapon_released → hit → damage_applied → hp_changed; omitted boundaries require a weapon-specific explanation.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Direct/guided/PD/interceptor collision golden, lifecycle cleanup, and S0–S8 performance baselines.
- Evidence: Seed/config, telemetry counters, before/after p95/p99 samples, hit traces, screenshots, logs, and Harness.
- Automation gaps: Authoritative frame-time, GC, query, and allocation telemetry must be completed and baselined before the performance claim is fully automatic.

### Step 5.8 — 清理剩余固定浪费和 GC 热点

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + LOG`
- Eyes: `EYE_TELEMETRY + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Construct seeded low/high-density battlefield fixtures with fixed ships, projectiles, cells, mounts, targets, and budgets; never fly to create load.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 依据计数器找出临时 table、字符串拼接、重复 Find/Query、无界日志和 orphan cleanup；[ ] 将热点改为复用 buffer/整数计数/批处理；[ ] 为每项建立 before/after replay；[ ] 不用“关闭功能”掩盖成本。 Run identical seeded actions at baseline and pressure scale and collect authoritative counts and timings.
- Reload: `F4_TO_F5_OR_REOPEN_LEVEL_XML` — Use F4→F5 for runtime Lua and reopen XML when density or placement changes.
- State assertions: S0–S5 的 CPU、Query、GC、memory slope 达到 Gate 5 预算。 [ ] p95/p99、Query、active count、GC 和内存曲线有历史；[ ] 无未解释回归；[ ] 每项优化有 ADR 或 issue。 Selection, hit, and collision semantics remain equal while stores and queries stay bounded; no P×S fallback, stale handle, or unbounded allocation remains.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: not required
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Direct/guided/PD/interceptor collision golden, lifecycle cleanup, and S0–S8 performance baselines.
- Evidence: Seed/config, telemetry counters, before/after p95/p99 samples, hit traces, screenshots, logs, and Harness.
- Automation gaps: Authoritative frame-time, GC, query, and allocation telemetry must be completed and baselined before the performance claim is fully automatic.

### Step 6.1 — 用 VehicleInstance 包装现有单根 Body

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Use pre-placed single-body and minimal multi-body/joint fixtures with named parts and anchors, fixed transforms, and bounded spawn/dispose repetitions.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 定义 VehicleInstance identity/generation/owner/definition/body handle/lifecycle；[ ] 用 adapter 包装现有单根 Body；[ ] 迁移 ship lifecycle、health、input、mount lookup 的入口；[ ] 暂不改变物理布局。 Resolve anchors, use one real move/fire/enter action only where it is under test, then spawn and dispose the graph.
- Reload: `REOPEN_LEVEL_XML_OR_F4_TO_F5` — Reopen XML for graph/prefab changes and use F4→F5 for resolver Lua.
- State assertions: 现有单 Body 舰船以显式实例存在，root Body 不再等于全部语义。 [ ] S0/S6 identity、owner、dispose 正确；[ ] generation 重用被拒绝；[ ] 旧行为 snapshot 一致。 Stable entity/part identity and parent-local transforms resolve within tolerance; every body, joint, anchor, and registry item disposes exactly once.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Registration and lifecycle reach a terminal ship_destroyed → ship_unregistered → ship_cleanup or the task's documented equivalent exactly once. Authoritative transforms, linear/angular velocity, owner, and registered state match the deterministic fixture within its numeric tolerance.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Existing single-body ships, muzzle/effect/camera anchors, damage, and lifecycle cleanup.
- Evidence: Graph snapshot, transform tolerance report, lifecycle events, screenshots, logs, and Harness.

### Step 6.2 — 建立 EntityGraph 与稳定 Part/Anchor Resolver

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Use pre-placed single-body and minimal multi-body/joint fixtures with named parts and anchors, fixed transforms, and bounded spawn/dispose repetitions.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 定义 EntityGraph 节点/父子关系/part id/anchor id；[ ] Resolver 根据 definition + runtime graph 解析 Body/Shape/Joint/Transform；[ ] 缺失/重复/循环引用失败；[ ] generation 和 owner 进入返回值；[ ] 记录 lookup 命中与失败。 Resolve anchors, use one real move/fire/enter action only where it is under test, then spawn and dispose the graph.
- Reload: `REOPEN_LEVEL_XML_OR_F4_TO_F5` — Reopen XML for graph/prefab changes and use F4→F5 for resolver Lua.
- State assertions: 所有部件和挂点都有稳定、可验证、可缓存的地址。 [ ] root/child/anchor/cycle/missing fixture；[ ] 同一 graph 解析稳定；[ ] S1 mount 数量和坐标 golden 一致。 Stable entity/part identity and parent-local transforms resolve within tolerance; every body, joint, anchor, and registry item disposes exactly once.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Registration and lifecycle reach a terminal ship_destroyed → ship_unregistered → ship_cleanup or the task's documented equivalent exactly once. Authoritative transforms, linear/angular velocity, owner, and registered state match the deterministic fixture within its numeric tolerance.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Existing single-body ships, muzzle/effect/camera anchors, damage, and lifecycle cleanup.
- Evidence: Graph snapshot, transform tolerance report, lifecycle events, screenshots, logs, and Harness.

### Step 6.3 — 建立统一 Transform/Anchor API

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Use pre-placed single-body and minimal multi-body/joint fixtures with named parts and anchors, fixed transforms, and bounded spawn/dispose repetitions.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 提供 local/world/parent transform、forward/up/right、velocity、scale、mirror API；[ ] 明确单位和 frame；[ ] 禁止系统直接读取 root Body 或手写 offset；[ ] 为 anchor cache 定义失效时机；[ ] 与 Step 1.1 golden 对齐。 Resolve anchors, use one real move/fire/enter action only where it is under test, then spawn and dispose the graph.
- Reload: `REOPEN_LEVEL_XML_OR_F4_TO_F5` — Reopen XML for graph/prefab changes and use F4→F5 for resolver Lua.
- State assertions: 所有新功能只依赖 Transform/Anchor API，坐标错误可在 resolver 层定位。 [ ] root/parent/mirror/scale/rotation golden；[ ] world/local round-trip；[ ] invalid handle 不访问 engine；[ ] API 文档完成。 Stable entity/part identity and parent-local transforms resolve within tolerance; every body, joint, anchor, and registry item disposes exactly once.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Authoritative transforms, linear/angular velocity, owner, and registered state match the deterministic fixture within its numeric tolerance.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Existing single-body ships, muzzle/effect/camera anchors, damage, and lifecycle cleanup.
- Evidence: Graph snapshot, transform tolerance report, lifecycle events, screenshots, logs, and Harness.

### Step 6.4 — 按顺序把现有系统迁移到 AnchorResolver

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Use pre-placed single-body and minimal multi-body/joint fixtures with named parts and anchors, fixed transforms, and bounded spawn/dispose repetitions.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 迁移 mount/fire transform；[ ] camera/engine/thruster；[ ] weapon muzzle/projectile spawn；[ ] FX/audio/shake anchors；[ ] damage/part health；[ ] 每一批保留 legacy 对照和差异报告。 Resolve anchors, use one real move/fire/enter action only where it is under test, then spawn and dispose the graph. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `REOPEN_LEVEL_XML_OR_F4_TO_F5` — Reopen XML for graph/prefab changes and use F4→F5 for resolver Lua.
- State assertions: 现有功能不再依赖根 Body magic offset，AnchorResolver 成为单一坐标事实来源。 [ ] S0/S1/S5 各批次通过；[ ] 发射、镜头、效果、伤害位置 golden；[ ] 未迁移系统有 ledger 条目。 Stable entity/part identity and parent-local transforms resolve within tolerance; every body, joint, anchor, and registry item disposes exactly once.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Authoritative transforms, linear/angular velocity, owner, and registered state match the deterministic fixture within its numeric tolerance.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Existing single-body ships, muzzle/effect/camera anchors, damage, and lifecycle cleanup.
- Evidence: Graph snapshot, transform tolerance report, lifecycle events, screenshots, logs, and Harness.

### Step 6.5 — 引入最小多 Body/Joint Fixture，不做正式炮塔

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `AUTO_WITH_VISUAL_REVIEW`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Use pre-placed single-body and minimal multi-body/joint fixtures with named parts and anchors, fixed transforms, and bounded spawn/dispose repetitions.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 建立一个最小多 Body/Joint 舰体 fixture；[ ] 验证创建、父子 transform、joint limit、dispose、网络 snapshot；[ ] 仅测 fixture 和 resolver，不开放正式玩家炮塔；[ ] 记录物理成本和失败模式。 Resolve anchors, use one real move/fire/enter action only where it is under test, then spawn and dispose the graph.
- Reload: `REOPEN_LEVEL_XML_OR_F4_TO_F5` — Reopen XML for graph/prefab changes and use F4→F5 for resolver Lua.
- State assertions: 得到可重复的 multi-body/joint 技术证据和预算。 [ ] fixture 可 spawn/update/dispose；[ ] joint 异常/父体销毁不泄漏；[ ] S7 协议能表达或明确拒绝；[ ] 没有正式内容依赖。 Stable entity/part identity and parent-local transforms resolve within tolerance; every body, joint, anchor, and registry item disposes exactly once.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. The real path reaches the applicable ordered boundaries: input_edge/fire_request → weapon_released → hit → damage_applied → hp_changed; omitted boundaries require a weapon-specific explanation. Authoritative transforms, linear/angular velocity, owner, and registered state match the deterministic fixture within its numeric tolerance.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant. Muzzle/beam/projectile/impact appears once at the authoritative anchor and target without obvious clipping or duplicate legacy playback.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Existing single-body ships, muzzle/effect/camera anchors, damage, and lifecycle cleanup.
- Evidence: Graph snapshot, transform tolerance report, lifecycle events, screenshots, logs, and Harness.
- Automation gaps: AI owns objective visibility, count, clipping, alignment, and budget checks; subjective visual quality remains a human review.

### Step 6.6 — 建立 Vehicle Factory 与动态 Spawn/Dispose API

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Use pre-placed single-body and minimal multi-body/joint fixtures with named parts and anchors, fixed transforms, and bounded spawn/dispose repetitions.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] Factory 从 VehicleDefinition/manifest 创建实例；[ ] 分阶段创建 graph、body、shape、joint、mount、runtime；[ ] 任何阶段失败都执行幂等回滚；[ ] Spawn/Dispose 产生 lifecycle event；[ ] 支持 synthetic/preview/test。 Resolve anchors, use one real move/fire/enter action only where it is under test, then spawn and dispose the graph.
- Reload: `REOPEN_LEVEL_XML_OR_F4_TO_F5` — Reopen XML for graph/prefab changes and use F4→F5 for resolver Lua.
- State assertions: 舰船生命周期从手工脚本变成可组合、可测试 API。 [ ] S1 反复 spawn/dispose 无 orphan；[ ] 部分失败清理完整；[ ] owner/generation/registry/snapshot 一致；[ ] 资源计数回到平台。 Stable entity/part identity and parent-local transforms resolve within tolerance; every body, joint, anchor, and registry item disposes exactly once.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Registration and lifecycle reach a terminal ship_destroyed → ship_unregistered → ship_cleanup or the task's documented equivalent exactly once.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Existing single-body ships, muzzle/effect/camera anchors, damage, and lifecycle cleanup.
- Evidence: Graph snapshot, transform tolerance report, lifecycle events, screenshots, logs, and Harness.

### Step 6.7 — 切换现有舰船并删除根 Body 坐标权威

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Use pre-placed single-body and minimal multi-body/joint fixtures with named parts and anchors, fixed transforms, and bounded spawn/dispose repetitions.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 将现有 5 个 Vehicle 切换到 VehicleFactory/EntityGraph/AnchorResolver；[ ] 删除已迁移系统对根 Body 坐标的直接读取；[ ] 更新 snapshot、Harness、实机 smoke 和目录文档；[ ] 保留有限 legacy adapter 直到下一 Gate 复核。 Resolve anchors, use one real move/fire/enter action only where it is under test, then spawn and dispose the graph. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `REOPEN_LEVEL_XML_OR_F4_TO_F5` — Reopen XML for graph/prefab changes and use F4→F5 for resolver Lua.
- State assertions: 现有舰船成为可动态创建、可解析、可回收的 VehicleInstance。 [ ] 5/5 Vehicle 通过；[ ] S0–S7 无未记录坐标/生命周期差异；[ ] 根 Body 权威引用扫描为零或有 ADR；[ ] 完整 Harness 通过。 Stable entity/part identity and parent-local transforms resolve within tolerance; every body, joint, anchor, and registry item disposes exactly once.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Authoritative transforms, linear/angular velocity, owner, and registered state match the deterministic fixture within its numeric tolerance.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Existing single-body ships, muzzle/effect/camera anchors, damage, and lifecycle cleanup.
- Evidence: Graph snapshot, transform tolerance report, lifecycle events, screenshots, logs, and Harness.

### Step 7.1 — 编译 `TurretDefinition v1` 与炮塔 Fixture

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `AUTO_WITH_VISUAL_REVIEW`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Pre-place a turret and target at known azimuth, elevation, and range, including limit, LOD, and joint-budget boundary fixtures.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 定义 turret id、base/axis anchors、yaw/pitch limits、slew、fire mount、target policy、visual/physical mode、budget 和 ownership；[ ] Compiler 输出 normalized definition；[ ] 建立单炮塔/双轴/镜像/缺 anchor fixture；[ ] 不把 engine joint handle 写入 source。 Run solver golden, then issue only the real aim/fire action required; repeat in Host/Client contexts when network authority is claimed.
- Reload: `REOPEN_LEVEL_XML_OR_RESTART_MOD_SESSION` — Reopen turret XML, F4→F5 solver Lua, and relaunch multiplayer for network changes.
- State assertions: 逻辑、视觉、物理实现共享同一 TurretDefinition v1。 [ ] valid/missing/limit/wrong frame fixture；[ ] 生成结果确定性；[ ] Hero Fixture 能从 definition 构建。 Angles, limits, and convergence match tolerance; actuator follows logical state; muzzle and hit align; sequence is monotonic and fallback respects budget.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. The real path reaches the applicable ordered boundaries: input_edge/fire_request → weapon_released → hit → damage_applied → hp_changed; omitted boundaries require a weapon-specific explanation. Authoritative transforms, linear/angular velocity, owner, and registered state match the deterministic fixture within its numeric tolerance.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant. Muzzle/beam/projectile/impact appears once at the authoritative anchor and target without obvious clipping or duplicate legacy playback.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Fixed mounts, anchor resolver, projectile/hit chain, LOD, joint budget, and multiplayer ownership.
- Evidence: Solver vectors, telemetry angles/owners/hits, screenshots, budget metrics, logs, and Harness.
- Automation gaps: AI owns objective visibility, count, clipping, alignment, and budget checks; subjective visual quality remains a human review.

### Step 7.2 — 实现纯逻辑 TurretSolver

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Pre-place a turret and target at known azimuth, elevation, and range, including limit, LOD, and joint-budget boundary fixtures.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 实现 target selection、lead/aim、yaw/pitch clamp、slew、cooldown、fire permission；[ ] solver 只读 snapshot/Transform/target，不调用底层物理；[ ] 固定 timestep/seed；[ ] 输出 command/state DTO。 Run solver golden, then issue only the real aim/fire action required; repeat in Host/Client contexts when network authority is claimed.
- Reload: `REOPEN_LEVEL_XML_OR_RESTART_MOD_SESSION` — Reopen turret XML, F4→F5 solver Lua, and relaunch multiplayer for network changes.
- State assertions: 逻辑炮塔可在 synthetic、Preview、服务器和回放中运行。 [ ] 直线/转向/限制/失标/销毁 golden；[ ] 多人同输入输出一致；[ ] solver 无 engine side effect。 Angles, limits, and convergence match tolerance; actuator follows logical state; muzzle and hit align; sequence is monotonic and fallback respects budget.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Authoritative transforms, linear/angular velocity, owner, and registered state match the deterministic fixture within its numeric tolerance.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Fixed mounts, anchor resolver, projectile/hit chain, LOD, joint budget, and multiplayer ownership.
- Evidence: Solver vectors, telemetry angles/owners/hits, screenshots, budget metrics, logs, and Harness.

### Step 7.3 — 增加 Visual Actuator 与 LOD

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Pre-place a turret and target at known azimuth, elevation, and range, including limit, LOD, and joint-budget boundary fixtures.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 将 solver state 映射为 visual yaw/pitch；[ ] 设定 near/far/culled LOD；[ ] 远处降低 update rate/效果/音频；[ ] visual actuator 不改变 server command；[ ] 接入 Effect/Audio budget。 Run solver golden, then issue only the real aim/fire action required; repeat in Host/Client contexts when network authority is claimed.
- Reload: `REOPEN_LEVEL_XML_OR_RESTART_MOD_SESSION` — Reopen turret XML, F4→F5 solver Lua, and relaunch multiplayer for network changes.
- State assertions: 远近炮塔成本可控，视觉降级不影响瞄准和伤害。 [ ] LOD 切换无跳变；[ ] scene-wide visual budget 有计数；[ ] S1/S5 下 p95 达标；[ ] owner dispose 停止 actuator。 Angles, limits, and convergence match tolerance; actuator follows logical state; muzzle and hit align; sequence is monotonic and fallback respects budget.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Fixed mounts, anchor resolver, projectile/hit chain, LOD, joint budget, and multiplayer ownership.
- Evidence: Solver vectors, telemetry angles/owners/hits, screenshots, budget metrics, logs, and Harness.

### Step 7.4 — 完成 Turret Network 与多人权威

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG + MULTIPLAYER`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Pre-place a turret and target at known azimuth, elevation, and range, including limit, LOD, and joint-budget boundary fixtures. Include one identified Host and at least one identified Client.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 服务端权威输出 turret state/command revision；[ ] 客户端只预测/插值视觉；[ ] 处理 late join、包丢失、重连、stale generation 和 fire ack；[ ] 物理 joint handle 不跨网络传输。 Run solver golden, then issue only the real aim/fire action required; repeat in Host/Client contexts when network authority is claimed. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `REOPEN_LEVEL_XML_OR_RESTART_MOD_SESSION` — Reopen turret XML, F4→F5 solver Lua, and relaunch multiplayer for network changes.
- State assertions: S7 中炮塔锁定、转动、开火、死亡和重连一致。 [ ] host/remote/late join fixture；[ ] server fire authority 不可绕过；[ ] visual prediction 与 snapshot 收敛；[ ] 断线 cleanup 完整。 Angles, limits, and convergence match tolerance; actuator follows logical state; muzzle and hit align; sequence is monotonic and fallback respects budget.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Host/Client source, player, owner, generation, and sequence are explicit and converge without duplicate authority mutation. Authoritative transforms, linear/angular velocity, owner, and registered state match the deterministic fixture within its numeric tolerance.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events. Terminate every test Host/Client child instance and re-enumerate processes to prove no multiplayer process remains.
- Regression: Fixed mounts, anchor resolver, projectile/hit chain, LOD, joint budget, and multiplayer ownership.
- Evidence: Solver vectors, telemetry angles/owners/hits, screenshots, budget metrics, logs, and Harness.
- Automation gaps: Harness can enumerate Host/Client and control Host, but Client foreground input, screenshot, and per-client telemetry are not yet reliable.

### Step 7.5 — 用 Hero Fixture 验证 Physical Joint Actuator

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Pre-place a turret and target at known azimuth, elevation, and range, including limit, LOD, and joint-budget boundary fixtures.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 选一个可控 Hero Fixture；[ ] 创建 base/hinge/axis/limit/actuator；[ ] 将 solver output 映射为 joint target；[ ] 测试碰撞、抖动、父体销毁、重生、网络和性能；[ ] 与纯逻辑/visual 结果对照。 Run solver golden, then issue only the real aim/fire action required; repeat in Host/Client contexts when network authority is claimed.
- Reload: `REOPEN_LEVEL_XML_OR_RESTART_MOD_SESSION` — Reopen turret XML, F4→F5 solver Lua, and relaunch multiplayer for network changes.
- State assertions: 得到是否采用物理执行器、哪些参数/场景必须降级的实证。 [ ] Hero fixture 长时间稳定；[ ] joint/body orphan=0；[ ] CPU/Joint count 在预算内；[ ] 失败结论可允许“不采用物理模式”。 Angles, limits, and convergence match tolerance; actuator follows logical state; muzzle and hit align; sequence is monotonic and fallback respects budget.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Authoritative transforms, linear/angular velocity, owner, and registered state match the deterministic fixture within its numeric tolerance.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Fixed mounts, anchor resolver, projectile/hit chain, LOD, joint budget, and multiplayer ownership.
- Evidence: Solver vectors, telemetry angles/owners/hits, screenshots, budget metrics, logs, and Harness.

### Step 7.6 — 建立 Scene-wide Joint Budget 与自动降级

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Pre-place a turret and target at known azimuth, elevation, and range, including limit, LOD, and joint-budget boundary fixtures.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 定义 scene joint hard cap、soft cap、优先级和 owner；[ ] joint 创建前做预算申请；[ ] 超限按 far/low-priority/visual-only/逻辑-only 自动降级；[ ] 记录 requested/accepted/degraded/rejected；[ ] 预算与 network/physics/FX 指标关联。 Run solver golden, then issue only the real aim/fire action required; repeat in Host/Client contexts when network authority is claimed.
- Reload: `REOPEN_LEVEL_XML_OR_RESTART_MOD_SESSION` — Reopen turret XML, F4→F5 solver Lua, and relaunch multiplayer for network changes.
- State assertions: 大场景在可控成本下保持核心战斗语义，降级可解释。 [ ] S1/S5 不突破 hard cap；[ ] 近处高优先级保留；[ ] 降级/恢复稳定无抖动；[ ] 自动降级事件可回放。 Angles, limits, and convergence match tolerance; actuator follows logical state; muzzle and hit align; sequence is monotonic and fallback respects budget.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Authoritative transforms, linear/angular velocity, owner, and registered state match the deterministic fixture within its numeric tolerance.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Fixed mounts, anchor resolver, projectile/hit chain, LOD, joint budget, and multiplayer ownership.
- Evidence: Solver vectors, telemetry angles/owners/hits, screenshots, budget metrics, logs, and Harness.

### Step 7.7 — 删除固定根 Body 炮口假设并开放炮塔内容

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `AUTO_WITH_VISUAL_REVIEW`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Pre-place a turret and target at known azimuth, elevation, and range, including limit, LOD, and joint-budget boundary fixtures.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 删除已迁移 weapon/mount 对根 Body muzzle 的强假设；[ ] 让 fire mount 来自 AnchorResolver/TurretDefinition；[ ] 将 Hero Fixture 扩展为一个正式内容；[ ] 更新 Catalog、Editor、Harness、Preview 和文档；[ ] 仍保留明确的逻辑/visual fallback。 Run solver golden, then issue only the real aim/fire action required; repeat in Host/Client contexts when network authority is claimed. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `REOPEN_LEVEL_XML_OR_RESTART_MOD_SESSION` — Reopen turret XML, F4→F5 solver Lua, and relaunch multiplayer for network changes.
- State assertions: 创作者可以声明多轴、镜像和不同 mount，运行时按模式/预算选择执行。 [ ] 根 Body muzzle 权威引用扫描清零或有 ADR；[ ] 正式炮塔内容通过 S1/S5/S7；[ ] 物理不可用时逻辑/视觉仍正确；[ ] 完整 Harness 通过。 Angles, limits, and convergence match tolerance; actuator follows logical state; muzzle and hit align; sequence is monotonic and fallback respects budget.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. The real path reaches the applicable ordered boundaries: input_edge/fire_request → weapon_released → hit → damage_applied → hp_changed; omitted boundaries require a weapon-specific explanation. Authoritative transforms, linear/angular velocity, owner, and registered state match the deterministic fixture within its numeric tolerance.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant. Muzzle/beam/projectile/impact appears once at the authoritative anchor and target without obvious clipping or duplicate legacy playback.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Fixed mounts, anchor resolver, projectile/hit chain, LOD, joint budget, and multiplayer ownership.
- Evidence: Solver vectors, telemetry angles/owners/hits, screenshots, budget metrics, logs, and Harness.
- Automation gaps: AI owns objective visibility, count, clipping, alignment, and budget checks; subjective visual quality remains a human review.

### Step 8.1 — 建立只读 Asset Importer 与 `AssetManifest v1`

- Implementation: `finish`
- Verification: `verified` — Existing static/fixture evidence satisfies the current contract; rerun the listed regression when an adjacent authority changes.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE`
- Eyes: `none`
- Hands: `HAND_TEST_SETUP`
- Setup: Use read-only source assets and disposable editor/preview projects covering valid, invalid, mirrored, and round-trip cases.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 扫描 VOX、sprite、sound、prefab、material 并生成只读 manifest；[ ] 记录 hash、尺寸、轴、scale、palette、依赖、license/provenance 和性能 class；[ ] 拒绝越界路径、缺失、重复 ID 和不支持格式；[ ] Importer 不修改 Runtime source。 Import, build, edit, or wizard-generate twice; validate output; then open the generated artifact in its deterministic preview scene.
- Reload: `NONE_OR_REOPEN_LEVEL_XML` — Tool-only work needs no Teardown reload; reopen XML for an in-game preview artifact.
- State assertions: AssetManifest 成为资源引用、校验、Preview 和 AI 建议的共同输入。 [ ] 相同资产扫描结果稳定；[ ] 缺失/越界/超大/错误 hash fixture；[ ] 只读约束可检查；[ ] manifest 与 catalog hash 关联。 Source remains unchanged; output is deterministic and cache-correct; schema, axes, anchors, and mounts round-trip without runtime catalog mutation.
- Telemetry: not required
- Visual: not required
- Log: not required
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority.
- Regression: Asset manifest/provenance, compiler/schema, VOX orientation, anchors, and preview budgets.
- Evidence: Source/output hashes, generated definitions, UI action trace, preview screenshot/log, and Harness.

### Step 8.2 — 把 Asset Build 变成确定性、可缓存的 Pipeline

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE`
- Eyes: `none`
- Hands: `HAND_TEST_SETUP`
- Setup: Use read-only source assets and disposable editor/preview projects covering valid, invalid, mirrored, and round-trip cases.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 将 import、validate、voxelize/convert、optimize、compile、package 分阶段；[ ] 每步输入 hash/工具版本/参数进入 cache key；[ ] 成功产物原子写入，失败不覆盖最后有效版本；[ ] 输出 machine/human report；[ ] 支持 clean rebuild 和增量 rebuild。 Import, build, edit, or wizard-generate twice; validate output; then open the generated artifact in its deterministic preview scene.
- Reload: `NONE_OR_REOPEN_LEVEL_XML` — Tool-only work needs no Teardown reload; reopen XML for an in-game preview artifact.
- State assertions: 本机/CI/外部作者得到相同产物和可解释缓存命中。 [ ] clean/incremental byte 一致；[ ] 工具版本变化使 cache 失效；[ ] 任一步失败可恢复；[ ] build hash 可追踪到 source/asset。 Source remains unchanged; output is deterministic and cache-correct; schema, axes, anchors, and mounts round-trip without runtime catalog mutation.
- Telemetry: not required
- Visual: not required
- Log: not required
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority.
- Regression: Asset manifest/provenance, compiler/schema, VOX orientation, anchors, and preview budgets.
- Evidence: Source/output hashes, generated definitions, UI action trace, preview screenshot/log, and Harness.

### Step 8.3 — 把 Preview 扩展为 Effect Lab、Weapon Range 和 Ship Dock

- Implementation: `finish`
- Verification: `human_visual_review` — Objective engineering verification passed: deterministic fixtures/negative cases, real Editor XML reload, Lua F4->F5 reload, fresh-frame HID mode/replay input, all three visible Preview surfaces, runtime catalog immutability, attributed log health and cleanup are evidenced by run 20260813T130550Z-d3b94655. Only subjective visual impact and polish remain for human review.
- Automation: `AUTO_WITH_VISUAL_REVIEW`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + VISUAL + LOG`
- Eyes: `EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Use read-only source assets and disposable editor/preview projects covering valid, invalid, mirrored, and round-trip cases.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] Effect Lab 复用 EffectPlayer；[ ] Weapon Range 支持固定 seed、目标、伤害/弹道/预算回放；[ ] Ship Dock 支持 VOX/graph/anchor/mount/turret、spawn/dispose 和相机；[ ] 三个 Preview 使用同一 Compiler、Catalog、World/Entity adapter；[ ] 支持导出诊断和截图/录像。 Import, build, edit, or wizard-generate twice; validate output; then open the generated artifact in its deterministic preview scene. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `NONE_OR_REOPEN_LEVEL_XML` — Tool-only work needs no Teardown reload; reopen XML for an in-game preview artifact.
- State assertions: 从 source 到可观察结果的反馈周期缩短，Preview 与 Runtime 不产生第二套规则。 [ ] S0/S2/S5 的关键回放可在 Preview 重现；[ ] 预算/LOD/生命周期一致；[ ] Preview 失败不污染 Runtime catalog。 Source remains unchanged; output is deterministic and cache-correct; schema, axes, anchors, and mounts round-trip without runtime catalog mutation.
- Telemetry: not required
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant. Muzzle/beam/projectile/impact appears once at the authoritative anchor and target without obvious clipping or duplicate legacy playback. The generated asset/editor surface opens through the real UI path and shows the expected orientation, scale, anchors, controls, and diagnostics.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Asset manifest/provenance, compiler/schema, VOX orientation, anchors, and preview budgets.
- Evidence: Source/output hashes, generated definitions, UI action trace, preview screenshot/log, and Harness.
- Automation gaps: AI owns objective visibility, count, clipping, alignment, and budget checks; subjective visual quality remains a human review.

### Step 8.4 — 先做无 3D 的 Schema-driven Definition Editor MVP

- Implementation: `finish`
- Verification: `human_visual_review` — Objective engineering verification passed: five forms, field metadata, valid/invalid saves, diff, undo/redo, migration, byte-identical compile, forbidden-root immutability, real XML/Lua reload, HID UI navigation, attributed log health and cleanup are evidenced by Step 8.4 runs. Only subjective visual polish and creator ergonomics remain for human review.
- Automation: `AUTO_WITH_VISUAL_REVIEW`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + VISUAL + LOG`
- Eyes: `EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Use read-only source assets and disposable editor/preview projects covering valid, invalid, mirrored, and round-trip cases.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 从 schema 自动生成 Weapon/Projectile/Effect/Vehicle/Mount 表单；[ ] 显示 field path、单位、范围、引用、预算和诊断；[ ] 生成 source，不直接写 generated artifact；[ ] 支持 diff、undo、版本迁移和保存前 Compiler 验证；[ ] 无 3D 也可完成第一把武器。 Import, build, edit, or wizard-generate twice; validate output; then open the generated artifact in its deterministic preview scene. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `NONE_OR_REOPEN_LEVEL_XML` — Tool-only work needs no Teardown reload; reopen XML for an in-game preview artifact.
- State assertions: 普通创作者不用编辑 Lua 即可创建、验证和预览基础定义。 [ ] 五分钟创建第一把合法武器；[ ] invalid fields 阻断保存；[ ] source 再编译 byte 一致；[ ] 手工 diff 可审查。 Source remains unchanged; output is deterministic and cache-correct; schema, axes, anchors, and mounts round-trip without runtime catalog mutation.
- Telemetry: not required
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant. The generated asset/editor surface opens through the real UI path and shows the expected orientation, scale, anchors, controls, and diagnostics.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Asset manifest/provenance, compiler/schema, VOX orientation, anchors, and preview budgets.
- Evidence: Source/output hashes, generated definitions, UI action trace, preview screenshot/log, and Harness.
- Automation gaps: AI owns objective visibility, count, clipping, alignment, and budget checks; subjective visual quality remains a human review.

### Step 8.5 — 增加 VOX、Anchor、Mount 与 Turret 3D Editor

- Implementation: `finish`
- Verification: `human_visual_review` — Objective engineering verification passed on 2026-08-13. Static/fixture checks, a disposable live VOX editor scenario, real keyboard input, screenshot assertions, incremental runtime log attribution, F4 cleanup, emergency release, and full Harness evidence are stored in docs/evidence/step-8.5-anchor-turret-editor-v1.json. Only subjective visual polish and creator ergonomics remain for human review.
- Automation: `AUTO_WITH_VISUAL_REVIEW`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + VISUAL + LOG`
- Eyes: `EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Use read-only source assets and disposable editor/preview projects covering valid, invalid, mirrored, and round-trip cases.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 加载 AssetManifest/VOX；[ ] 显示 canonical axes、scale、parent/local transform；[ ] 可创建/移动/镜像 Anchor、Mount、Turret base/axis；[ ] 可视化 part/graph/joint budget；[ ] 每次编辑生成 source patch，不能直接改生成产物。 Import, build, edit, or wizard-generate twice; validate output; then open the generated artifact in its deterministic preview scene. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `NONE_OR_REOPEN_LEVEL_XML` — Tool-only work needs no Teardown reload; reopen XML for an in-game preview artifact.
- State assertions: 复杂挂点和炮塔可视化编辑，错误在构建前暴露。 [ ] root/child/mirror/scale golden；[ ] editor/runtime anchor 位置一致；[ ] missing/duplicate/cycle 阻断构建；[ ] budget preview 与 Runtime 一致。 Source remains unchanged; output is deterministic and cache-correct; schema, axes, anchors, and mounts round-trip without runtime catalog mutation.
- Telemetry: not required
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant. The generated asset/editor surface opens through the real UI path and shows the expected orientation, scale, anchors, controls, and diagnostics.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Asset manifest/provenance, compiler/schema, VOX orientation, anchors, and preview budgets.
- Evidence: Source/output hashes, generated definitions, UI action trace, preview screenshot/log, and Harness.
- Automation gaps: AI owns objective visibility, count, clipping, alignment, and budget checks; subjective visual quality remains a human review.

### Step 8.6 — 实现 Creator Ship Wizard MVP

- Implementation: `finish`
- Verification: `human_visual_review` — Objective engineering verification passed on 2026-08-13: deterministic four-file staging, eight fail-closed negative cases, clean rebuild/source immutability, disposable Teardown Wizard navigation, manual edit/backtracking, Build/Ship Dock/Weapon Range Preview, attributed runtime logs and cleanup are evidenced. Only subjective visual polish and creator ergonomics remain for human review.
- Automation: `AUTO_WITH_VISUAL_REVIEW`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + VISUAL + LOG`
- Eyes: `EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Use read-only source assets and disposable editor/preview projects covering valid, invalid, mirrored, and round-trip cases.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 设计 source/asset/definition/import/anchor/mount/preview/build/package 向导；[ ] 支持已有单 Body VOX；[ ] 自动生成 manifest、VehicleDefinition、默认 camera/engine/mount；[ ] 每一步可回退、可人工修改；[ ] 最终运行完整 Compiler/预算/入口检查。 Import, build, edit, or wizard-generate twice; validate output; then open the generated artifact in its deterministic preview scene. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `NONE_OR_REOPEN_LEVEL_XML` — Tool-only work needs no Teardown reload; reopen XML for an in-game preview artifact.
- State assertions: 创作者可从 VOX 到可预览、可构建的舰船包，所有自动建议可审计。 [ ] 单 Body ship clean-room 端到端成功；[ ] 缺资产/越界/坐标不确定时明确阻断；[ ] package hash、manifest、catalog 和 Preview 证据齐全。 Source remains unchanged; output is deterministic and cache-correct; schema, axes, anchors, and mounts round-trip without runtime catalog mutation.
- Telemetry: not required
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant. The generated asset/editor surface opens through the real UI path and shows the expected orientation, scale, anchors, controls, and diagnostics.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Asset manifest/provenance, compiler/schema, VOX orientation, anchors, and preview budgets.
- Evidence: Source/output hashes, generated definitions, UI action trace, preview screenshot/log, and Harness.
- Automation gaps: AI owns objective visibility, count, clipping, alignment, and budget checks; subjective visual quality remains a human review.

### Step 9.1 — 定义 `PackageManifest v1` 与 Data-only Capability

- Implementation: `finish`
- Verification: `verified` — The embedded STATIC+FIXTURE+CONSUMER_MOD contract passed: public schema/compiler/package tools are tracked, two clean builds and installs are deterministic, manifest and installed hashes match, valid use succeeds, incompatible/invalid use fails closed without overwriting last-valid bytes, Core-only fallback is explicit, the reopened Teardown Mod Manager starts the independent version-3 Consumer and displays PASS, runtime health is clean for in-scope paths, cleanup and full Harness pass. Evidence: docs/evidence/step-9.1-package-manifest-v1.json.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + CONSUMER_MOD`
- Eyes: `none`
- Hands: `HAND_TEST_SETUP`
- Setup: Build a clean-room disposable consumer Mod/package that uses only the published manifest, SDK, schema, or broker surface and no private CM2 include.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 定义 package id/version、schema/core/sdk range、source/assets/generated hash、依赖 DAG、capabilities、license/provenance、entrypoints；[ ] Data-only 包只能引用批准 schema/runtime nodes；[ ] 路径、依赖、重复 ID、循环和预算在构建前失败；[ ] manifest 可签名/复现。 Build/install twice, reopen Mod Manager, start the consumer, and invoke one valid plus one invalid public operation.
- Reload: `REOPEN_MOD_MANAGER_OR_RESTART_MOD_SESSION` — Reopen Mod Manager for new/metadata Mods and restart the Mod session for runtime changes.
- State assertions: 第三方可独立构建和验证内容包，Runtime 不加载未知 Lua。 [ ] valid/缺依赖/循环/越界/重复/超预算 fixture；[ ] manifest hash 与 package 产物一致；[ ] Capability 检查接入 Compiler。 Dependencies, versions, and capabilities are explicit; compatible use succeeds; incompatible use fails closed; release hashes match the manifest.
- Telemetry: not required
- Visual: not required
- Log: not required
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority.
- Regression: Basic consumer fixture, clean-room package, compatibility matrix, Core-only build, and exact rollback.
- Evidence: Consumer source, package manifest/hash, install/start trace, telemetry/screenshot/log where runtime applies, and Harness.

### Step 9.2 — 实现 Creator SDK CLI Alpha

- Implementation: `finish`
- Verification: `verified` — The embedded STATIC+FIXTURE+CONSUMER_MOD contract passed. ProjectPath is now authoritative; init emits a buildable five-definition Hello Ship; PackageManifest and the shared Compiler run in validate/build/test/package; two Windows/CI roots emit byte-identical package, build-report, and Compiler artifacts; actionable version/capability/private-reference/Compiler/tool-lock/drift failures preserve exact last-valid bytes; the reopened Teardown Mod Manager discovered and started the independent SDK Consumer, which displayed PASS for accepted Ship, rejected ExecuteLua, shared Compiler/package hashes, and no Runtime Lua. Evidence: docs/evidence/step-9.2-creator-sdk-cli-alpha.json.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + CONSUMER_MOD`
- Eyes: `none`
- Hands: `HAND_TEST_SETUP`
- Setup: Build a clean-room disposable consumer Mod/package that uses only the published manifest, SDK, schema, or broker surface and no private CM2 include.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 提供 init/validate/build/preview/test/package/clean 命令；[ ] 使用和 Core 相同 Compiler/schema；[ ] 输出稳定错误码、field path、suggestion 和 build report；[ ] 提供模板、示例、锁定工具版本；[ ] CLI 不需要安装完整战场才能构建 Data-only 包。 Build/install twice, reopen Mod Manager, start the consumer, and invoke one valid plus one invalid public operation.
- Reload: `REOPEN_MOD_MANAGER_OR_RESTART_MOD_SESSION` — Reopen Mod Manager for new/metadata Mods and restart the Mod session for runtime changes.
- State assertions: 创作者从模板到 package 的路径无需手工编辑 Runtime catalog。 [ ] clean-room hello-ship 可由 CLI 构建；[ ] Windows/CI 重复产物一致；[ ] 错误可操作；[ ] CLI 可脱离 Editor 运行。 Dependencies, versions, and capabilities are explicit; compatible use succeeds; incompatible use fails closed; release hashes match the manifest.
- Telemetry: not required
- Visual: not required
- Log: not required
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority.
- Regression: Basic consumer fixture, clean-room package, compatibility matrix, Core-only build, and exact rollback.
- Evidence: Consumer source, package manifest/hash, install/start trace, telemetry/screenshot/log where runtime applies, and Harness.

### Step 9.3 — 完成真正独立的 `hello-ship` Clean-room 包

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG + CONSUMER_MOD`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Build a clean-room disposable consumer Mod/package that uses only the published manifest, SDK, schema, or broker surface and no private CM2 include.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 在仓库外或隔离目录创建包；[ ] 只通过公开 schema/SDK 生成一艘单 Body 舰船、一把武器和一个效果；[ ] 不引用 Core 私有文件、相对越界路径或内部 helper；[ ] 安装/构建/Preview/Runtime/卸载全流程记录。 Build/install twice, reopen Mod Manager, start the consumer, and invoke one valid plus one invalid public operation. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `REOPEN_MOD_MANAGER_OR_RESTART_MOD_SESSION` — Reopen Mod Manager for new/metadata Mods and restart the Mod session for runtime changes.
- State assertions: 得到第三方最小可运行包和真实错误清单。 [ ] 无私有引用扫描；[ ] package 可独立 hash/build/install/remove；[ ] 缺依赖和版本不符有清晰失败；[ ] S0/S8 通过。 Dependencies, versions, and capabilities are explicit; compatible use succeeds; incompatible use fails closed; release hashes match the manifest.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Basic consumer fixture, clean-room package, compatibility matrix, Core-only build, and exact rollback.
- Evidence: Consumer source, package manifest/hash, install/start trace, telemetry/screenshot/log where runtime applies, and Harness.

### Step 9.4 — 把 `sync-cm2-to-global.ps1` 演进为 Release Builder

- Implementation: `finish`
- Verification: `verified` — Existing static/fixture evidence satisfies the current contract; rerun the listed regression when an adjacent authority changes.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE`
- Eyes: `none`
- Hands: `HAND_TEST_SETUP`
- Setup: Build a clean-room disposable consumer Mod/package that uses only the published manifest, SDK, schema, or broker surface and no private CM2 include.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 明确 Content source、Global generated target、版本、manifest、hash、清单和 clean output；[ ] 构建前运行入口闭包/schema/asset/预算检查；[ ] 原子生成 Global Mod 发布物；[ ] 禁止 Global 手工修改；[ ] 支持 release/repro/rollback。 Build/install twice, reopen Mod Manager, start the consumer, and invoke one valid plus one invalid public operation.
- Reload: `REOPEN_MOD_MANAGER_OR_RESTART_MOD_SESSION` — Reopen Mod Manager for new/metadata Mods and restart the Mod session for runtime changes.
- State assertions: 发布物由单一构建流程产生，任何拷贝差异都能定位。 [ ] clean build/rebuild byte 一致；[ ] source/global hash 可核验；[ ] failure 不覆盖上次发布物；[ ] 发布 manifest 可追溯。 Dependencies, versions, and capabilities are explicit; compatible use succeeds; incompatible use fails closed; release hashes match the manifest.
- Telemetry: not required
- Visual: not required
- Log: not required
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority.
- Regression: Basic consumer fixture, clean-room package, compatibility matrix, Core-only build, and exact rollback.
- Evidence: Consumer source, package manifest/hash, install/start trace, telemetry/screenshot/log where runtime applies, and Harness.

### Step 9.5 — 建立 Schema/Core/Package 兼容与废弃政策

- Implementation: `finish`
- Verification: `verified` — Embedded STATIC, FIXTURE and CONSUMER_MOD contract passed: 77 compatibility assertions, 11 independent Consumer assertions, retained PackageManifest/SDK regressions, exact hashes/rollback, live Mod discovery/start, attributed log window and emergency-release cleanup are persisted in docs/evidence/step-9.5-compatibility-policy-v1.json.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + CONSUMER_MOD`
- Eyes: `none`
- Hands: `HAND_TEST_SETUP`
- Setup: Build a clean-room disposable consumer Mod/package that uses only the published manifest, SDK, schema, or broker surface and no private CM2 include.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 定义支持矩阵、最低/最高版本、migration 工具、deprecated 周期和错误等级；[ ] 新旧 schema 双读/单写规则；[ ] package/core/sdk 版本协商；[ ] 兼容测试覆盖旧包、缺字段、unknown optional、future required；[ ] 每次废弃有移除日期和 owner。 Build/install twice, reopen Mod Manager, start the consumer, and invoke one valid plus one invalid public operation.
- Reload: `REOPEN_MOD_MANAGER_OR_RESTART_MOD_SESSION` — Reopen Mod Manager for new/metadata Mods and restart the Mod session for runtime changes.
- State assertions: 升级、降级和废弃行为可预测、可诊断、可回滚。 [ ] matrix 文档和自动测试；[ ] migration 幂等；[ ] unsupported version 明确失败；[ ] ledger 有删除证据。 Dependencies, versions, and capabilities are explicit; compatible use succeeds; incompatible use fails closed; release hashes match the manifest.
- Telemetry: not required
- Visual: not required
- Log: not required
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority.
- Regression: Basic consumer fixture, clean-room package, compatibility matrix, Core-only build, and exact rollback.
- Evidence: Consumer source, package manifest/hash, install/start trace, telemetry/screenshot/log where runtime applies, and Harness.

### Step 9.6 — 定义 Expert Custom Behavior API，延后开放

- Implementation: `finish`
- Verification: `needs_regression` — Implementation completion is retained, but evidence predates the autonomous policy or explicitly deferred a now-required live, multiplayer, visual, or consumer-path assertion.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + CONSUMER_MOD`
- Eyes: `none`
- Hands: `HAND_TEST_SETUP`
- Setup: Build a clean-room disposable consumer Mod/package that uses only the published manifest, SDK, schema, or broker surface and no private CM2 include.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 先定义 capability、沙箱、生命周期、网络、性能、错误隔离和版本边界；[ ] 不将任意 Lua、文件系统、网络和 engine handle 直接开放；[ ] 只完成设计/Spike/安全审查，不让其成为 Data-only SDK 前置；[ ] 记录未来 allowlist/审核流程。 Build/install twice, reopen Mod Manager, start the consumer, and invoke one valid plus one invalid public operation.
- Reload: `REOPEN_MOD_MANAGER_OR_RESTART_MOD_SESSION` — Reopen Mod Manager for new/metadata Mods and restart the Mod session for runtime changes.
- State assertions: 明确“可支持的专家行为”边界，或明确结论为暂不支持。 [ ] threat model/ADR；[ ] 最小沙箱 fixture；[ ] 超时/崩溃/越权隔离；[ ] 未通过安全审查时保持关闭。 Dependencies, versions, and capabilities are explicit; compatible use succeeds; incompatible use fails closed; release hashes match the manifest.
- Telemetry: not required
- Visual: not required
- Log: not required
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority.
- Regression: Basic consumer fixture, clean-room package, compatibility matrix, Core-only build, and exact rollback.
- Evidence: Consumer source, package manifest/hash, install/start trace, telemetry/screenshot/log where runtime applies, and Harness.

### Step 9.7 — 独立验证 Global Mod Broker，允许结论为“不采用”

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG + MULTIPLAYER + CONSUMER_MOD`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Build a clean-room disposable consumer Mod/package that uses only the published manifest, SDK, schema, or broker surface and no private CM2 include. Include one identified Host and at least one identified Client.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] Spike Content/Global 加载顺序、Core 缺失、版本不符、卸载、多人和多个 package；[ ] 验证是否能声明依赖并稳定解析；[ ] 不把实验失败转化为永久协议；[ ] 将结论和限制写入 SDK/Editor 文档。 Build/install twice, reopen Mod Manager, start the consumer, and invoke one valid plus one invalid public operation.
- Reload: `REOPEN_MOD_MANAGER_OR_RESTART_MOD_SESSION` — Reopen Mod Manager for new/metadata Mods and restart the Mod session for runtime changes.
- State assertions: 得到采用/不采用 Broker 的实证和清晰限制。 [ ] 所有失败场景可复现；[ ] 加载顺序、缺 Core、卸载、多人结果有记录；[ ] 失败分支被关闭，不残留半套协议。 Dependencies, versions, and capabilities are explicit; compatible use succeeds; incompatible use fails closed; release hashes match the manifest.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Host/Client source, player, owner, generation, and sequence are explicit and converge without duplicate authority mutation.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events. Terminate every test Host/Client child instance and re-enumerate processes to prove no multiplayer process remains.
- Regression: Basic consumer fixture, clean-room package, compatibility matrix, Core-only build, and exact rollback.
- Evidence: Consumer source, package manifest/hash, install/start trace, telemetry/screenshot/log where runtime applies, and Harness.
- Automation gaps: Harness can enumerate Host/Client and control Host, but Client foreground input, screenshot, and per-client telemetry are not yet reliable.

### Step 9.8 — Creator SDK Beta

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG + CONSUMER_MOD`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Build a clean-room disposable consumer Mod/package that uses only the published manifest, SDK, schema, or broker surface and no private CM2 include.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 邀请框架外作者使用 CLI/模板/文档完成武器、效果和单 Body ship；[ ] 收集安装、错误、兼容、Preview、package 和卸载阻断；[ ] 修复高频阻断；[ ] 运行 conformance、S0/S8 和重复构建。 Build/install twice, reopen Mod Manager, start the consumer, and invoke one valid plus one invalid public operation. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `REOPEN_MOD_MANAGER_OR_RESTART_MOD_SESSION` — Reopen Mod Manager for new/metadata Mods and restart the Mod session for runtime changes.
- State assertions: SDK、文档、诊断、多包构建可被 Core 团队之外的作者使用。 [ ] 外部作者 clean-room 成功；[ ] 阻断问题有关闭证据；[ ] 不安装 Editor/AI 仍可构建；[ ] Beta 兼容矩阵发布。 Dependencies, versions, and capabilities are explicit; compatible use succeeds; incompatible use fails closed; release hashes match the manifest.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Basic consumer fixture, clean-room package, compatibility matrix, Core-only build, and exact rollback.
- Evidence: Consumer source, package manifest/hash, install/start trace, telemetry/screenshot/log where runtime applies, and Harness.

### Step 10.1 — 先建立 AI 评测集、权限边界与 Provenance

- Implementation: `finish`
- Verification: `verified` — Existing static/fixture evidence satisfies the current contract; rerun the listed regression when an adjacent authority changes.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE`
- Eyes: `none`
- Hands: `HAND_TEST_SETUP`
- Setup: Use a fixed AI evaluation corpus and disposable consumer output with undeclared network, filesystem, generated, Core, and runtime writes denied.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 覆盖普通、模糊、冲突、超预算、缺资源、恶意路径、要求 Lua、人工已修改字段；[ ] 记录 model/tool version、seed、input、candidate、validator/repair、confidence、人工修改和最终 build hash；[ ] AI 只能写 authoring candidate/JSON Patch；[ ] 禁止写 generated/Core/任意 Lua；[ ] 人工字段有 ownership，AI 不静默覆盖。 Generate twice from identical input, run provenance/schema/policy checks, then preview and package only the accepted candidate through production tools.
- Reload: `NONE_OR_REOPEN_PREVIEW` — Generation is engine-free; reopen Mod Manager or level XML only for consumer preview.
- State assertions: 模型/prompt 更换可比较合法率、返工量、性能风险和来源。 [ ] 评测集版本化；[ ] 权限负面测试全部拒绝；[ ] 每个 artifact 可追溯；[ ] 关闭 AI 后 Editor/CLI/Runtime 完整可用。 Normalized output is deterministic and attributable; no path escape, private code, arbitrary Lua, renderer, or budget bypass occurs.
- Telemetry: not required
- Visual: not required
- Log: not required
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority.
- Regression: AI negative corpus, compiler/schema, asset provenance, package security, and Core semantic invariance.
- Evidence: Prompt/input/provider hashes, normalized diff, validator result, consumer preview screenshot/log, and Harness.

### Step 10.2 — 实现 AI Weapon Assistant

- Implementation: `finish`
- Verification: `needs_regression` — Implementation completion is retained, but evidence predates the autonomous policy or explicitly deferred a now-required live, multiplayer, visual, or consumer-path assertion.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG + CONSUMER_MOD`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Use a fixed AI evaluation corpus and disposable consumer output with undeclared network, filesystem, generated, Core, and runtime writes denied. Use an independent disposable consumer Mod.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 从已注册 behavior/projectile/effect node 生成候选；[ ] 展示 DPS、range、power、projectile/effect budget 和不确定字段；[ ] Validator 只允许合法 Patch 修复；[ ] 保存前显示人工 diff，默认不自动发布；[ ] 流程为自然语言 → WeaponIntent → schema-constrained Patch → deterministic validate/balance/budget lint → source → Compiler → Preview。 Generate twice from identical input, run provenance/schema/policy checks, then preview and package only the accepted candidate through production tools. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `NONE_OR_REOPEN_PREVIEW` — Generation is engine-free; reopen Mod Manager or level XML only for consumer preview.
- State assertions: 用户能用自然语言创建并试射一件使用既有 Runtime 能力的武器。 [ ] 非法引用/越界路径/超预算/任意 Lua 无法绕过；[ ] 100% 保存结果再次通过 Compiler；[ ] S1/S5 性能记录；[ ] 用户可拒绝/编辑候选。 Normalized output is deterministic and attributable; no path escape, private code, arbitrary Lua, renderer, or budget bypass occurs.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. The real path reaches the applicable ordered boundaries: input_edge/fire_request → weapon_released → hit → damage_applied → hp_changed; omitted boundaries require a weapon-specific explanation.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant. Muzzle/beam/projectile/impact appears once at the authoritative anchor and target without obvious clipping or duplicate legacy playback.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: AI negative corpus, compiler/schema, asset provenance, package security, and Core semantic invariance.
- Evidence: Prompt/input/provider hashes, normalized diff, validator result, consumer preview screenshot/log, and Harness.

### Step 10.3 — 实现 AI Effect Assistant

- Implementation: `finish`
- Verification: `needs_regression` — Implementation completion is retained, but evidence predates the autonomous policy or explicitly deferred a now-required live, multiplayer, visual, or consumer-path assertion.
- Automation: `AUTO_WITH_VISUAL_REVIEW`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG + CONSUMER_MOD`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Use a fixed AI evaluation corpus and disposable consumer output with undeclared network, filesystem, generated, Core, and runtime writes denied. Use an independent disposable consumer Mod.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 将自然语言转 effect intent（颜色、时序、emitter、beam、shockwave、sound、shake、LOD）；[ ] 只组合批准节点和参数范围；[ ] 专用 renderer 只能由 Core 专家创建；[ ] 生成多个预算档；[ ] Effect Lab 显示 near/far、request/accepted/degraded 和固定 seed；[ ] 用户选择/编辑后写 source。 Generate twice from identical input, run provenance/schema/policy checks, then preview and package only the accepted candidate through production tools. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `NONE_OR_REOPEN_PREVIEW` — Generation is engine-free; reopen Mod Manager or level XML only for consumer preview.
- State assertions: 复杂表现请求变成受预算、可预览、可版本化 Definition，而非 Lua 粒子脚本。 [ ] 固定 seed/revision 编译结果可重复；[ ] 压力预览 hard cap 生效；[ ] 降级可解释；[ ] provider 不能越权创建 renderer。 Normalized output is deterministic and attributable; no path escape, private code, arbitrary Lua, renderer, or budget bypass occurs.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: AI negative corpus, compiler/schema, asset provenance, package security, and Core semantic invariance.
- Evidence: Prompt/input/provider hashes, normalized diff, validator result, consumer preview screenshot/log, and Harness.
- Automation gaps: AI owns objective visibility, count, clipping, alignment, and budget checks; subjective visual quality remains a human review.

### Step 10.4 — 先实现 Existing-VOX Ship Import Assistant

- Implementation: `finish`
- Verification: `needs_regression` — Implementation completion is retained, but evidence predates the autonomous policy or explicitly deferred a now-required live, multiplayer, visual, or consumer-path assertion.
- Automation: `AUTO_WITH_VISUAL_REVIEW`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG + CONSUMER_MOD`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Use a fixed AI evaluation corpus and disposable consumer output with undeclared network, filesystem, generated, Core, and runtime writes denied. Use an independent disposable consumer Mod.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 基于 AssetManifest 推荐 forward/up、engine、camera、mount、对称组、复杂度和性能 class；[ ] 每项带 confidence、依据、review status；[ ] PCA 只给主轴候选，不自动决定船头；[ ] 3D Editor 逐项确认/修正；[ ] low confidence 阻断自动 build；[ ] 推荐尺度但明确单位和可编辑范围。 Generate twice from identical input, run provenance/schema/policy checks, then preview and package only the accepted candidate through production tools. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `NONE_OR_REOPEN_PREVIEW` — Generation is engine-free; reopen Mod Manager or level XML only for consumer preview.
- State assertions: 减少 VOX 导入机械工作，语义决定仍由人确认。 [ ] Runtime 不含逐体素/AI 分析；[ ] 模糊方向会询问/阻断；[ ] confidence 和依据保存到 provenance；[ ] Editor 修正后重建一致。 Normalized output is deterministic and attributable; no path escape, private code, arbitrary Lua, renderer, or budget bypass occurs.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant. The generated asset/editor surface opens through the real UI path and shows the expected orientation, scale, anchors, controls, and diagnostics.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: AI negative corpus, compiler/schema, asset provenance, package security, and Core semantic invariance.
- Evidence: Prompt/input/provider hashes, normalized diff, validator result, consumer preview screenshot/log, and Harness.
- Automation gaps: AI owns objective visibility, count, clipping, alignment, and budget checks; subjective visual quality remains a human review.

### Step 10.5 — 接入图片/文本到 3D 的外部 Pipeline

- Implementation: `finish`
- Verification: `needs_regression` — Implementation completion is retained, but evidence predates the autonomous policy or explicitly deferred a now-required live, multiplayer, visual, or consumer-path assertion.
- Automation: `AUTO_WITH_VISUAL_REVIEW`
- Profiles: `STATIC + FIXTURE + SCENE + VISUAL + LOG + CONSUMER_MOD`
- Eyes: `EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Use a fixed AI evaluation corpus and disposable consumer output with undeclared network, filesystem, generated, Core, and runtime writes denied. Use an independent disposable consumer Mod.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] AI provider 使用可替换 adapter；[ ] 保存输入、prompt、模型版本、license/provenance、中间 mesh、voxelization 参数和拒绝记录；[ ] mesh cleanup/voxelization/optimization 是确定性或版本化工具；[ ] 发布前检查超体素、断连、薄壁、palette/material；[ ] 失败不覆盖最后有效资产/source；[ ] 流程为图片/文本 → 外部/本地生成 → mesh repair/scale/axis → voxelization → palette/material → connectedness/optimization → AssetManifest → AI anchor suggestions → 人工 Editor review → VehicleDefinition → Compiler/Preview。 Generate twice from identical input, run provenance/schema/policy checks, then preview and package only the accepted candidate through production tools.
- Reload: `NONE_OR_REOPEN_PREVIEW` — Generation is engine-free; reopen Mod Manager or level XML only for consumer preview.
- State assertions: 图片/文本进入一条可替换、有来源记录、有人审查的资产流程。 [ ] provider 可替换；[ ] 任意失败保留最后有效版本；[ ] Runtime 只收到编译后的 VOX/prefab/Definition；[ ] license/provenance 检查可阻断发布。 Normalized output is deterministic and attributable; no path escape, private code, arbitrary Lua, renderer, or budget bypass occurs.
- Telemetry: not required
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant. The generated asset/editor surface opens through the real UI path and shows the expected orientation, scale, anchors, controls, and diagnostics.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: AI negative corpus, compiler/schema, asset provenance, package security, and Core semantic invariance.
- Evidence: Prompt/input/provider hashes, normalized diff, validator result, consumer preview screenshot/log, and Harness.
- Automation gaps: AI owns objective visibility, count, clipping, alignment, and budget checks; subjective visual quality remains a human review.

### Step 10.6 — AI Creator Beta 与质量阈值

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG + CONSUMER_MOD`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Use a fixed AI evaluation corpus and disposable consumer output with undeclared network, filesystem, generated, Core, and runtime writes denied. Use an independent disposable consumer Mod.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 记录 schema 首次/最终合法率；[ ] 平均人工修改字段数；[ ] prompt→首次 Preview 时间；[ ] 超预算拒绝/降级率；[ ] 坐标/anchor 返工次数；[ ] 查看 Lua 次数（目标 0）；[ ] 生成内容在 S1/S5 的预算表现；[ ] 明确可自动完成与必须人工确认的任务。 Generate twice from identical input, run provenance/schema/policy checks, then preview and package only the accepted candidate through production tools. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `NONE_OR_REOPEN_PREVIEW` — Generation is engine-free; reopen Mod Manager or level XML only for consumer preview.
- State assertions: 得到创作效率、返工、合法率和预算风险的真实数据，形成明确自动化边界。 [ ] 指标有样本量/阈值/版本；[ ] 每个 Beta artifact 通过完整 Compiler/Preview/Harness；[ ] S1/S5 不突破预算；[ ] AI 可关闭且项目仍可维护。 Normalized output is deterministic and attributable; no path escape, private code, arbitrary Lua, renderer, or budget bypass occurs.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: AI negative corpus, compiler/schema, asset provenance, package security, and Core semantic invariance.
- Evidence: Prompt/input/provider hashes, normalized diff, validator result, consumer preview screenshot/log, and Harness.

### Step 11.1 — 建立 End-to-end Golden Packages

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG + CONSUMER_MOD`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Use immutable release candidates and independent consumer Mods for baseline, upgrade, rollback, S0–S8, and required soak topologies.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 覆盖全部内置内容；[ ] `hello-ship`；[ ] 前一 Schema 版本；[ ] 合法多包依赖 DAG；[ ] 缺依赖/循环/重复 ID/路径越界/asset hash mismatch/超预算包；[ ] 受信任 Expert Behavior 包；[ ] AI 生成后人工批准的 Weapon/Effect/Ship 包；[ ] 每次 Core/Schema/Compiler 升级跑构建、迁移、Preview、Runtime 回归。 Run every gate from a clean install, execute live single-player and required Host/Client scenarios, then repeat after upgrade and exact rollback. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `RESTART_TEARDOWN_AND_MOD_SESSION` — Restart Teardown between immutable package versions and restart all multiplayer processes for each topology.
- State assertions: Core、Schema、Compiler、SDK、Editor、AI 变化有统一跨层语料，升级问题在发布前暴露。 [ ] Golden 集合版本化；[ ] 失败消息稳定、可操作；[ ] 所有包可构建/迁移/Preview/运行；[ ] 缺包和恶意输入不越权。 All component and negative gates pass; live samples are not fixtures; package/save compatibility and exact rollback hashes hold; missing evidence remains no-go.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Golden packages, S0–S8, lifecycle/save soak, p95/p99 budgets, clean-room consumers, upgrade/rollback, support, and security gates.
- Evidence: Immutable hashes, machine identity, live telemetry/screenshots/logs/replays, per-gate reports, sign-off, and Harness.

### Step 11.2 — 执行多人、存档和生命周期 Soak

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG + MULTIPLAYER + CONSUMER_MOD`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Use immutable release candidates and independent consumer Mods for baseline, upgrade, rollback, S0–S8, and required soak topologies. Include one identified Host and at least one identified Client.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] Host+remote 配置、锁定、开火、炮塔、死亡、重生、late join；[ ] 反复生成/销毁 Ship/Projectile/Craft/Effect/Joint；[ ] 保存/加载 Loadout/Package revisions、缺包和降级；[ ] 30 分钟及更长 soak，记录 queue、owner lease、memory、stale handle。 Run every gate from a clean install, execute live single-player and required Host/Client scenarios, then repeat after upgrade and exact rollback. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `RESTART_TEARDOWN_AND_MOD_SESSION` — Restart Teardown between immutable package versions and restart all multiplayer processes for each topology.
- State assertions: 长时间多客户端、多次生成、版本化存档不积累孤儿状态。 [ ] warmup 后 memory/active count 平台化；[ ] stale handle/lease=0 或有明确可回收队列；[ ] 版本不一致明确失败；[ ] 重连/late join 收敛。 All component and negative gates pass; live samples are not fixtures; package/save compatibility and exact rollback hashes hold; missing evidence remains no-go.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Host/Client source, player, owner, generation, and sequence are explicit and converge without duplicate authority mutation.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events. Terminate every test Host/Client child instance and re-enumerate processes to prove no multiplayer process remains.
- Regression: Golden packages, S0–S8, lifecycle/save soak, p95/p99 budgets, clean-room consumers, upgrade/rollback, support, and security gates.
- Evidence: Immutable hashes, machine identity, live telemetry/screenshots/logs/replays, per-gate reports, sign-off, and Harness.
- Automation gaps: Harness can enumerate Host/Client and control Host, but Client foreground input, screenshot, and per-client telemetry are not yet reliable.

### Step 11.3 — 建立持续性能回归门禁

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG + MULTIPLAYER + CONSUMER_MOD`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Use immutable release candidates and independent consumer Mods for baseline, upgrade, rollback, S0–S8, and required soak topologies. Include one identified Host and at least one identified Client.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] Runtime PR 跑相关 S0–S8，里程碑/夜间跑全部压力和 Soak；[ ] 未声明性能换功能时 p95 暂不恶化 5%、p99 不恶化 10%；[ ] Query、active entity、budget reject、queue depth、network bytes、memory slope 是发布指标；[ ] 方差过大先修场景，不挑最好一次；[ ] 预算调整必须有 ADR、参考硬件和 before/after replay。 Run every gate from a clean install, execute live single-player and required Host/Client scenarios, then repeat after upgrade and exact rollback.
- Reload: `RESTART_TEARDOWN_AND_MOD_SESSION` — Restart Teardown between immutable package versions and restart all multiplayer processes for each topology.
- State assertions: 性能成为版本化产品合同，未经批准的回归阻止合并/发布。 [ ] 基准环境和阈值有历史；[ ] 自动门禁可阻断回归；[ ] 例外有 owner、期限和 ADR；[ ] 指标误差/方差受控。 All component and negative gates pass; live samples are not fixtures; package/save compatibility and exact rollback hashes hold; missing evidence remains no-go.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Host/Client source, player, owner, generation, and sequence are explicit and converge without duplicate authority mutation.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events. Terminate every test Host/Client child instance and re-enumerate processes to prove no multiplayer process remains.
- Regression: Golden packages, S0–S8, lifecycle/save soak, p95/p99 budgets, clean-room consumers, upgrade/rollback, support, and security gates.
- Evidence: Immutable hashes, machine identity, live telemetry/screenshots/logs/replays, per-gate reports, sign-off, and Harness.
- Automation gaps: Harness can enumerate Host/Client and control Host, but Client foreground input, screenshot, and per-client telemetry are not yet reliable. Authoritative frame-time, GC, query, and allocation telemetry must be completed and baselined before the performance claim is fully automatic.

### Step 11.4 — 执行一次真实的版本升级与回滚演练

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG + CONSUMER_MOD`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Use immutable release candidates and independent consumer Mods for baseline, upgrade, rollback, S0–S8, and required soak topologies.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 发布内部 v1 Core/Schema/SDK 与三个扩展包；[ ] 做真实 v2 schema/core 变更与 migration；[ ] 升级包、存档、generated artifacts 并验证 semantic golden；[ ] 回滚 Runtime/包版本，验证错误和兼容策略；[ ] 记录耗时/人工步骤/失败点，修工具后再次演练。 Run every gate from a clean install, execute live single-player and required Host/Client scenarios, then repeat after upgrade and exact rollback.
- Reload: `RESTART_TEARDOWN_AND_MOD_SESSION` — Restart Teardown between immutable package versions and restart all multiplayer processes for each topology.
- State assertions: 第三方 source、存档和 generated artifact 在真实升级中可恢复。 [ ] migration 单命令、幂等、可诊断；[ ] rollback 不破坏 source；[ ] 旧 Core 不静默误读未来数据；[ ] 第二次演练无需临时手工修复。 All component and negative gates pass; live samples are not fixtures; package/save compatibility and exact rollback hashes hold; missing evidence remains no-go.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Golden packages, S0–S8, lifecycle/save soak, p95/p99 budgets, clean-room consumers, upgrade/rollback, support, and security gates.
- Evidence: Immutable hashes, machine identity, live telemetry/screenshots/logs/replays, per-gate reports, sign-off, and Harness.

### Step 11.5 — 发布物与支持边界分离

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `FULL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + TELEMETRY + VISUAL + LOG + CONSUMER_MOD`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_TEST_SETUP`
- Setup: Use immutable release candidates and independent consumer Mods for baseline, upgrade, rollback, S0–S8, and required soak topologies.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 拆分 Core Runtime、Creator CLI/Compiler、External Editor、Preview Mod、Schema/API 文档、Templates/Examples、Conformance Test Kit、可选 AI provider；[ ] 每个发布物有版本/兼容范围/安装/支持文档；[ ] 文档覆盖五分钟武器、单 Body VOX、ID/坐标/Anchor/Turret、Effect/Projectile/Joint 预算、兼容矩阵、错误码、发布/升级/回滚/卸载、Data-only/Expert 边界、AI provenance/license；[ ] 不安装 AI/Editor 仍可构建相应包。 Run every gate from a clean install, execute live single-player and required Host/Client scenarios, then repeat after upgrade and exact rollback.
- Reload: `RESTART_TEARDOWN_AND_MOD_SESSION` — Restart Teardown between immutable package versions and restart all multiplayer processes for each topology.
- State assertions: 玩家 Runtime 极简，创作者按需安装工具，各发布物有清晰支持边界。 [ ] 发布物依赖图无循环；[ ] 版本和下载内容可核验；[ ] Core/CLI/Editor/Preview/AI 可独立按声明工作；[ ] 文档用 clean-room 读者验证。 All component and negative gates pass; live samples are not fixtures; package/save compatibility and exact rollback hashes hold; missing evidence remains no-go.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events.
- Regression: Golden packages, S0–S8, lifecycle/save soak, p95/p99 budgets, clean-room consumers, upgrade/rollback, support, and security gates.
- Evidence: Immutable hashes, machine identity, live telemetry/screenshots/logs/replays, per-gate reports, sign-off, and Harness.

### Step 11.6 — 正式平台发布门槛

- Implementation: `unable`
- Verification: `pending` — Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.
- Automation: `PARTIAL_AUTO`
- Profiles: `STATIC + FIXTURE + SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG + MULTIPLAYER + CONSUMER_MOD`
- Eyes: `EYE_TELEMETRY + EYE_SCREENSHOT + EYE_LOG`
- Hands: `HAND_REAL_INPUT + HAND_TEST_SETUP`
- Setup: Use immutable release candidates and independent consumer Mods for baseline, upgrade, rollback, S0–S8, and required soak topologies. Include one identified Host and at least one identified Client.
- Trigger: Exercise the minimum operation that proves this exact implementation scope: [ ] 建立 go/no-go 清单；[ ] 检查第三方 clean-room 包、Golden、S0–S8、多人/存档 Soak、性能 p95/p99、升级回滚、入口闭包、资产 provenance、支持文档和安全边界；[ ] 任一关键项不满足时继续以 Framework/Beta 发布；[ ] 记录发布决策、已知限制和下一版计划。 Run every gate from a clean install, execute live single-player and required Host/Client scenarios, then repeat after upgrade and exact rollback. Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.
- Reload: `RESTART_TEARDOWN_AND_MOD_SESSION` — Restart Teardown between immutable package versions and restart all multiplayer processes for each topology.
- State assertions: 得到明确、可审计的正式发布决定和已知限制清单。 [ ] 所有 required gate 勾选；[ ] no-go 条件可阻断发布；[ ] 发布包 hash、版本、兼容矩阵和回滚资产齐全；[ ] 负责人和复核人签字。 All component and negative gates pass; live samples are not fixtures; package/save compatibility and exact rollback hashes hold; missing evidence remains no-go.
- Telemetry: Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate. Host/Client source, player, owner, generation, and sequence are explicit and converge without duplicate authority mutation.
- Visual: A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant.
- Log: No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed.
- Cleanup: Dispose temporary fixtures and preserve the formal source plus last valid generated authority. Release every tracked key/button with emergency release and confirm the held-input set is empty. Confirm the next session contains no stale scenario entities, registrations, cursors, or events. Terminate every test Host/Client child instance and re-enumerate processes to prove no multiplayer process remains.
- Regression: Golden packages, S0–S8, lifecycle/save soak, p95/p99 budgets, clean-room consumers, upgrade/rollback, support, and security gates.
- Evidence: Immutable hashes, machine identity, live telemetry/screenshots/logs/replays, per-gate reports, sign-off, and Harness.
- Automation gaps: Harness can enumerate Host/Client and control Host, but Client foreground input, screenshot, and per-client telemetry are not yet reliable.
