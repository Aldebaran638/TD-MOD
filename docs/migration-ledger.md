# Content Mod 2 迁移账本

本账本记录 legacy/new 双轨的事实来源、调用者、负责人、Parity 和删除门槛。每次迁移 PR 必须更新对应行；没有证据的行不得标记为 Removed。路径是当前仓库扫描到的候选或历史记录，若实际不存在也要保留条目并注明 `not_found`，防止问题被“扫掉”。

## 账本状态定义

- `legacy-active`：仍被运行时调用，不能删除。
- `shadow`：新路径已存在，旧路径仍作为对照或回滚。
- `migrated`：运行时已切换，新旧 parity 已记录，允许进入删除评审。
- `removed`：删除门槛完成并有回滚产物。
- `not_found`：文档/计划要求登记，但仓库当前未发现实体；仍需在下一次扫描确认。

## 双轨登记

| ID | 旧事实来源/路径 | 新事实来源/目标 | 当前状态 | Owner | 当前调用者 | Parity test | Removal gate / 回滚 |
|---|---|---|---|---|---|---|---|
| ML-001 | `Content Mod 2/script/weapon/client/presentation/visual/runtime/registry/effect_profile_registry.lua`、`palette_profile_registry.lua` | Effect Runtime profile/catalog（Gate 2） | legacy-active | Effect owner：____ | `effect_dispatch.lua` 与表现模块 | S0/S6 FX 计数、事件序列 | 事件覆盖全部消费者且无 registry 读取；保留上一版 catalog |
| ML-002 | 历史 profile registry keys（具体键见 `Content Mod 2/docs/registry_migration_notes.md`） | 按 owner 的 definition/runtime state | migrated/shadow | Runtime owner：____ | ship snapshot、weapon state | registry 与 local state golden snapshot | 连续两个版本无读取；恢复旧 snapshot API |
| ML-003 | 具名 `ClientCall` 分散调用（如 `Global Mod/script/weapon/server/guided/slot_group.lua`） | 版本化 PresentationEvent broker（Gate 2） | legacy-active | Network owner：____ | guided slot、FX、HUD | host/remote 事件顺序与去重 | 所有事件有 owner/entity/lifecycle；保留 broker adapter |
| ML-004 | slot 专用状态机：`Content Mod 2/script/weapon/server/slot/`、`Global Mod/script/weapon/server/slots/` 及 `script_titan`/escort 复制路径 | 统一 slot/behavior runtime（Gate 2/5） | shadow | Weapon owner：____ | M/G/H/L/X/T 控制与 projectile manager | 每槽位 fire/stop/dead-owner case | 新 runtime 覆盖所有 slotTypes 后删除重复 controller |
| ML-005 | `Content Mod 2/script_riddle_escort/`、`Global Mod/script_riddle_escort/`、`Global Mod/script_titan/` 的独立运行时副本 | Content source 生成的 extension/ship package | legacy-active | Packaging owner：____ | escort/titan 入口 | 包 hash、入口 closure、S6 | 生成器可重建且回滚包可安装；禁止手工覆盖 |
| ML-006 | 根 Body mount API/隐式 mount 偏移（`Content Mod 2/script/data/ships/*/*_mounts.lua`） | parentId + localTransform + canonical anchor compiler（Gate 1/6） | legacy-active | Asset owner：____ | ship definitions、weapon loadout | root/shape/parent/mirror golden cases | importer/compiler 双读一致；保留旧坐标 alias |
| ML-007 | `Content Mod 2/script/server/registry/shipRegistryRequest.lua` 中遗留 request/snapshot keys | owner-scoped request endpoint/runtime state | migrated/shadow | Ship owner：____ | movement、weapon command、driver sync | forged request、dead ship、host/remote | 两版均可回放且旧 key 无读取后移除 |
| ML-008 | `Content Mod 2/script/weapon/client/config_ui/`（已由入口迁移，superseded） | `Content Mod 2/script/weapon/client/interaction/config/` | migrated | Interaction owner：____ | `main.lua`、ship client bootstrap | entry closure + Step 0.1 UI smoke S0 | 实机新路径已由 Step 0.1 证据确认；回滚为两条 include |

## Source of truth 与发布纪律

1. `docs/source-of-truth.json` 是机器可读声明；`harness/check-source-of-truth.ps1` 在完整 Harness 中执行。
2. `Content Mod 2` 是产品源码和 Definition source；`Global Mod` 是生成/发布目标，不接受手工独立演化。
3. 生成产物必须记录 source revision、generator revision、package hash 和生成时间；没有这些字段的包不能作为回滚点。
4. 发现 Global 与 Content 不一致时，先停止发布、保存差异和上一份有效包；不得直接在 Global 热修后继续开发。

## 迁移 PR 清单

每个迁移 PR 描述必须填满以下字段：

- Ledger ID / ADR ID：____
- 旧路径、全部 callers、owner：____
- 新路径、source revision、generated package hash：____
- Parity fixture、Harness 输出、S0/S6/S7 smoke record：____
- 性能 counters/timings 与预算结论：____
- removal gate、回滚版本、恢复步骤：____
- 未完成项必须写 `unable` 原因和恢复条件，不能写“已验证”。

## Gate 评审记录

| 评审 | 日期 | 结论 | 未完成项/恢复条件 | 签名 |
|---|---|---|---|---|
| Gate 0 | 2026-08-10 | 进行中；0.1–0.4 已登记，0.5 文档/检查器待本次验证 | Teardown 实机和性能证据待可执行文件恢复 | ____ |
| Gate 1 | ____ | 未开始 | 依赖 Gate 0 通过 | ____ |
