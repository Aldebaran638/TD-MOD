# World Protocol v1、Owner Lease 与 Capability

## 合同定位

`Content Mod 2/script/net/world_protocol_v1.lua` 是 Gate 4.2 的 transport-neutral
DTO 合同。它把 World Host 从隐式全局变量变成有 protocol version、message kind、
owner lease、generation、sequence、capability 和 fixed-capacity queue 的服务边界。
本步只定义并验证合同；真正的 Host registry/adapter 由 Step 4.3 接管。

## Wire DTO

每条消息至少包含：

```text
protocolVersion = cm2.world/1
kind            = register | unregister | heartbeat | command | snapshot | delta | presentation | lifecycle
source          = { contextId, ownerId }
generation      = positive integer
sequence        = strictly increasing per context/generation
payload         = serializable DTO only
payloadBytes    = bounded integer measured before enqueue
capabilities    = declared allow-list
```

`function`、Lua userdata/thread、Body/Shape/Joint handle、registry reference、
callback/functionName 和 shared table 都是硬拒绝项。`damage`、`fire-authority` 和
weapon definition 不属于本步跨 context authority；它们必须等后续 server-authority
协议完成后再进入单独的 command/snapshot 合同。

## Owner Lease

Lease key 是 `ownerId@generation`，包含 issuedAt、expiresAt 和正数 timeout：

- 同一 service/generation 已有有效 lease 时，重复 acquire 拒绝；
- 只有原 owner 能 renew/release；另一个 owner 即使知道 context ID 也拒绝；
- Host reload 递增 generation，旧 lease/message 一律 stale；
- 过期 lease 不可用于消息；新 Host 必须重新 acquire，不能复用本地引用；
- unregister/release 是显式生命周期事件，scene unload 时 Host 清空实例索引和队列。

## Capability 与 Queue

Capability 是版本化 allow-list（register、heartbeat、command、snapshotRead/Write、
deltaRead、presentationPublish、lifecycleRead）。未知 capability fail fast，不能
通过任意字符串扩大权限。Presentation 使用 60 Hz/256 B、ambient-coalesce；snapshot
使用 10 Hz/1024 B、ordered-reliable。`newTransport(capacity)` 是固定容量 head/tail
ring：满时返回 `queue overflow` 并递增 dropped，不分配无界消息列表。

## Fixture 与失败路径

`docs/candidates/world-protocol-v1.fixture.json` 覆盖：

1. valid register；
2. stale generation、duplicate sequence、incompatible version；
3. payload budget、forbidden engine handle、unknown capability；
4. duplicate owner acquire、wrong-owner renew/release、expired lease；
5. capacity=2 的第三次 enqueue overflow 和 dequeue 后 depth=1。

离线复现：

```powershell
& .\tools\cm2-world-host\run-world-protocol-v1.ps1
```

如果任一 invariant 失败，脚本以非零状态退出并打印稳定字段；这比在 Registry 中
轮询大字符串更早暴露协议错误。当前环境没有 Teardown.exe，所以实际 server/client
序列化、网络延迟、owner timeout、Host reload 与无船成本仍需实机证据；本合同不会
把 fixture 结果误报为 runtime capability。

## 回退

本步模块只提供 DTO/lease/queue API，不抢占生产伤害或开火路径。若 Step 4.3 接入
失败，保留 `worldServiceOwner=local`，停止调用 `cm2WorldProtocolV1` 的 Host 实现，
恢复上一版 fixture/文档；不得删除上一版协议或静默接受未知 generation。
