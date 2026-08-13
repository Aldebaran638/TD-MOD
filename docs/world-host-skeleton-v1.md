# World Host Skeleton v1 与 Ship Instance Adapter

## 迁移范围

Gate 4.3 只迁移 scene-wide registration、heartbeat、lifecycle、generation、dense
instance index 和低开销诊断。`Content Mod 2/main.lua` 在 server/client init/tick
启动唯一 `cm2WorldHostV1`；`shipMain.lua`、`strikeCraftMain.lua` 和 legacy escort
entry 在完成既有 ship 初始化后，通过 `cm2ShipInstanceAdapterV1` 注册 identity、owner
和 capability。移动、伤害、开火、Projectile、Effect/Audio 仍由原有 ship/weapon
runtime 负责，避免在跨 context 尚未证明时搬迁权威语义。

## Host 状态机

```text
server.init
  -> generation = previous + 1
  -> owner = scene-host-1, mode = content-host, ready = true
server.tick
  -> fixed clock + 0.5s heartbeat
  -> consume bounded adapter announcements
  -> maintain dense[1..12], byId, queue/active diagnostics
host.dispose(scene-unload)
  -> generation++, dense/byId clear, ready = false
```

Host 通过小字段 registry announcement 读取 adapter 的 identity/owner/generation/
heartbeat/active；它不把大 payload、engine handle 或 weapon state 放进 registry。slot
固定在 1..12，默认由 identity hash 选择，也可以用 `worldslot` 参数显式指定；冲突或
stale generation 会计数并拒绝。后续 Step 4.4/4.5 会把 presentation/snapshot/damage
改成正式 transport，不把本实验的 announcement 当成最终网络协议。

## Adapter 状态机与回退

1. adapter 先观察 `cm2/world-host/v1/ready/mode/generation`；Host 可用时以
   `content-host` 发布小型 register/heartbeat announcement；
2. Host 缺失时显式进入 `local`，用本 context 的 skeleton 注册，并写入
   `fallbackReason=content-host-unavailable`；
3. Host generation 改变或 ready 消失时进入 `local-fallback`，记录原因，重新建立
   local registration；绝不静默创建第二个 content-host；
4. ship death、unregister 或 scene unload 调用 dispose，active=false，Host 下次扫描
   清除 dense index。

`getReport()` 暴露 mode、generation、heartbeat、fallbackReason、activeInstances 和
`localAuthority`，用于后续 S0/S6/S7 与 Soak 诊断。`synthetic_world_adapter_v1.lua`
提供相同的 `init/tick/dispose/snapshot/getReport` 形状给 Preview/fixture；它不调用
Teardown API，因而不能把预览状态误当作真实 physics entity。

## 复现与边界

```powershell
& .\tools\cm2-world-host\run-world-host-skeleton-v1.ps1
```

该脚本验证三个 ship entry 的 include/初始化/heartbeat/dispose 连接、Host 的 dense
index/generation/fixed capacity、local fallback 和 deferred authority scope，并输出
稳定报告。`docs/candidates/world-host-skeleton-v1.fixture.json` 记录两船、reload、
stale、late join 和 unload 的最小时序。

本机没有 Teardown.exe，因而不能证明真实脚本 context 之间的 registry 可见性、两个
live Ship 同时注册、Host reload/late join、死亡回收、server/client latency 或无船
成本；这些条件必须在 S0/S6/S7 实机 smoke/压力中完成。当前状态是 skeleton 已落地、
runtime 证据 unable。

## 回退

把 `worldServiceOwner`/Host ready 设为 local、停止 Content Host announcement，保留
原有 ship/weapon adapter；回滚只涉及五个 entry 的 include/调用和两个新模块，不删除
旧 registry。若 Host 不可用，宁可显式 local fallback，也不让第二个隐式 Host 接管。
