# Content Mod 2 架构决策记录

本文件是 Gate 0 的冻结记录。它描述的是“以后代码必须遵守的边界”，不是对旧代码现状的猜测。任何改变下列决策的 PR 都必须先更新对应 ADR、迁移账本和 source-of-truth 检查，再改实现。

## 评审与状态

- 记录集：ADR-0001 至 ADR-0006
- 状态：Accepted（2026-08-10 冻结）
- 评审人：项目负责人：____；运行时负责人：____；工具负责人：____
- 冻结范围：`Content Mod 2` 的源码、生成 `Global Mod` 的发布边界、Teardown Lua/XML 入口、网络/表现/实体/性能合同。
- 例外：只允许修复阻断构建或安全问题；例外必须在 `docs/migration-ledger.md` 增加一条记录，并在下一次 Gate 评审前消除。

## ADR-0001：脚本 context 归属

**上下文**：Teardown 会加载多个 Lua 入口；共享 client/server namespace 使无归属的全局表和回调发生实例串写。

**决策**：脚本按 `context / responsibility / classification / implementation` 分层。实例状态必须挂在稳定的 `shipBody`、`vehicleId` 或实体 ID 下；跨实例共享的只读定义放入 Definition catalog；不得用未命名全局表承载某一艘船的运行态。入口闭包由 `harness/check-entry-closures.ps1` 验证。

**后果**：调用方需要显式传递 owner/context；迁移早期会有适配器，但不会把适配器当作新的事实来源。

**移除/解冻条件**：只有在所有调用方完成 namespace 审计、并通过 host/remote 与多实例 smoke 后，才可删除旧的无 owner 全局状态。

**负责人/调用者/Parity**：Runtime owner：____；调用方由迁移账本登记；Parity：S0、S6、S7 smoke + Lua fixture。

## ADR-0002：Definition source 与 build 产物分离

**上下文**：手工维护 `Content Mod 2` 与 `Global Mod` 会产生漂移，生成 catalog 和入口可能引用不同版本。

**决策**：`Content Mod 2` 是唯一产品源码；`Global Mod` 只允许作为生成/发布目标。机器可读声明位于 `docs/source-of-truth.json`，并由 `harness/check-source-of-truth.ps1` 在 Harness 早期阶段检查。生成器必须从 Content 读取 Definition，写入 Global；禁止手工在 Global 建立独立演化路径。

**后果**：Global 的临时修复必须回写 Content 后重新生成；发布包必须保留 source revision 和生成时间。

**移除/解冻条件**：在生成器、差异报告、可回滚产物和一次完整发布演练存在前，不得把 Global 宣称为源码。

**负责人/调用者/Parity**：Build owner：____；调用者：生成器/发布脚本；Parity：source manifest 检查 + 生成前后 catalog diff。

## ADR-0003：坐标、ID 与版本决策的前置约束

**上下文**：旧数据用无 namespace 字符串和隐式坐标；编辑器、AI、运行时无法可靠判断来源、父节点和版本。

**决策**：ID、schemaVersion、canonical frame 和 transform 合同由 Gate 1 的 ADR-0010 承载；Gate 0 只冻结“必须有单一合同、不能继续隐式归一化”的治理边界。任何新 Definition 必须包含可追溯的 package/source revision，禁止新写裸字符串 ID。

**后果**：旧 ID 通过只读 alias 过渡；alias 不能成为持久化主键。

**移除/解冻条件**：Gate 1 的 schema/transform golden snapshot 通过后，才可将新 compiler 输出切换为唯一运行时输入。

**负责人/调用者/Parity**：Schema owner：____；调用者：compiler、editor、runtime；Parity：Gate 1 golden cases。

## ADR-0004：world owner 与生命周期

**上下文**：飞船、武器、投射物、舰载机和表现效果可能跨 server/client 产生，死船仍有 tick 或 FX 会造成泄漏。

**决策**：每个运行时对象必须声明唯一 world owner 和 parent/owner ID；权威状态在 server，client 只接收快照或 PresentationEvent。对象创建、更新、销毁和 dead-owner 清理必须可追踪；禁止依赖“某个脚本实例自然结束”作为销毁机制。

**后果**：事件需要带 owner/entity/lifecycle 字段；删除旧轮询前必须证明事件和清理路径覆盖同一语义。

**移除/解冻条件**：S6 死船场景证明武器、导弹、舰载机、回调、声音和粒子均停止或转移后，才可删除旧 owner 兼容分支。

**负责人/调用者/Parity**：World owner：____；调用者：ship registry、effect runtime、projectile manager；Parity：S6 + active entity counter。

## ADR-0005：extension packaging

**上下文**：第三方扩展需要加入舰船、武器、效果和定义，但不应修改 Core 或复制整棵目录。

**决策**：扩展以 package manifest + namespaced Definition + 明确入口注册；Core 只提供稳定 broker/SDK 边界。扩展不能覆盖 Core 文件，不能依赖 Global 的手工副本；未冻结的 broker 不得在 SDK 文档中承诺。

**后果**：加载顺序、冲突和权限必须由 manifest 明确；扩展失败要降级为 unknown/deprecated，而不是阻断基础飞船。

**移除/解冻条件**：Gate 9 的最小第三方包通过安装、冲突、回滚和版本不匹配测试后，才可扩大扩展 API。

**负责人/调用者/Parity**：SDK owner：____；调用者：package loader/compiler；Parity：extension fixture + package hash。

## ADR-0006：性能预算与可观察性

**上下文**：仅看 FPS 无法区分 Query、Registry、FX、音频、Joint、孤儿实体和 GC 的增长来源。

**决策**：诊断默认关闭，热路径只允许整数累加；启用时按秒快照 counters/timings/active owner counts。Gate 0 记录预算目标：96 枚导弹、24 架 craft、500 个弹体压力场景；任何超预算必须给出 owner、增长曲线和回滚方案。`network_debug.lua` 是最小实现，后续 subsystem 只能通过 API 记录。

**后果**：诊断数据可用于定位但不能改变游戏语义；没有 Teardown 实机时只能标记 unable，不能伪造 overhead 结论。

**移除/解冻条件**：S0–S7 和压力场景取得关闭/开启对照、实体不增长、回收完整、预算达标的记录后，才可把阶段从观测冻结改为优化冻结。

**负责人/调用者/Parity**：Performance owner：____；调用者：各 subsystem；Parity：`harness/test-network-debug.ps1` + smoke/pressure record。

## 冻结与解冻规则

| Gate | 默认状态 | 允许的变更 | 解冻证据 |
|---|---|---|---|
| Gate 0（本记录） | 冻结 | 入口修复、检查器、诊断、文档和阻断构建的最小修复 | 0.1–0.5 有状态和证据；入口闭包、Harness、自测通过 |
| Gate 1 | 冻结 | schema/ID/compiler MVP 的纵切，不改变未迁移旧事实来源 | 1.1–1.7 golden snapshot、候选纵切和 shadow catalog 通过 |
| Gate 2+ | 按迁移账本逐条解冻 | 只对指定 owner/路径迁移；旧路径仍需 parity | 对应 ledger 行的 removal gate、smoke、回滚记录齐全 |

解冻申请必须说明：ADR 编号、影响范围、旧/新事实来源、调用者清单、parity 测试、smoke/性能证据、回滚点和重新冻结时间。未满足条件时，状态只能是 `unable`，不可把文档状态写成 `finish`。

