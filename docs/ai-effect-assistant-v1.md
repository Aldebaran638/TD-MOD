# AI Effect Assistant v1

## 目标

Effect Assistant 把自然语言效果描述转成受控 EffectIntent，只组合已批准的 emitter、beam、shockwave、sound、shake 节点。它生成 EffectDefinition source candidate，不生成 Lua，也不允许 AI 创建专用 renderer。

流程为：

    prompt -> EffectIntent -> approved nodes -> normal/critical/ambient profiles
      -> fixed-seed Effect Lab -> human diff -> source definition -> Compiler

## 预算和权限

版本化硬上限为 8 个 emitter、5000 ms duration、priority 0–100、shake 0–1 和 power cost 12。正常配置、critical 配置和 ambient 配置都必须生成；critical/ambient 通过减少 emitter 和 duration 明确降级，而不是偷偷超过 hard cap。Effect Lab 固定 seed 424242，分别记录 near/far 的 accepted/degraded/rejected 结果。

操作边界与 Weapon Assistant 一致：默认拒绝，需人工批准；Core、Global Mod、generated、Lua、网络、Runtime 注册、budget 放宽和 custom-renderer 请求均拒绝。所有效果都声明使用 EffectPlayer + PresentationBudget facade，人工 diff 展示每个 AI 提出的字段，默认不自动发布。

## 回归与证据

运行：

    .\tools\cm2-ai\check-ai-effect-assistant-v1.ps1
    .\tools\cm2-ai\run-ai-effect-assistant-v1.ps1
    .\tools\cm2-ai\test-ai-effect-assistant-v1.ps1

固定语料包括两个合法效果、一个模糊请求、一个超 hard cap 请求、一个缺资源请求和一个 custom renderer/Lua 越权请求。测试要求所有决策匹配、三个 profile 全部通过共享 Compiler、Effect Lab 产生 2 accepted + 2 degraded、重复 determinismHash 相同、Core 差异为 0，并且 AI generated/Core/Lua/network 写入为 0。结果写入 docs/candidates/ai-effect-assistant-v1.result.json。

本步骤的 Effect Lab 是无 Teardown 依赖的确定性诊断。真实粒子/光/声音、压力场景和截图仍需 Teardown.exe；runtime.status=deferred 不应解释为实机渲染已验证。

## 回退

删除候选 Definition 和报告，保留最后一个有效 profile/catalog；关闭 AI provider 不影响现有 EffectPlayer、PresentationBudget、Editor、CLI 或 Runtime。只有 Core 专家经过评审后才能增加新 renderer。

