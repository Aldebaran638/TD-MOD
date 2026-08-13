# Bounded Interceptor Runtime v1

## 目标与边界

`cm2InterceptorRuntimeV1` 为舰载机/拦截导弹提供一个可观测、可限额、可回收的生命周期边界。它把 target selection、flight、intercept、impact、presentation 和 finish 分成明确入口，但不在本版本夺取旧 strike-craft controller 的权威。`legacy` 是默认模式；`shadow`/`runtime` 只能由受控初始化配置启用。

生产上限保持每舰 4 架、全场 24 架。Think 默认 5 Hz、update 默认 30 Hz，每 tick 最多处理 4 个 target think 和 24 个 flight update。超出预算只记录 `thinkBudgetRejected`/`updateBudgetRejected`，不创建无界队列，也不循环补偿。

## 生命周期

1. `register` 验证 owner、generation 和容量，建立稳定 phase、位置/速度和可选 ProjectileLifecycle handle。
2. `selectTarget` 优先调用 Target Catalog 的稳定 `query`；候选必须有 identity、generation 且未 disabled/destroyed。无候选转为 `return` 并记录 target loss。
3. `serverTick` 按固定 think/update 时钟调用 target selection 和 flight adapter；每帧排序 ID，确保预算和执行顺序可重放。
4. `intercept` 再次校验目标 generation；命中进入 `impact`，失效目标进入确定性的 `return`。
5. `impact` 通过 ProjectileLifecycle 的 `collide/finish/destroy` DTO 边界，并经 PresentationPublisher 发出唯一表现事件。
6. `finish` 幂等删除运行时实例；`ownerDestroyed` 和 `sceneReload` 批量结束所有相关实例并推进 generation，防止 Body ID 重用造成 stale entity。

## 接线与回退

通用 ship server bootstrap 载入模块，`strikeCraftMain` 在初始化和 server tick 建立生命周期钩子。初始化仍传入 `mode = legacy`，所以旧飞行/伤害/表现路径保持行为权威。若 S3 命中、回收、owner cleanup 或表现计数出现差异，保持 `legacy` 或调用 `setMode("legacy")`，保留 synthetic replay 和诊断，不让新旧控制器同时结束同一实例。

## 验证限制

离线 fixture 覆盖容量拒绝、generation stale、目标丢失、命中、owner dead、scene reload、幂等 finish、固定 think/update budget 和 3-event synthetic replay。runner/self-test 只证明 DTO/lifecycle 规则与预算；本机没有 Teardown.exe，无法证明 S3 24 craft 的物理飞行、真实 Target Catalog 查询、视觉回收、Query/CPU p95/p99 或 GC 曲线，均须在真机压力场景补证。
