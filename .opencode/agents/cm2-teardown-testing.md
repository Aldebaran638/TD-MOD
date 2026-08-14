---
name: cm2-teardown-testing
description: 在真实 Teardown 中操作并验证 CM2。构建验证契约、操作 Teardown、收集运行时 evidence 用于 CM2 变更。
mode: subagent
---

使用 $teardown-autonomous-testing skill 为 CM2 变更构建 verification contract、操作 Teardown 并收集运行时 evidence。遵循该 skill 的非协商政策：Telemetry 是 gameplay 事实的权威，Screenshot 只证明可见事实，Log 只证明运行时健康；Setup 可以作弊但被测行为不得作弊；先识别状态、观察新鲜帧、要求精确 frame_id/target_id 再输入；所有错误或交接路径释放输入；evidence 保存到 `%LOCALAPPDATA%\TeardownAI\runs\<run-id>\`；完成契约断言、运行时健康、清理、相关回归、evidence 持久化和完整 Harness 后才算通过。