# AI Weapon Assistant v1

## 目标

Weapon Assistant 是 Gate 10 的第一个创作入口。它把自然语言先解析成可审计的 WeaponIntent，再生成受 Schema 约束的 Weapon、Projectile、Effect source candidate。它不会生成 Lua，不会写 Core/Global/generated，也不会自动发布。

固定流程为：

    prompt -> WeaponIntent -> schema-constrained patch -> deterministic lint
      -> human diff -> source definition -> shared Compiler
      -> headless Weapon Range/Effect Lab

## 安全边界

只允许 authoring-candidate、json-patch、validator-read 和 preview-read。行为与效果类型必须来自已注册白名单；fire rate、projectile speed、damage、DPS 和 effect priority 必须通过版本化预算。路径遍历、Core、Global Mod、generated、Lua、网络和 Runtime 注册请求一律拒绝。缺少行为或效果类型属于 repair，而不是猜测后发布。

接受的候选会在临时目录生成三个 source envelope，并交给 tools/cm2-compiler/compile-definitions.ps1。Compiler 输出、catalog hash 和 Range/Effect Lab replay hash 都进入报告，但只保存在 disposable temp；人工 diff 显示所有 AI 提出的字段，保存前必须人工批准。

## 回归与证据

运行：

    .\tools\cm2-ai\check-ai-weapon-assistant-v1.ps1
    .\tools\cm2-ai\run-ai-weapon-assistant-v1.ps1
    .\tools\cm2-ai\test-ai-weapon-assistant-v1.ps1

固定语料包含两个合法候选、一个模糊请求、一个超预算请求、一个缺资源请求和一个 Lua/Global Mod 越权请求。测试要求所有预期决策一致、合法率和接受候选 Compiler 通过率为 1.0、重复运行 determinismHash 相同、Core 差异为 0，并且 generated/Core/Lua/network 写入均为 0。结果写入 docs/candidates/ai-weapon-assistant-v1.result.json。

当前实现的 Range/Effect Lab 是无 Teardown 依赖的确定性诊断；真实 Preview 试射、截图、帧时间和玩家体验仍需 Teardown.exe，不能由本步骤的 headless 结果冒充。

## 回退

撤销时删除候选和报告，保留最后一个有效 source/generated catalog；关闭 AI provider 不影响 Editor、CLI、Compiler 或 Runtime。任何模型、prompt、Schema、预算或验证器升级都必须提升版本并重新运行全部固定语料。

