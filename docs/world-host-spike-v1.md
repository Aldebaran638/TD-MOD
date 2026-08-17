# World Host Spike v1：两船、两 Context、一个 Host

## 目的与边界

这是 Gate 4 的最小可复现实验，不是生产 World Host 接管。它把 `main.lua` 的
Content Host、两个 `shipMain.lua` adapter context 和一个版本化 DTO transport
写成离线 fixture，并用 `tools/cm2-world-host/run-world-host-spike-v1.ps1` 重放。
实验先验证 context、顺序、generation、owner 和 payload 边界，再允许 Step 4.2
定义正式 World Protocol；在此之前不把伤害或开火权威放进跨 context transport。

## 拓扑与选择

| 方案 | Host/Ship 所有权 | 优点 | 风险 | 本 Spike 结论 |
|---|---|---|---|---|
| A | Content Host 拥有 scene service；每船保留 adapter；transport 只传 DTO | 可逐步迁移，保留现有飞行/武器；高频事件可按船隔离 | 需要明确 owner/generation 和队列预算 | **选择**，作为 Step 4.2–4.5 的默认拓扑 |
| B | 一个 World Script 直接拥有所有 Ship，prefab 只注册 | 全场扫描集中、单一 tick | 迁移面大，单脚本故障域和调度压力更大 | 保留为 Host 缺失时的理论对照，不接生产 |
| C | 高频 instance-local；可靠服务集中 | 延迟和成本更可控，适合表现事件 | 两条路径必须禁止双播放、双计数 | 作为 A 的后续优化，不在本 Spike 混用 |

当前 fixture 明确验证一个 `scene-host-1`、`ship-A` 和 `ship-B` 两个独立 owner。
Host reload 将 generation 从 1 提升到 2，旧 generation 消息无效；late join 只能
以新 generation 注册并从 snapshot 收敛。

## Capability matrix 与时序

`docs/candidates/world-host-spike-v1.fixture.json` 的 capability matrix 覆盖：

1. host init/tick/client 生命周期和唯一 host；
2. 两个 ship register/heartbeat/unregister；
3. transport 只能承载稳定 DTO，禁止 Lua function、Body/Shape/Joint handle 和 registry 引用；
4. host reload、stale generation、late join 和 scene unload；
5. presentation 高频通道与 snapshot 低频通道分别计量；
6. damage/fire authority 在 Step 4.2+ 前明确 deferred。

生命周期重放顺序是 `host.init → A/B register → A/B heartbeat → presentation/snapshot
publish → duplicate/out-of-order rejection → host.reload → stale-generation rejection
→ B late-join → A re-register/unregister → scene.unload`。该顺序同时覆盖 ship 先于
host 的失败语义：真实接入时 adapter 必须等待 host capability，不能静默创建第二个 Host。

| 通道 | 频率上限 | payload 上限 | 可靠性 | 归属 |
|---|---:|---:|---|---|
| Presentation | 60 Hz | 256 B | ambient/coalesce；critical 另行可靠队列 | Host client Effect/Event 服务 |
| Snapshot | 10 Hz | 1024 B | ordered/reliable | Host snapshot service |

两类通道必须分别测量 latency、queue depth、drop 和 duplicate；不能用大字符串
Registry 轮询模拟共享内存。

## 失败路径与安全约束

- duplicate sequence、delayed out-of-order 和 stale generation 都是 reject-and-count；
- owner 与 context 不匹配拒绝，不能用另一个 Ship 的 lease 写入；
- host reload 清空旧实例索引和队列，late join 以 snapshot 重建；
- scene unload 必须让 registered context=0，不能遗留 stale instance；
- transport 不承载 authoritative damage/fire/weapon-definition，服务端权威留在下一步协议；
- Host/transport 不可用时只能显式 `local` fallback 或拒绝，不能半运行、双注册或双播放。

## 可执行复现与证据

在仓库根目录运行：

```powershell
& .\tools\cm2-world-host\run-world-host-spike-v1.ps1
```

脚本会验证 fixture schema、两个 context/一个 Host、payload 禁止字段、15 个有序
lifecycle 事件、五个 transport probes 和预期计数，并输出稳定 JSON 报告。`-ReportPath`
可把报告写到审计目录；默认只输出结果，避免把实验结果误当生产 generated catalog。

本机没有 Teardown.exe，因此本次只能证明离线时序/协议不变量；实机的 server/client
context 顺序、实际网络 latency、payload 序列化大小、S0/S6/S7 和高频压力仍是
`unable`，不得据此宣称已经具备多 Context runtime。

## 回退与下一步

Spike 不改变生产入口。若任何高频跨 context 测试不可靠，回退到现有 per-ship
local mode，并保留 fixture 失败记录；禁止把失败修成字符串 Registry。只有该报告和
实际 Teardown smoke 通过后，才进入 Step 4.2 的 World Protocol/Owner Lease 定义，
再进入 Step 4.3 的 skeleton/adapter 接入。
## Live Step 4.1 follow-up (2026-08-18)

The first live two-player run exposed a startup race: ship scripts could initialize before the Content Host and then remain in an incorrect local fallback. The production fix is committed as `961c998`.

- `ship_instance_adapter_v1.lua` waits in `pending`, observes the advertised Host generation, and only publishes an active `content-host` announcement after readiness.
- `vehicle_instance_v1.lua` now sets its initialized flag after `serverInit`, allowing the adapter heartbeat path to run.
- Local fallback remains bounded and explicit; it is not used during the verified startup.

The clean live run used Host PID 40804 and Client1 PID 49532. One fresh `CM2_TEST_V1` session (`0-ef8ddf1b`) reported three active contexts, generation 1, `register_count=3`, `fallback_count=0`, and `rejected_count=0`. Host and Client real W edges were recorded with player IDs 1 and 2; Client1 had no vehicle owner and did not mutate the Host registry. Host and Client screenshots, input traces, incremental log result, cleanup, and Harness are recorded in `docs/evidence/step-4.1-world-host-multiplayer-v1.json`.

This live record verifies the World Host/context boundary. It does not claim independent fire/death authority acceptance. The Client1 screenshot is near-black after the player fell below the tested scene camera and is retained for human visual review. The next scope is the owner-bound World Protocol/Lease work in Step 4.2, with fire/damage authority kept outside this spike.
