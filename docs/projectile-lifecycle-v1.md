# Unified Projectile Lifecycle 与 Logical Dense Store v1

## 定位与兼容

`Content Mod 2/script/weapon/server/behavior/projectile/lifecycle_api_v1.lua` 定义
Projectile 的统一生命周期边界，`weapon/server/bootstrap.lua` 只负责把它作为可选
adapter 接入；现有 `projectile/manager.lua` 仍是默认 legacy engine backend。新 API
先用于 synthetic/replay、shadow 和诊断，未在没有 Teardown 实机时替换真实伤害路径。

## DTO 与生命周期

`spawn(definitionId, FireContext, backend)` 的 FireContext 只含 ownerId、seed、origin、
direction、velocity、lifetime、targetEntityId/targetGeneration、damage、priority 和
impactEventId 等可序列化字段。禁止 Definition 原表、engine/body/shape/joint handle、
函数和 callback。backend 显式限制为 `hitscan`、`logicalSwept`、`kinematicBody`、
`physicalBody`。

统一状态序列为：

```text
spawn -> active -> update/correct -> colliding -> finish(reason, hit) -> destroy
                         \\-> ttl/owner-destroyed/scene-reload finish -> destroy
```

- `update` 修改位置、速度、flightRemain 和 target；`correct` 记录修正后回到 active。
- `collide` 只记录可序列化 impact DTO；伤害和 EffectEvent 仍由现有 server authority
  处理。
- `finish` 幂等：同一 handle 第二次 finish 返回原 finish result 并计
  `idempotentFinishes`；`destroy` 才把槽归还 free-list。
- `tick` 处理 TTL；`ownerDestroyed`、`sceneReload` 遍历 owner/scene 并显式终止。
- generation-bearing handle 在 slot reuse 后拒绝 stale update/destroy；owner 不一致
  的 update/correct/collide 拒绝。

## Dense Store 与预算

默认 logical capacity 为 500。`slots`、`activeIndices`、`activePosition`、`free` 和
`generations` 是 numeric dense/free-list 结构，注册/删除为 O(1) swap-remove，
`active + free = capacity` 恒成立。每个实体记录只保留 lifecycle 所需 DTO，不创建
通用 component table。诊断记录 active/free、capacity reject、maxActive、memory
high-water（离线模型按 256 B/slot 估算）、stale/owner/malformed/backend reject、
TTL/impact/owner/scene finish 和 replay event 数。

## Synthetic/replay

`replay(trace)` 接受纯 DTO trace 并标记 `synthetic=true`，用于 S2/S4 golden、迁移
shadow 和回放差异记录；它不调用 Teardown API，也不把回放结果当作物理命中证据。

## Fixture 与运行

`docs/candidates/projectile-lifecycle-v1.fixture.json` 覆盖四种 backend、capacity
拒绝、update/correct/collide、impact finish 幂等、generation reuse/stale handle、
stale owner、owner death、scene reload、TTL、malformed DTO、replay 和最终 active/free
平台化。

```powershell
& .\tools\cm2-world-host\run-projectile-lifecycle-v1.ps1 `
  -ReportPath .\docs\candidates\projectile-lifecycle-v1-result.json
& .\tools\cm2-world-host\test-projectile-lifecycle-v1.ps1
```

离线结果验证协议/生命周期，不宣称 projectile 的真实 QueryRaycast、damage、impact
FX、frame p95 或 GC。当前环境没有可发现的 `Teardown.exe`，因此 S2/S4 500 logical
projectile、owner death、scene reload 和真实内存平台曲线仍需实机 replay 后补 Todo，
本步骤应保持 `unable`。

## 回滚

按 projectile kind/backend 保留 `projectile/manager.lua` legacy 路径。若 shadow replay
出现命中、owner 或回收差异，关闭 lifecycle adapter，切回旧 manager，并保留 fixture、
result、失败 trace 和上一版 generated artifact；不得让新旧 manager 同时拥有同一
projectile instance。
