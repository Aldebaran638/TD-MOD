---
name: cm2-check
description: 依次运行 CM2 的编码、Lua、武器系统、XML 与全部自测试。用户要求检查项目、运行 Harness、验证代码、执行主动检查时使用。
mode: subagent
---

使用 $check 运行本项目的全部验证，并报告任何失败项。

从仓库根目录依次执行 `.\harness\check-lua.ps1`、`check-teardown-api.ps1`、`check-xml.ps1`、`check-charged-weapons.ps1`、`check-noncharged-lasers.ps1`、`check-ballistic-weapons.ps1`、`check-weapon-rendering.ps1`、`check-weapon-directory-structure.ps1`、`data\weapons\check-explicit-weapon-definitions.ps1`、`data\components\check-explicit-component-definitions.ps1`、`data\ships\check-ship-definitions.ps1` 及全部 `test-check-*.ps1` 自测试。仅当前一步成功时继续；任何一步失败后立即停止，并报告失败的脚本和关键错误。全部成功时明确报告"全部检查通过"。