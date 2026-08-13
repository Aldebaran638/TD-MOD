# Registry Snapshot、Scheduler 与 Damage Inbox v1

## 服务周期

`Content Mod 2/script/world/host/registry_scheduler_damage_v1.lua` 将全局枚举放在
Host 服务周期，而不是让每艘船各自扫描 Registry/explosion/projectilehit：

```text
beginSnapshotCycle(generation)
  -> 一次 registryReadPass
  -> addEntity(只接受稳定 DTO)
  -> freezeSnapshot (revision + generation)
  -> scheduler fixed-Hz/priority/stagger/budget
  -> ingestGlobalDamage (一次读取/去重)
  -> adapter.consumeDamage(ownerId) (只消费自己的 inbox)
```

Snapshot freeze 后禁止添加或修改；`getSnapshot()` 返回 clone，旧 generation 和 stale
damage 都拒绝。实体 DTO 只带 entityId/ownerId/bodyId/generation 等稳定标识，不含
Body/Shape handle 或可变 Registry 引用。当前 root Host 每个 server tick 生成一个空
安全 snapshot，后续 Adapter 接入再填充实体。

## Scheduler

Scheduler 是固定 60 Hz 时钟上的小任务表，不为每个实体分配通用消息对象。每项任务有
taskId、owner、frequencyHz、priority、stagger、budget；执行顺序 priority 降序、taskId
稳定排序。重复 task、错误 owner unregister、超过 64 项和 budget=0 都显式拒绝并计数。

## Damage Inbox

Host 每个 simulation tick 对全局 damage source 只调用一次 `ingestGlobalDamage`，按
ownerId 放入最多 256 项的 inbox，并按 sequence/eventId 排序。eventId 去重，generation
过期拒绝；`consumeDamage(ownerId, n)` 只返回该 owner 的事件并在应用计数后移除。最终
伤害应用仍是 server authority，本步不改现有武器/物理伤害函数。

零事件帧只递增一次 globalDamageReads，不读取每艘船 Transform/COM；fixture 以
`entityTransformReads=0` 固化这个边界。诊断暴露 registryReadPasses、globalDamageReads、
queue depth、duplicate/stale/applied 和 scheduler budget 数据，供后续 1/4/8/12 舰压力曲线使用。

## 复现与限制

```powershell
& .\tools\cm2-world-host\run-registry-scheduler-damage-v1.ps1
```

runner 会重放 fixture 的 snapshot freeze、scheduler contract、duplicate/stale damage
和 zero-event invariant，并输出稳定 report。由于当前环境没有 Teardown.exe，无法测量
真实 Registry API 调用次数、damage 物理结果、1/4/8/12 舰 O(S) 曲线或 6→12 舰 2.3x
CPU 暂定阈值；这些证据必须在后续实机压力中补齐。

## 回退

关闭 root Host data-plane tick，继续由现有 server ship/weapon runtime 处理 damage；
保留最后一个 snapshot/revision 和 inbox report。不要在失败时把 per-ship 全局扫描重新
复制到每个 adapter，下一次尝试从固定 snapshot/revision 恢复。
