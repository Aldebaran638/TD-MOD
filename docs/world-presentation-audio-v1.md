# Scene Presentation/Audio Host v1

## 目标

Gate 4.4 在 Host 上建立唯一的 EffectPlayer owner、Audio voice owner、resource
cache owner 和 scene budget。`Content Mod 2/main.lua` 的 client Host 初始化
`cm2PresentationAudioHostV1`；Ship Instance Adapter 只发布有界的 presentation event
和本船 anchor/camera snapshot。现有 `presentation_publisher.lua` 的 legacy/event-v1
互斥仍是 server 语义边界，未把旧 weapon renderer 复制到 Host。

## 队列与预算

| 类别 | 容量 | 策略 | 诊断 |
|---|---:|---|---|
| Critical | 64 | 满时可靠拒绝并计数；不静默丢弃 | `criticalDropped`, `duplicateRejected`, `staleRejected` |
| Ambient | 128 | 以 `coalesceKey` 合并最新事件 | `ambientCoalesced`, `ambientDropped` |
| Event announcement slots | 32 | Ship adapter 写固定小字段，Host client 扫描 | sequence/generation/latency |

Host `getDiagnostics()` 固定报告 `effectPlayerOwnerCount=1`、
`audioVoiceOwnerCount=1`、`resourceCacheOwnerCount=1`、queue depth、critical/ambient
drop、duplicate/stale、`latencyP95`。Host 初始化时复用现有 EffectPlayer 的单一
capacity（128）；本步不在每个 Ship context 重新创建 scene budget。

## Adapter 边界与回退

`publishPresentationEvent(kind, anchorId, critical, coalesceKey, effectId, emittedAt)`
只写 `source/sequence/generation/kind/critical/anchor/effect` 小 DTO。`publishAnchorSnapshot`
只写 anchor/camera identity 和 revision。Host ready 且 mode=content-host 时由唯一
scene Host 消费；adapter mode=local/local-fallback 时返回 `legacy-local-owner`，让旧
renderer 继续负责，避免同一事件双播放。Adapter 不持有 EffectPlayer、Audio voice
manager、resource cache 或 scene budget。

Host reload 清空队列和 sequence map；旧 generation 事件拒绝。Critical 与 ambient
分别计量 latency，`latencyP95` 只作样本报告，不在没有 Teardown 实机时伪造目标值。

## 可执行复现

```powershell
& .\tools\cm2-world-host\run-world-presentation-audio-v1.ps1
```

fixture 覆盖 critical accepted、duplicate/stale rejection、ambient coalescing、
owner=1 和 local double-playback guard。该 runner 是静态/离线合同检查；它不会删除
旧 FX/audio catalog，也不将 legacy 默认改成 event-v1。

## 不能提前宣称的内容

本机没有 Teardown.exe，无法证明 S1/S3/S5 中不同 Ship context 的事件确实到达同一
client Host、真实 PlaySound/EffectPlayer owner 数、critical drop=0、presentation p95、
resource cache 共享、远近 LOD 或 10 分钟压力。因此旧 renderer/音频路径仍保留且
status 必须为 unable，等 Step 4.5/实机 smoke 后再删除 per-ship full catalog。

## 回退

将 Host mode 设为 local、清空 Host ready/队列，adapter 继续 `legacy-local-owner`；
恢复上一版 presentation publisher/effect runtime。回滚不删除旧 renderer，不重放
已消费事件，也不允许 Host 与 legacy 同时拥有同一 event source。
