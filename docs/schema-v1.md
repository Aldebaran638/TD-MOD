# Source Envelope 与核心 Schema v1

## Envelope

每个可编译 Definition 都是一个 source envelope，公共字段固定为：

```json
{
  "schemaVersion": "cm2.weapon/1",
  "id": "cm2:weapon.ray",
  "kind": "weapon",
  "runtime": {},
  "editor": {"displayName": "Ray"},
  "ai": {"roles": ["direct-fire"]},
  "build": {"sourcePath": "definitions/weapon/ray.json", "revision": "local", "budgetClass": "standard"}
}
```

`runtime` 是 Teardown 运行时唯一需要的语义；`editor` 保存显示/作者信息，`ai` 保存规划输入，`build` 保存 provenance、资源和预算信息。后面三段不能通过运行时 Lua table 反向覆盖 runtime。

## v1 覆盖范围

第一版固定六类核心 Definition：`weapon`、`projectile`、`effect`、`vehicle`、`mount`、`turret`。它们足以表达普通射线、普通弹道、制导弹、战巡和 Titan 的最小运行语义；复杂表现通过 effect 引用扩展，不把 renderer 细节塞进 weapon。另有七类可被核心引用的 supplemental Definition：`part`、`anchor`、`damage`、`sound`、`targetFilter`、`flight`、`component`，同样声明完整字段元数据，但不扩大本阶段的编译纵切。

每个字段的机器可读元数据在 `schemas/cm2/source-envelope-v1.json`，包含 `type`、`unit`、`range`、`default`、`runtimeRequired`、`referenceKind` 和 `budgetImpact`。新增字段先作为 optional；改变已有字段语义必须提升 schema major。

| kind | v1 runtime 必需字段 | 典型引用 |
|---|---|---|
| weapon | behavior、effectId、fireRateHz | effect、projectile |
| projectile | speedMps、damage、effectId | effect |
| effect | effectType、assetId、priority | asset |
| vehicle | controlMode、massKg、mountId | mount |
| mount | parentId、localTransform、slotType | vehicle |
| turret | weaponId、mountId、traverseSpeedDeg | weapon、mount |

## 校验与兼容

校验失败必须包含 `definition id`、`field path`、`expected`、`actual` 和 `suggestion`。`unknown-field`/`deprecated-field` 默认是 warning；非法 ID、缺引用、范围错误是 error；future major version 是 fatal。未支持的 legacy 字段只能进入显式 adapter，不能进入 AI 公共合同。

`harness/data/schemas/cm2-schema-v1-fixtures.json` 为每个 kind 提供 valid、missing、wrong-type、out-of-range、broken-reference、future-version 六类生成 fixture。`harness/check-schema-v1.ps1` 验证 catalog、引用闭包、范围和诊断格式；不宣称 Teardown 实机可运行。
