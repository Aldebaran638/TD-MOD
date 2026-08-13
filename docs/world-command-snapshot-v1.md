# World Command/Snapshot Boundary v1

## 定位

`Content Mod 2/script/net/world_command_snapshot_v1.lua` 是 Gate 4.6 的
transport-neutral 多人边界。它把客户端输入当作可拒绝的意图，把服务器状态当作
唯一事实；它不把 Lua 函数、本地闭包、Teardown engine handle、Definition 原表或
效果回调放进网络 DTO。

协议版本为 `cm2.world.multiplayer/1`。根 `main.lua`、Ship/StrikeCraft 入口都只
include 这一份实现，生产入口仍可由上一层 `world_protocol_v1`/local adapter 回退，
因此本步骤没有把未验证的多人语义强行替换进武器和伤害实现。

## DTO 与权威规则

| 方向 | 允许内容 | 服务器处理 |
|---|---|---|
| Client → Server command | `input`、`loadout`、`target`、`fireIntent`，session/owner/generation/revision/sequence 和可序列化 payload | 校验版本、session owner、generation、严格递增 sequence、revision、payload 512 B 上限、fit、target、fire cooldown 和 1 秒 30 条限流 |
| Server → Client snapshot | `lifecycle`、`snapshot`、`delta`、`shot`、`damage`、`presentation` | 服务器分配 sequence；稳定状态可留给 late join，瞬时事件只发布一次，不进入 late-join 回放 |
| Server → Client ack | `accepted`、server command sequence、generation、revision、client sequence | ack 只确认服务器接受意图，不代表客户端可以自行生成伤害或 projectile |

`definition`、`rawDefinition`、`engineHandle`、`bodyHandle`、`shapeHandle`、
`jointHandle`、`callback`、`functionName` 和 `effect` 是硬拒绝字段；函数、userdata、
thread 也拒绝。重复 damage event、已标记 destroyed 的 entity 复活 snapshot 都拒绝。

## 会话、版本和生命周期

1. server 初始化时锁定正整数 `generation` 和 revision；`registerSession` 记录
   owner、epoch 和 sequence 起点。
2. `negotiateVersion` 只接受 exact protocol，或客户端明确声明兼容当前版本；未知
   版本返回错误，禁止静默分叉。
3. `acceptCommand` 先做 owner/generation/revision/sequence/内容/冷却检查，再执行
   rate limit。拒绝不会推进客户端 sequence；接受后由服务器分配 command sequence。
4. `publishSnapshot` 把 stable lifecycle/snapshot/delta 保存为 late-join 基线；
   shot/damage/presentation 是 transient，只计入发布和抑制回放计数。
5. `lateJoin` 只返回最后一份 stable snapshot。`reconnect` 重新注册 epoch、重置
   session sequence，并附带 stable snapshot；旧 transient 不重放。
6. `markDestroyed` 建立不可复活标记，后续携带该 entity 的 snapshot 被拒绝，避免
   stale owner 或 handle reuse 造成死船复活。

## 队列与诊断

命令/快照边界采用固定容量声明（command 32、snapshot 64），处理后深度回到零，
并保留 high-watermark。`getDiagnostics()` 暴露 `networkBytesIn/Out`、两类 queue
depth/high-watermark、accepted/rejected、stale/owner/revision/cooldown/fit/target、
duplicate damage、destroyed resurrection 和 `transientReplaySuppressed`。这使
S7 压力和重连测试可以把网络字节、队列深度和 authority reject 与同一份协议记录
关联，而不是靠客户端日志猜测。

## 离线 fixture 与运行方式

`docs/candidates/world-command-snapshot-v1.fixture.json` 覆盖：

- host/remote/late-join 三个 session；exact、declared-compatible、incompatible 版本；
- input/loadout/target/fireIntent 的正常命令；越权 owner、stale generation/revision、
  duplicate sequence、fit/target/cooldown 失败、禁止 handle、超 512 B、未知 kind 和
  命令版本失败；
- 30 条/秒限流、stable lifecycle/snapshot/delta 与 transient shot/damage/presentation；
- duplicate damage、destroyed entity resurrection、late join stable-only 和 reconnect
  sequence reset/stable snapshot。

运行：

```powershell
& .\tools\cm2-world-host\run-world-command-snapshot-v1.ps1 `
  -ReportPath .\docs\candidates\world-command-snapshot-v1-result.json
& .\tools\cm2-world-host\test-world-command-snapshot-v1.ps1
```

离线 runner 只验证协议/fixture 契约，不冒充网络、延迟、丢包或 Teardown 服务器。
本机没有可发现的 `Teardown.exe`，所以 S7 实机的 host/remote 配置、开火、锁定、死亡、
重连和 late join 仍记录为 `unable`；待有运行时后，必须把 command/snapshot 序列、
duplicate damage/projectile、死船复活和 30 分钟压力记录补入 Todo evidence。

## 回滚

若多人接线或实机验证失败，将 `worldServiceOwner`/adapter 回到 local 或上一版
`world_protocol_v1`，停止调用 `cm2WorldMultiplayerV1` 的生产路径，保留本 fixture、
result 和失败日志。不得删除上一版协议或静默接受未知 generation/revision；修复后从
同一 fixture 和同一回滚版本重新验证。
