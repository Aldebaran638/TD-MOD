# Turret Physical Joint Actuator v1（Hero Fixture）

## 目的与边界

本 fixture 验证将 `TurretSolver` 的目标角映射到物理关节执行器前，最小可行的限制、速率、扭矩和父体生命周期契约。实现刻意保持为 DTO/纯逻辑适配层，`fixtureOnly = true`，不创建 Teardown `Joint`、不读取实时物理状态，也不改变正式舰船的默认 `Visual Actuator` 路径。

## 契约

- 协议：`cm2.turret-physical-joint/1`。
- 角度：yaw/pitch 使用度；yaw 范围 `[-90, 90]`，pitch 范围 `[-30, 30]`。
- 速率：最大 `60 deg/s`，每帧 `dt` 限制在 `[0, 0.1]`，目标角先限幅再按速率逼近。
- 扭矩：命令扭矩必须不超过 `50`；超限拒绝并计数。
- 生命周期：父体 `active` 才允许应用；父体 `destroyed/disposed` 会将 actuator 置为 `disposed`，后续命令拒绝。
- 身份：`identity + ownerId + generation` 组成句柄；代际变化后旧句柄拒绝。
- 快照：每次有效应用和生命周期操作都可输出 DTO 快照，供未来网络/回放桥接。

## Fixture 与验证

fixture 位于 `docs/candidates/turret-physical-joint-actuator-v1.fixture.json`，离线 runner 位于 `tools/cm2-world-host/run-turret-physical-joint-actuator-v1.ps1`，自测位于 `tools/cm2-world-host/test-turret-physical-joint-actuator-v1.ps1`。覆盖：

1. 目标 `120/-50` 被限幅到 `90/-30`，以 `0.1s` 和 `60 deg/s` 得到 `6/-6`；
2. 第二帧继续逼近到 `12/-12`；
3. 扭矩 `51` 拒绝；
4. 父体销毁后 actuator 处于 `disposed`，命令拒绝；
5. dispose 幂等、快照生命周期一致、旧 generation 句柄拒绝；
6. 静态扫描确认没有 `SetJoint/CreateJoint/GetJoint/JointMotor` 调用。

runner 结果写入 `docs/candidates/turret-physical-joint-actuator-v1.result.json`，要求 applies=2、clamped=1、torqueRejected=1、parentRejects=1、lifecycleChanges=2、snapshots=5、staleRejects=1，且 `fixtureOnly=true`。

## 采用结论与回退

当前只能证明 DTO 契约和边界逻辑，不能证明实际 Joint 的碰撞抖动、孤儿 body、物理/网络/CPU 成本；因为本机没有可发现的 `Teardown.exe`。因此物理模式不进入正式内容，继续以 logical/visual fallback 为默认。获得 live Teardown 压测证据前，回退只需不接入本模块（或全局关闭 physical mode），保留 fixture 和结果作为审计基线。
