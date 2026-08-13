# AI Creator Beta 与质量阈值 v1

## Gate 目标

Beta gate 组合 Weapon Assistant、Effect Assistant、Existing-VOX Import Assistant 和 Creator SDK conformance，并把“headless 通过”与“官方 Beta 可发布”分开。质量不是视觉 Demo，而是普通作者能完成、错误可修复、预算可控、来源可追溯。

固定指标包括：

- 首次/最终 Schema 合法率；
- 平均人工修改字段数；
- prompt 到第一次 Preview 的 p95；
- 超预算拒绝/降级率；
- anchor 返工次数；
- 用户查看 Lua 次数（目标为 0）；
- S1/S5 运行时预算；
- Compiler、Preview、package conformance 和安全零绕过。

官方 Beta 还要求至少 5 名非 Core 作者完成 Weapon/Effect、至少 3 名完成 Existing-VOX Ship，且必须有 Teardown 实机 S1/S5 证据。headless simulation 永远不计入外部作者。

## Gate 结果语义

pass 表示 headless、外部作者和 Runtime 证据全部满足；fail 表示 headless 质量/安全本身失败；unable 表示 headless 质量通过，但外部作者或 Teardown 证据缺失，可以继续作为内部 Framework，不得扩大 Beta 兼容承诺。

当前 fixture 中四套 suite 全部 headless 通过，安全计数器为零，质量指标达标；外部作者验证数为 0，Teardown.exe 不可用，因此 gate 有意报告 unable。

## 回归与回退

运行：

    .\tools\cm2-ai\check-ai-creator-beta-v1.ps1
    .\tools\cm2-ai\run-ai-creator-beta-v1.ps1
    .\tools\cm2-ai\test-ai-creator-beta-v1.ps1

报告写入 docs/candidates/ai-creator-beta-v1.result.json。重复运行 determinismHash 必须一致。回退时关闭 Beta 邀请，保留内部 Assistant/SDK 和已有有效包；provider、Editor 或 AI 移除后，手工 Editor/CLI/Compiler 流程仍可维护项目。

