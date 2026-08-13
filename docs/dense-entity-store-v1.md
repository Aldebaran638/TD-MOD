# Dense Entity Store v1

## 目标与边界

Gate 5.1 为高周转实体提供固定容量的本地热数据面：`projectile`、`craft`、
`effect`、`joint` 分别拥有自己的 dense store。World Registry 仍负责跨系统
identity、观察和 snapshot；它不再承担每次 spawn/remove 的全表压缩。根
`Content Mod 2/main.lua` 在 server 初始化时建立 store，在 server tick 中只调用
store 的轻量 tick，旧 Registry API 可以继续作为兼容/回滚边界。

默认容量是 projectile 96、craft 24、effect 128、joint 64；真实场景可在
`serverInit(generation, capacities)` 传入固定容量覆盖，但不能在热路径隐式扩容。

## 数据结构与 O(1) 操作

- `slots[index]` 保存实体记录；`activeIndices` 是连续 active 数组。
- `free` 是预填充的 free-list；注册从尾部取 index，删除把最后一个 active
  index swap 到被删位置，再把 index 放回 free-list。
- `generations[index]` 随 remove 增加。句柄携带 `kind/index/generation/entityId`；
  `get`/`remove` 对 index、generation 和 slot 三项同时校验，旧句柄统一返回
  `stale dense handle`。
- `byEntityId` 与 `byBodyId` 是本地 O(1) 映射；重复 identity 被拒绝。删除先清理
  映射，允许 bodyId 在新 generation 中安全复用。
- `iterate` 只遍历 active 数组，不遍历 capacity 中的空槽；`snapshot` 返回复制的
  DTO，避免 Registry 读到可变内部 slot。

每一步操作后恒有 `active + free = capacity`。删除/重用不会重写其他 store，也不会
给每枚导弹复制 Major Vehicle 的完整 HP/config 字段；调用方应只放热路径所需的
最小 payload。

## 诊断与性能证据

每个 store 报告 `capacity`、`active`、`free`、`registers`、`removes`、`reuses`、
`staleRejected`、`capacityRejected`、`denseIterations`、`legacyTableIterations`、
`memorySamples`、`gcSamples` 和 `maxActive`。总诊断报告额外给出 generation、总重用、
stale handle、dense/legacy iteration、memory/GC sample 计数。

`recordComparison` 为迁移期间记录 legacy table iteration 与 dense iteration、内存
和 GC 样本的入口；它不伪造引擎计时。真实 S2/S3 压力需要把 96 missile、24 craft
生成/销毁 replay 接入 Teardown 后，再填入 p95/p99 和 memory/GC 曲线。

## 离线 fixture

`docs/candidates/dense-entity-store-v1.fixture.json` 覆盖四类 store、连续注册、
swap-remove、容量拒绝、旧句柄读取、slot generation reuse、bodyId 复用和 active
遍历。`tools/cm2-world-host/run-dense-entity-store-v1.ps1` 使用同一不变量模型检查
每个 operation 后的 `active + free = capacity`，并验证比较记录的 p95/p99 方向。

```powershell
& .\tools\cm2-world-host\run-dense-entity-store-v1.ps1 `
  -ReportPath .\docs\candidates\dense-entity-store-v1-result.json
& .\tools\cm2-world-host\test-dense-entity-store-v1.ps1
```

离线结果证明数据结构和拒绝策略，但不能替代 S2/S3 实机的物理、内存、GC 或 frame
p95/p99。当前环境没有可发现的 `Teardown.exe`，因此 Todo 将该项标记为 `unable`，
而不是把 fixture 的占位曲线当作运行时成绩。

## 兼容、回退与迁移顺序

1. 先以 `cm2DenseEntityStoreV1` 记录/比较，不改变旧 Registry 的观察输出。
2. 对单一实体类型启用 adapter，将旧 register/remove 包装到 store，再比较 snapshot。
3. 只有 generation、active/free、stale-handle 和 live pressure 证据都通过，才逐类
   切换 projectile、craft、effect、joint。
4. 出现串实体、容量不足或性能回归时，按实体类型切回旧 Registry index；不要让旧
   Registry 和新 store 同时为同一 instance 分配 owner。保留 fixture、result、回滚
   日志和上一版生成物。
