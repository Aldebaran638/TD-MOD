# Formal Turret Content Authority v1

## 问题与迁移边界

现有舰船 mount 数据仍有 `firePosOffset`/`fireDirRelative` 兼容读取，主要用于旧武器路径、相机和部分发射器。它们不能继续成为正式炮塔的权威。Hero candidate 将 fire mount 改为 `TurretDefinition` 的 `fireAnchorId`，由 `EntityGraph -> TransformAnchor -> FireContext` 提供世界变换；旧偏移只保留在 migration ledger，不能出现在 formal content 或新 authority 模块中。

## 正式 Hero 内容

`docs/candidates/turret-content-authority-v1.fixture.json` 定义一个双轴、左右镜像的 Hero 炮塔，包含两个 muzzle anchor、一个 weapon group、fixed/logical/visual/joint 四种声明模式，以及 catalog、Editor、Preview、Harness 引用。对应 catalog candidate 为 `turret-content-authority-v1.catalog.json`，运行时 authority 模块是 `Content Mod 2/script/world/adapter/turret_content_authority_v1.lua`。

正式 mount 只允许：

- `mountId -> fireAnchorId -> AnchorResolver`；
- mirror、weaponGroupId、fallbackMode 等内容元数据；
- 由同一 Solver/Anchor/FireContext 供 fixed/logical/visual/joint 使用。

`firePosOffset`、`fireDirRelative`、根 Body muzzle 查询和隐式猜测都会被拒绝。anchor 丢失时，logical/visual/fixed 返回明确的 fallback source，不吞掉错误；joint 在 physical fixture 尚未批准时拒绝切换。

## Catalog、Editor、Preview 与 Harness

Catalog candidate 固定 namespaced `catalogRef`，Editor 只编辑 source fixture/schema，禁止编辑 generated Lua；Preview 使用与正式运行相同的 normalized content DTO，并显示 EntityGraph/anchor/mount tree；Harness 继续执行全项目检查，专用 runner 负责 formal mount、fallback、legacy-field rejection、stale handle 和跨引用闭包。

## 当前结论与回退

离线 runner 可以证明 formal candidate 不依赖固定根 Body muzzle、双 anchor 的位置/镜像稳定、缺 anchor 有可解释 fallback，且 catalog/editor/preview/harness 引用完整。但当前旧 reader 仍存在，且本机没有 Teardown.exe，无法完成 S0-S7 实机开火、网络、性能和视觉验收。因此 catalog 状态保持 `candidate-until-live-S0-S7`，正式默认仍为 logical/visual。若迁移失败，撤销 candidate 注册、恢复旧 mount reader，并保留本 fixture 与 ledger 作为审计和回滚基线。
