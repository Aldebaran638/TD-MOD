# `WeaponPresentationEvent v1` 与 Identity DTO

旁路模块 `Content Mod 2/script/net/presentation_event_v1.lua` 冻结 transport-neutral DTO；当前旧 `ClientCall` 和网络入口不变。

## Identity DTO

- `DefinitionRef { id, schemaVersion }`：定义身份，不代表运行时实体；
- `EntityRef { id, generation }`：运行时实体身份，generation 防止 Body/实体 ID 复用后的 stale event；
- `AnchorRef { entityId, anchorId }`：实体上的稳定 anchor；
- `EffectInstanceRef { id, generation }`：可回收表现实例身份。

事件公共字段为 `protocolVersion`、正整数 `sequence`、`kind`、`source`、可选 `weapon/effect/anchor/effectInstance/transform/target/hit`、非负 `seed`、`priority`、`serverTime` 和 `payload`。v1 kind 固定为：`charge`、`muzzle`、`beam`、`projectile`、`impact`、`sound`、`shake`、`craft_launch`、`craft_recover`。

校验拒绝未知必需协议版本、重复/倒退 sequence、负 generation、非法 reference、callback/functionName/sharedTable/engineHandle 和 userdata/function/thread。未知可选内容只能进入 `extensions`，因此 transport 可按协议版本跳过而不改变核心字段。

`encode`/`decode` 当前是不依赖 Teardown API 的 validated table projection；`semanticEqual` 用于 adapter/fixture 对照。协议一旦接入网络或 generated artifact，字段语义变更只能提升 protocolVersion；回退只切 publisher adapter，保留旧 ClientCall。

