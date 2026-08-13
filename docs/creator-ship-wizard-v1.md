# Creator Ship Wizard MVP v1

Creator Ship Wizard 是面向非 Core 作者的 source-only 工作流。它按固定顺序编排现有的 Asset Import、Schema/Compiler、Anchor/Mount 与 Preview 能力，不实现第二套隐藏编译器：

`Select VOX → Import Report → Scale/Forward/Up → Single-body Template → HP/Flight/Camera/Engine → Effect Anchors/Mounts → Loadout → Validate/Build → Ship Dock → Weapon Range`

## 确定性构建

`tools/cm2-wizard/run-creator-ship-wizard-v1.ps1` 读取 Step 8.1 AssetManifest，验证 Gamma 单 Body VOX 的 SHA-256、`+Y` up、`-Z` forward、0.1 m/voxel 与 `1 Body / 1 Shape / 0 Joint` 预算。所有字段、Anchor、Mount、引用和边界在写盘前 fail closed。

合法输入只写入 disposable staging：

- `docs/candidates/generated/creator-ship-wizard-v1/package.manifest.json`
- `docs/candidates/generated/creator-ship-wizard-v1/vehicle.definition.json`
- `docs/candidates/generated/creator-ship-wizard-v1/anchor-mount.definition.json`
- `docs/candidates/generated/creator-ship-wizard-v1/catalog.projection.json`

报告记录 source、build、package 和每个产物的哈希。两次干净构建必须 byte-identical。`catalog.projection.json` 明确为只读候选，`runtimeRegistration=false`；构建器不修改源 fixture、VOX、Core Lua 或 Runtime catalog。

## 失败门与回退

自测试覆盖错误步骤顺序、缺失 VOX、未确认坐标、Anchor 越界、非法 mass、缺失 engine anchor、Core 边界违规和不可定位诊断。每个拒绝用例必须在 staging 目录创建前失败，不留下半成品。

回退方式是删除 disposable staging 并恢复上一份合法 source candidate。因为正式 Runtime 权威从未被写入，所以回退不需要清理运行时注册。

## Teardown 实机表面

`Content Mod 2/_ai_scenario_creator_ship_wizard.xml` 加载真实 Gamma VOX 和 `creator_ship_wizard_controller.lua`。真实方向键、Delete、Space 和 Enter 验证步骤推进、阻断、人工修复、回退、Build、Ship Dock 与 Weapon Range Preview；F4 返回 Level Editor，随后执行 emergency release。

该场景只验证 Wizard/Preview 编排。Weapon Range 的 Space 触发是合成表现回放，不能证明任何真实武器可由 LMB 命中或造成伤害；武器合同仍必须走真实 LMB → weapon runtime → hit → damage → HP telemetry 链路。

工程验收可以自动判断字段、哈希、边界、控件、可见性、日志与清理。主观视觉品质和创作者手感仍保留人工审阅。
