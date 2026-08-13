# Scene Target Catalog 与 Uniform Grid v1

## 目标

Gate 5.2 把目标资格和空间候选从每个 mount/导弹自己的全量 Registry/Find 扫描，
收敛到一个 scene 级 server-owned snapshot。`Content Mod 2/main.lua` 初始化
`cm2SceneTargetCatalogV1`，入口只接收 spawn、movement、disable/remove 更新；模块本身
不调用 `FindBodies`、`FindVehicles` 或物理 Query。

默认刷新为 5 Hz（允许 5–10 Hz），cell size 默认 150 m（限制在 100–250 m）。脏更新
会立即在下一次 server tick 生成 snapshot，干净场景按固定周期刷新；因此不会因每枚
导弹或每个炮口而增加全场扫描次数。

## 目录记录与网格

每个 target entry 固定包含：

- `entityId` + `generation`（查询返回的稳定身份）；
- position、velocity、radius（同一 physics phase 缓存）；
- faction、targetType、capabilities、tags；
- enabled 状态。

启用实体进入 `cellKey = floor(position / cellSize)` 的 uniform grid。移动跨 cell 时只
从旧 list 移除并加入新 list；disable/remove 清理 cell。snapshot 构建时复制 entry 和
cell lists，并按 entityId 排序，避免读取内部可变表产生隐式分叉。

## 查询与过滤

`query(origin, radius, filter)` 只访问 snapshot 中与 origin 相邻的 cell，再执行精确
距离、faction/factions、targetType/targetTypes、capabilities 和 excludeEntityId
过滤。结果按距离、entityId 稳定排序，最多 128 条，并携带 entityId/generation、位置、
速度和 distanceSquared。目录层先筛选资格，guided、charged、Point Defense 和 HUD
可以复用同一 candidate set；客户端应消费 `clientSetSnapshot` 的有界副本，不自行
每帧 Find。

## 诊断

`getDiagnostics()` 报告 scene/generation/revision、cell size/refresh Hz、target/cell/
snapshot 数、register/update/move/disable/remove、dirty/scheduled refresh、query
次数、candidate checks/results、query budget reject、stale generation reject，以及
`recordQueryCost` 的样本总量、累计值和当前 p95 上界。snapshot age 与刷新频率是可观测
字段；实际 frame time 仍必须由运行时 replay 记录。

## Fixture 与 legacy shadow

`docs/candidates/scene-target-catalog-v1.fixture.json` 覆盖：

- 100 m cell 边界（-0.1→0.1）和跨两个 cell 的移动；
- spawn、dirty refresh、定时/快照 revision、disable、remove；
- major/interceptor/craft/external 的 faction/type/capability filter；
- stable snapshot 在 dirty refresh 前保持旧位置；
- stale generation update/register；
- `legacyGolden` 的候选 ID 顺序与 `fail-and-record` 差异策略；
- client snapshot 版本接受/拒绝和 512 条上限声明。

运行：

```powershell
& .\tools\cm2-world-host\run-scene-target-catalog-v1.ps1 `
  -ReportPath .\docs\candidates\scene-target-catalog-v1-result.json
& .\tools\cm2-world-host\test-scene-target-catalog-v1.ps1
```

runner 是离线模型，证明网格边界、快照稳定性和过滤契约，不伪造 Teardown 的物理
候选或性能。当前环境没有 `Teardown.exe`，因此 S1/S3 的真实 Find 次数、Query 耗时、
目标可见性和 HUD/Server 一致性仍需实机 replay 后补录，Todo 状态保持 `unable`。

## 兼容与回退

迁移时旧 target API 先包装 catalog 并保留 candidate trace；只有 shadow golden、
stale/death 行为和实机成本达标后，才逐个切换 guided/charged/PD/HUD。出现候选差异、
错误 generation 或性能回归时，按 scene 切回旧候选器；不得让 Server 与 UI 各自维护
不同的 target eligibility，也不得删除本 fixture、结果或上一版生成物。
