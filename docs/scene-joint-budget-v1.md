# Scene-wide Joint Budget v1

## 目标

所有物理炮塔 Joint 必须先向场景预算申请，不能由单艘飞船私自创建。预算把物理 Joint、Body/Shape、网络和 FX 成本放在同一份可审计 DTO 中；超限时只改变执行模式，不改变服务端目标、开火语义或生命周期。

默认参考值为 active physical turret hard cap=16、soft cap=12；Hero fixture 使用更小的 hard cap=4、soft cap=3，以便在离线测试中强制覆盖边界。

## 分配规则

1. 请求必须携带稳定 `id`、`ownerId`、generation 句柄、`jointCost`、`physicsBodies`、`physicsShapes`、`networkCost` 和 `fxCost`。
2. 排序分数由 priority、距离、屏幕相关性、玩家交互和 destruction requirement 组成；同分按请求 ID 排序，确保回放确定性。
3. `critical/high`、玩家交互或 destruction-required 请求可使用 hard cap；普通/低优先级请求只使用 soft cap。
4. hard cap 永远不能突破。没有物理名额的请求降级为声明的 `logical-only` 或 `visual-only`，保留同一个 Solver/Anchor/FireContext。
5. 由降级恢复为 Joint 时需要 `recoveryMargin` 的余量；否则保持原 fallback 并记录 `hysteresis-hold`，避免边界帧抖动。
6. 每次请求、决策、释放、owner dispose 和 scene metric 更新都写入有序 replay event，事件包含 frame/sequence/原因。

## 观测指标

报告同时输出 requested/granted/downgraded/rejected、active Joint cost、Body/Shape、active/degraded network/FX cost、recoveries、hysteresis holds、owner disposal 和 scene metrics。这样 Definition budget、physics profiler、network profiler 与 FX budget 可引用同一份事件序列。

## 离线验证与回退

`docs/candidates/scene-joint-budget-v1.fixture.json` 覆盖四个请求：两个 high/critical 请求首先占满 hard cap，第三个 high 请求被滞回保持降级，远端 low 请求在 soft cap 下视觉降级；释放 owner 后逐步恢复，并检查 duplicate/stale handle、场景指标、owner dispose 和连续 replay。runner 为 `tools/cm2-world-host/run-scene-joint-budget-v1.ps1`，自测为同目录的 `test-scene-joint-budget-v1.ps1`，结果写入 `docs/candidates/scene-joint-budget-v1.result.json`。

当前模块为 `fixtureOnly`，不调用任何 Teardown Joint API。由于本机没有 `Teardown.exe`，无法证明 S1/S5 长场景 hard-cap 压力、实际物理抖动或 live profiler 数值；正式运行保持 Visual/Logical fallback。若未来接入失败，移除该适配器注册即可回到 Visual Actuator，保留 fixture/replay 作为回滚基线。
