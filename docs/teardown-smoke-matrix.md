# CM2 Teardown 实机 Smoke Matrix

本文件是 Content Mod 2 入口、生命周期、网络和表现相关改动的统一实机记录模板。静态 Harness 通过不等于实机通过；每次记录必须填写版本、地图、操作、观察点和证据路径。

## 执行环境表单

```text
Teardown executable/version:
Codex/Mod build hash:
OS/hardware:
Map:
Content Mod 2 package hash:
Global Mod package hash (if used):
Date/time/timezone:
Tester:
Screenshot/log/replay directory:
```

## S0 单船基线

**目的：** 验证内容入口、舰船初始化、配置 UI、输入、镜头、武器发射/命中/表现和死亡后的基本闭环。

### 前置

- [ ] 进入 Content Mod 2 主地图。
- [ ] 记录初始舰船、框架、武器组和 loadout。
- [ ] 打开诊断计数器；记录初始化错误、active entity、effect、voice 和 query 基线。

### 操作

1. [ ] 等待地图和舰船初始化完成，确认无 include/preprocess/runtime error。
2. [ ] 打开配置 UI，确认窗口、按钮、文字和当前 loadout 显示正确。
3. [ ] 关闭配置 UI，确认镜头、飞船输入和开火输入恢复。
4. [ ] 分别发射至少一件 ray/beam、普通弹道、制导或代表性武器。
5. [ ] 观察 muzzle、trail、impact、audio、shake、伤害和冷却。
6. [ ] 摧毁舰船或触发死亡流程，确认武器、导弹、效果和回调停止。

### 通过标准

- [ ] 初始化无 include/preprocess 错误。
- [ ] UI 打开/关闭不会锁死输入、镜头或开火。
- [ ] 发射、命中、伤害、表现和音频均与当前 golden 一致。
- [ ] 死亡后 owner/lifecycle 清理完成，无持续发射和孤儿效果。

## S6 死船生命周期

**目的：** 专门验证舰船销毁后的武器、导弹、舰载机、效果、声音、回调和 registry 清理。

### 操作

1. [ ] 在舰船同时有 active projectile、guided、craft、effect、voice 时触发死亡。
2. [ ] 连续观察至少 10 秒，记录仍在更新的实体和表现。
3. [ ] 重生或重新生成同类型舰船，检查 generation/owner 是否正确。
4. [ ] 重复销毁/生成至少 3 次，记录 active count、queue、memory 和 stale handle。

### 通过标准

- [ ] 死船不再执行武器、导弹、舰载机和表现更新。
- [ ] 未完成 event 被 finish/cancel，owner dispose 幂等。
- [ ] generation 不复用旧实体句柄。
- [ ] 重复生成/销毁后 active count 和内存回到 warmup 平台。

## S7 Host + Remote 多人基线

**目的：** 验证配置、锁定、开火、死亡、重连和 late join 的 host/remote 一致性。

### 操作

1. [ ] 启动 host 和至少一个 remote，记录双方版本和 package hash。
2. [ ] host 创建/配置舰船，remote 观察 snapshot 和 loadout。
3. [ ] 双方分别执行锁定、开火、命中和死亡流程。
4. [ ] 在 active event/projectile/effect 时让 remote 重连。
5. [ ] 使用 late join 进入当前战斗，检查 snapshot、owner、generation 和表现补偿。
6. [ ] 记录 duplicate/out-of-order/gap/drop、network bytes、queue depth 和错误。

### 通过标准

- [ ] server authority 不被客户端绕过。
- [ ] host/remote 的配置、开火、伤害和死亡状态最终一致。
- [ ] 重连和 late join 不产生 stale owner、重复伤害或孤儿表现。
- [ ] 版本不一致明确失败，不静默分叉模拟。

## 当前记录

状态：`partial / input-blocked`

2026-08-12（Asia/Shanghai）已发现并连接真实 `teardown.exe`（PID 30296）。本次 MCP 运行记录：

