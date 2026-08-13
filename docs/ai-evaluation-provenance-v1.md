# AI 评测、权限边界与 Provenance v1

## 目标与范围

Step 10.1 只建立可审计的 AI 生成评测闸门，不把模型接入游戏运行时，也不允许 AI 直接修改 Core、Runtime、Lua 或 generated 产物。AI 的输出只能作为待人工审核的 source-definition candidate；通过后仍必须由既有 Schema/Compiler/SDK 流程生成正式产物。

本版本使用固定十类回归语料：normal、ambiguous、conflict、budget-overflow、missing-resource、malicious-path、lua-request、manual-edit、generated-write、missing-provenance。评测器是可重复的规则替身，使用固定 seed、modelVersion、toolVersion、inputHash、promptHash 和 validatorVersion，以便未来替换模型时比较行为变化。

## 权限与数据流

允许的操作只有 authoring-candidate、json-patch、validator-read 和 preview-read；默认拒绝，且需要人工批准。generated-artifact-write、core-write、lua-write、Schema/预算放宽、文件系统、网络和 Runtime 注册全部拒绝。路径遍历、Global Mod、Core、generated 和 Lua 目标即使声明了其他权限也会拒绝。

评测顺序为：Provenance 完整性 → 操作白名单 → 权限拒绝表 → 路径边界 → ID/预算验证 → 可修复问题 → 人工编辑复核 → 接受。任何接受结果都只产生 deferred:<candidateHash> 的待构建标记，不生成或覆盖文件。

## 使用与证据

    .\tools\cm2-ai\check-ai-evaluation-v1.ps1
    .\tools\cm2-ai\run-ai-evaluation-v1.ps1
    .\tools\cm2-ai\test-ai-evaluation-v1.ps1

结果写入 docs/candidates/ai-evaluation-provenance-v1.result.json。报告应有十条评测、legalRate=1.0、重复运行相同 determinismHash，并记录每条候选的完整 Provenance 与零 Runtime/generated/Core/network 写入。当前报告为 evaluation-only；没有 Teardown 实机依赖，Runtime 执行不会被伪装成已验证。

## 回退与升级

回退时删除候选报告并保留最后一个有效 source/build；不得用 AI 输出覆盖生成物。若升级模型、提示词、验证器、Schema 或预算策略，必须提升对应版本/哈希，重新运行十类语料并由人工比较报告后才可改变策略。任何 legal rate 或 determinism 下降都阻止接入下一阶段。

