# EntityGraph / Part / Anchor Resolver v1

## 图模型

定义层由唯一 `nodeId`、`parentId`、`partId`、`kind` 和 anchor 列表组成，必须恰好一个 root；part/anchor ID 在同一 graph 内全局唯一。加载时先检查 parent 存在，再做有色 DFS，缺失 parent、重复 ID 和循环引用都拒绝，不会留下半成品 graph。

运行层以同一 `nodeId` 绑定 `bodyId`、`shapeId`、`jointId`、transform、owner 和 generation。绑定前校验 graph generation/owner，绑定后递增 runtime revision 并清空 part/anchor cache。解析结果包含 identity、owner、generation、definition/runtime revision，因此 Body ID 重用或 scene reload 后的旧结果可被拒绝。

## Resolver API

- `loadDefinition(definition)`：校验并冻结定义关系。
- `bindRuntime(runtimeGraph)`：绑定现有单根/子 Body 实例，不创建新物理布局。
- `resolvePart(partId)`：返回稳定 part 引用和 runtime handles。
- `resolveAnchor(anchorId)`：返回 node/body/shape、localTransform 与 runtime world transform。
- `snapshot()`：输出可对照 DTO；`getDiagnostics()` 记录 loads/binds、命中、失败、stale、owner 和 cycle。

shipMain 与 strikeCraftMain 先为现有 root Body 建立 root graph，再逐步允许后续 mount/camera/engine/effect 系统接入。旧 mount resolver 仍是行为权威。

## 回退与限制

若 S1 mount 数量、坐标或运行时 handle 与旧 golden 不一致，按系统旁路 EntityGraph，保留旧 resolver 只读对照和 negative fixtures。当前没有 Teardown.exe，无法验证真机 Shape/Joint 枚举、重载后 handle、坐标 goldens 或运行时查询成本；离线 fixture 只证明 DTO 拓扑和代际/owner 契约。