- 窗口可恢复、可聚焦；完整客户区截图为 `2560×1440`，亮度/方差有效，前后截图尺寸一致。
- 额外将窗口临时最小化后由 MCP 恢复回归通过（`SC_RESTORE` fallback、客户区 `2560×1440`、焦点有效）。
- `teardown_control` 已通过扫描码和虚拟键码路径发送 W、相对鼠标移动及 LMB 按下/释放；当前会话停在暂停菜单，Teardown Lua 未观察到任何 `AI_TEST|` 输入边沿，前后截图差异接近零，因此不宣称键鼠验证通过。
- 日志游标为 `16252590`；游标前已有 133630 条 warning（主要是 `strikeCraftMain.lua` warning storm）和 12 条 error。本次游标后没有新增完整日志行，未发现本次新增 Lua ERROR。
- 所有 MCP 跟踪的键和鼠标按钮均已释放。完整证据（PNG、动作、日志切片、`result.json`）在仓库外：`%LOCALAPPDATA%\TeardownAI\runs\20260811T161222Z-f45d38d6\`。
- 静态完整 Harness 已通过；本次没有修改 Harness。`Content Mod 2/script` 的 Lua 与 Teardown API 检查均通过。

阻断原因：当前游戏窗口可聚焦但不响应 SendInput 的扫描码或虚拟键码；跨完整性级别的 `WM_KEY*`/鼠标消息也被拒绝。按验证计划，继续证明需要 USB/虚拟 HID 或以与游戏相同完整性级别运行的输入桥接，不能用桌面消息模拟替代。

恢复条件：在同一会话提供可被 Teardown 观察的 USB/虚拟 HID 输入（或重新加载已修改的关卡脚本），再补做 W/LMB 边沿、位置/速度/相机变化和完整 S0；S6/S7 仍需另行实机执行。

## 2026-08-20 当前续跑记录

状态：`partial / external-dependency`

- 重启后的正式 `teardown.exe` 为 PID `188928`，目标 `teardown:188928:853349070`；Mod Manager 客户区 `1280x720`，窗口可聚焦并得到有效新鲜截图。
- Content Mod 2 已从本地文件路径确认并进入官方双人启动流程。Host 为 PID `204660`，Client1 为 PID `199436`；原始 Mod Manager 进程仍为 PID `188928`。
- `CM2_TEST_V1` 在 Host 与 Client 都可独立读取，同一 session 为 `0-902d205a`；Host/Client player id 分别为 `1/2`，两边 `world_host.ready=true`、`generation=1`、`active_instances=3`、`register_count=3`、`rejected_count=0`、`fallback_count=0`，三项 identity 一致。
- Host 截图为有效游戏视口并显示 `Host` HUD；Client1 截图已捕获并显示 `Client1` HUD，但主体视口接近黑色，不能用作视觉通过证据。
- 两边 `vehicle_id=0` 且 scenario `ready=false`，因此本次只证明窗口枚举、目标绑定、截图和共享 telemetry 桥接；不证明 host/remote 配置、锁定、开火、命中、伤害、死亡、重连或 late join。
- S6 没有可执行的专用死船场景，未运行；S7 的完整行为链依赖当前场景未提供的玩家舰船绑定，标记为 `EXTERNAL_DEPENDENCY`。
- 本轮退出 Host 后 `teardown_modtest.exe` 子进程为 `0`，主 `teardown.exe` 保留在 Mod Manager；紧急释放结果为 `keys=[]`、`buttons=[]`。
- 权威证据：`docs/evidence/step-0.3-s0-multiplayer-partial-v2.json`；历史阻断证据 `docs/evidence/step-0.3-environment-blocked.json` 保留不变。运行证据在 `%LOCALAPPDATA%/TeardownAI/runs/20260819T170206Z-70f61c45/`、`20260819T170253Z-0e99e488/` 和 `20260819T170340Z-01fa6b18/`。
