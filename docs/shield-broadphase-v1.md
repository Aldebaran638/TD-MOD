# Projectile Shield Broadphase v1

## 目的与切换边界

`Content Mod 2/script/weapon/server/behavior/projectile/shield_broadphase_v1.lua` 为
普通 projectile 提供 shield sphere snapshot + uniform grid broadphase。它把每条
segment 的候选范围限制到穿过的 cells，再做 segment/sphere entry；不会在每枚弹每帧
遍历 Registry 的全部护盾。`projectile/manager.lua` 增加
`server.projectileManagerSetShieldBroadphase("legacy"|"grid")`，默认仍为 legacy，
因此未有实机 shadow 证据前不会改变既有伤害结果。

## 数据面

每个 shield entry 包含 entityId/generation、bodyId、center、radius、shieldHP 和
enabled。spawn/move/HP/disable/remove 更新会重建受影响 cell 列表；`refresh` 复制出
immutable snapshot，query 不读取正在变化的表。默认 cell size 150 m，限制在 100–250 m。
snapshot 同时保留 `entriesById`，候选 ID 去重后只做一次 narrowphase。

`findEarliest(startPos, endPos, projectileRadius, ownerBodyId)`：

1. 用 segment AABB + projectile radius 枚举 grid cells；
2. 去重并排除 owner body、disabled/HP=0 shield；
3. 对候选执行 expanded sphere entry，支持 tangent、inside-start、跨 cell、高速
   segment 和大 projectile radius；
4. 返回最早 `t`、entity/generation/body、hitPos、normal、impactLayer=shield。

诊断报告 broadphaseCandidates、candidateChecks、narrowphaseTests、query/hit、
stale generation、fullRegistryScans 和 snapshot revision；legacy scan 通过
`recordLegacyScan` 留下可比较的基线，不能被新 backend 静默抹掉。

## Fixture 与 golden

`docs/candidates/shield-broadphase-v1.fixture.json` 覆盖四个 shield（含空 HP 和 owner
排除）、tangent、inside-start、跨多个 cell 的高速 segment、大 radius、移动后 revision、
销毁/stale generation、无命中和 legacy full-scan 记录。golden 要求新旧命中对象一致，
差异采用 `fail-and-record`。

```powershell
& .\tools\cm2-world-host\run-shield-broadphase-v1.ps1 `
  -ReportPath .\docs\candidates\shield-broadphase-v1-result.json
& .\tools\cm2-world-host\test-shield-broadphase-v1.ps1
```

runner 只执行离线几何和 grid 模型，不调用 `QueryRaycast`、GetBodyTransform 或真实
伤害。当前环境没有可发现的 `Teardown.exe`，所以 S4 的 500 projectile×12 ship 对比、
实际命中/层级/伤害、Query/CPU p95 仍需实机 replay；Todo 状态保持 `unable`。

## 回退

若任何 segment golden、owner 排除或 shield HP 行为不一致，保持
`projectileShieldBroadphaseMode="legacy"`，继续使用 manager 的旧 Registry 扫描；
保留 grid snapshot、result、shadow trace 和失败日志。不得同时让 grid 与 legacy 为同一
projectile 产生两次 damage，也不得删除旧 manager 或上一版 artifact。
