# VehicleInstance v1

## 目标

`cm2VehicleInstanceV1` 将现有单根 Body 包装成显式 VehicleInstance。它定义 identity、definition、owner、generation、root body、lifecycle、health、input revision、mount revision 和 capability 集合；物理布局与现有 Body/Shape/Joint 不变，旧 `cm2ShipInstanceAdapterV1` 仍负责 World Host 注册与 heartbeat。

## 边界与入口

- `serverInit` 先复用已有 ShipInstance adapter，再建立本地 VehicleInstance snapshot；Body handle 只在服务端持有，跨边界只输出稳定 `bodyId`。
- `validateHandle` 同时校验 identity、owner、generation、bodyId 和 disposed 状态，拒绝 Body ID 重用后的 stale handle。
- `setHealth`、`setInputRevision`、`setMountRevision` 和 `resolveMount` 是后续 lifecycle/health/input/mount 迁移的窄门；mount resolver 返回 identity+generation 包装结果。
- `serverTick` 通过 adapter heartbeat，并读取现有 Registry health；destroyed 时按 `destroyed -> disposed` 终止，避免残留实例。
- `snapshot` 是行为对照 DTO，明确 root Body 仍为实现细节，不改变物理布局。

## 接线与回退

`shipMain` 和 `strikeCraftMain` 的 server init/tick 已经改为 VehicleInstance 入口；client adapter 与旧 movement/damage/weapon controller 不变。若运行时发现 identity、owner、health 或 heartbeat 差异，可旁路 `cm2VehicleInstanceV1`，恢复原来的 `cm2ShipInstanceAdapterV1.serverInit/serverTick`，保留 snapshot 和 generation negative fixture 作为回归证据。

## 验证限制

离线 fixture 覆盖 stable identity、owner/generation/body handle、health/revision、mount capability、destroy/dispose 和 stale/owner reject。当前没有 Teardown.exe，因此 S0/S6 真机重载、destroyed body、health 与输入/mount snapshot parity 仍需在 smoke matrix 中补证。
