# Hotpath Budget v1

## 审计结论

本轮把固定浪费分成三类：projectile manager 每次 spawn 创建新 record、point-defense 每次候选刷新创建新数组/顶层 DTO、以及临时计数/孤儿清理没有统一上限。没有通过关闭武器、降低伤害或跳过碰撞来“制造”性能数字。

## 改造

- `hotpath_budget_v1.lua` 提供有上限的可复用 buffer、整数 counter 和 begin/batchOperation/end 批处理边界；超过 `maxBuffers`/`maxCounterKeys` 会记录拒绝，不产生无界日志或表。
- `projectile/manager.lua` 保留 `active` dense swap-remove，同时将结束的 projectile record 放进 `free` pool；下一次 spawn 复用 record，reset 只清空 active 并保留 pool。
- `point_defense/allocator_v1.lua` 按 ship 复用候选 buffer，使用 `_cloneInto` 覆写已有 DTO，候选刷新在一个 batch 中计数，清理 ship 时释放 buffer。
- 所有优化都在原有命中、排序、cooldown、生命周期和表现路径之内；Hotpath module 没有自己的“禁用功能”开关。

## Before/After replay

fixture 使用 120 个 96-record projectile churn、12 次 64-candidate refresh、40 个 orphan cleanup 和 129 个 counter key 尝试。离线结果应显示首轮只创建 96 个 projectile record，后续复用至少 11,424 次；候选 buffer 只创建 1 次并复用至少 11 次；孤儿处理从 40 个独立 pass 变为一个 40-operation batch；第 129 个 counter 被明确拒绝。行为 trace（spawn/sweep/shield-check/impact/finish 与 query/sort/allocate/cooldown）必须字节级保持不变。

## 真机证据与回退

当前没有 Teardown.exe，因此 p95/p99 CPU、Query、GC、内存 slope 和 S0–S5 压力只能标记为 `requires-live-Teardown`。若真机 replay 出现命中、顺序或生命周期差异，可分别 revert projectile pool、candidate buffer 或 batch cleanup；保留 `cm2HotpathBudgetV1` 诊断，恢复旧临时 table 实现，不改变业务预算来掩盖问题。
