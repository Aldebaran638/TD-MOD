# Guided Collision Budget v1

## 目标

导引弹碰撞器保留原来的五次 `Query` 路径，同时提供一个可回滚的预算规划器。预算模式以每枚弹的上一帧位置、当前帧位置和速度为输入，优先做一次连续扫掠；仅在首次接触确认或进入临界区时追加一次 `QueryClosestPoint`。这样可以把 96 枚导引弹的常态查询量控制在约 3,000/s，并为尖锐转向、近距离、预计即将碰撞和超速状态保留额外检查。

## 调度契约

- `cm2GuidedCollisionBudgetV1.serverInit(generation, options)` 初始化代际、平均预算、硬预算、扫掠频率和临界阈值。
- `setMode("legacy"|"budgeted")` 是唯一的运行时切换点；生产默认值是 `legacy`。
- `plan(...)` 是每枚弹每帧唯一的计划入口。规划器以固定种子计算 phase，并累加 sweep/closest 两个定时器。
- 预算模式的一般帧最多发出一次连续扫掠；首次接触、距离 ≤ 40 m、预计碰撞时间 ≤ 0.25 s、转向或速度 ≥ 240 m/s 时提升为临界计划。
- 平均窗口超限时标记 `degraded` 并跳过本帧查询；硬预算超限时标记 `queryRejected`。规划器不会在同一帧自动重试，调用方记录一次潜在漏检并继续飞行状态。
- `recordHit`、`recordPotentialMiss`、`getDiagnostics` 提供可回放的命中、漏检、降级和窗口峰值证据。

## 碰撞路径

`collider.lua` 只有在诊断模式为 `budgeted` 时调用预算分支：先在当前头部做一次近点确认（若计划要求），再以 `prePhysicsCenterPos -> currentProbes.center` 做一次 swept raycast。未命中不会循环重试。模式不是 `budgeted` 时完整保留原来的头部/中部近点加三段扫掠，共五次 `Query`，因此可在发现漏检时立即回滚。

每枚弹的 planner 状态在 `guidedProjectileRemoveAt` 和 `guidedProjectileClearAll` 中清理，避免场景重载或弹体销毁后残留预算状态。

## 验证与限制

离线 runner 覆盖 96 枚、60 Hz、直线、急转、近碰撞、超速、平均/硬预算过载、无重试和 legacy 五查询黄金。它验证调度契约、静态接线和预算计数，但不能替代 Teardown 真机的 `Query` 性能、p95/p99 帧时、穿透金样或视觉回放；当前工作区没有 `Teardown.exe`，因此这些证据标记为 `requires-live-Teardown`。

## 回滚

不修改武器定义即可执行：保持 `cm2GuidedCollisionBudgetV1` 为 `legacy`，或在受控诊断入口调用 `setMode("legacy")`。回滚后碰撞器恢复五次 Query 逻辑；预算器仍可读取诊断数据而不改变命中结果。
