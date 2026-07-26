---
name: check
description: 依次运行 Teardown 模组的编码、Lua/API/include、武器系统、XML 及其自测试。用户要求检查项目、运行 Harness、验证代码、执行主动检查，或显式调用 $check 时使用。
---

# 项目检查

从仓库根目录依次执行下列命令。仅当前一步成功时继续；任何一步失败后立即停止，并报告失败的脚本和关键错误。

```powershell
.\check-encoding.ps1 -Path ".\Content Mod 2"
if ($?) { .\check-lua.ps1 -Path ".\Content Mod 2\script" }
if ($?) { .\check-weapon-system.ps1 -Path ".\Content Mod 2" }
if ($?) { .\check-strike-craft-motion.ps1 -Path ".\Content Mod 2" }
if ($?) { .\check-xml.ps1 -Path ".\Content Mod 2" }
if ($?) { .\test-check-encoding.ps1 }
if ($?) { .\test-check-lua.ps1 }
if ($?) { .\test-check-weapon-system.ps1 }
if ($?) { .\test-check-strike-craft-motion.ps1 }
if ($?) { .\test-check-xml.ps1 }
```

所有命令成功时，明确报告“全部检查通过”。
