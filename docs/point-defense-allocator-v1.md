# Point Defense Candidate Allocator v1

## 目标与接线

Gate 5.3 在现有 engine-backed `point_defense/control.lua` 旁增加
`behavior/point_defense/allocator_v1.lua`。它是按舰的候选/分配边界：一艘船每个 tick
只接收/构建一次候选，所有 mount 共享这份列表；旧 `_pdFindTarget` 仍是默认 legacy
backend，只有 live S3 shadow 通过后才允许按船把 `backendMode` 切到 `catalog`。

## 分配顺序

1. `updateCandidates` 对候选做固定容量截断（默认 64），按 priority、threatTime、
   distance、entityId 稳定排序；超出容量的候选进入 `candidateBudgetRejected`。
2. `allocate(shipId, dt, tickId, shipFaction)` 对同一 tickId 只执行一次。重复调用
   返回缓存 assignments 并计 `duplicateTickRejects`，避免每个 mount 重新 query。
3. 每个 mount 先消耗 cooldown，再检查舰队 fire budget。候选按顺序过滤 disabled/
   destroyed、owner/faction 友军、距离、line-of-sight、武器 targetClasses 和同一
   target 的 `targetAssignmentLimit`；失败原因分别计数。
4. 选中后返回 `mountId/weaponType/role/targetEntityId/targetGeneration/distance/
   threatTime`，减少分配器与 engine handle 的耦合；mount cooldown 重置，fire budget
   减一。
5. `disposeMount` 立即移除 mount 并清空 cached assignments，避免锁定残留；
   `clearShip` 清理整舰状态。

过载降级顺序固定为“候选容量截断 → 每舰 fire budget → mount cooldown/资格拒绝”。
这保证 12 船/24 mount 的成本与舰数、mount 数线性相关，而不是 `R × N` 次全场扫描。

## 诊断与兼容

全局和 per-ship diagnostics 包含 candidate query/pass/count、candidate capacity reject、
mount allocation、assignment/cooldown/range/friend/occlusion/destroyed/fire-budget
reject、duplicate tick 和 disposed mount。`buildCandidates` 接受 Step 5.2 catalog
query API，因此 target snapshot/grid 是唯一候选来源；模块不调用 Find 或 QueryRaycast。

`setBackend(shipId, "legacy"|"catalog")` 是显式开关。legacy 默认保留旧 selector；
任何候选差异或 runtime 回归都可按船切回，不得让两套 backend 同时为同一 mount 发火。

## Fixture 与 golden

`docs/candidates/point-defense-allocator-v1.fixture.json` 覆盖一舰三 mount：

- torpedo/missile/strike-craft priority 与 target class；
- friendly owner/faction、遮挡、destroyed、超距候选；
- 9→8 候选容量降级、2 发 fire budget、cooldown 时间推进；
- duplicate tick、同一 target 一次分配、mount dispose 清锁；
- tick-1/tick-3/tick-4 的 legacy assignment golden 与 fail-and-record 策略。

运行：

```powershell
& .\tools\cm2-world-host\run-point-defense-allocator-v1.ps1 `
  -ReportPath .\docs\candidates\point-defense-allocator-v1-result.json
& .\tools\cm2-world-host\test-point-defense-allocator-v1.ps1
```

runner 是离线分配模型，不宣称真实 LoS、damage、FX、CPU 或 p95。当前机器没有可发现
的 `Teardown.exe`，所以 S3 的 12/24 pressure、Query/CPU p95、实际防御行为和视觉
退化仍需实机 replay 后补入 Todo；状态保持 `unable`。

## 回退

若 candidate shadow、遮挡或分配行为不一致，按船将 backend 切回 `legacy`，保留
allocator fixture、golden、诊断和失败日志；不要删除旧 `_pdFindTarget`，也不要用新
模块绕过旧的 server damage/weapon authority。
