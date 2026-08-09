---
name: check
description: 依次运行 Teardown 模组的 Lua、XML、Teardown API、武器与组件定义检查及自测试。用户要求检查项目、运行 Harness、验证代码、执行主动检查，或显式调用 $check 时使用。
---

# 项目检查

从仓库根目录依次执行下列命令。仅当前一步成功时继续；任何一步失败后立即停止，并报告失败的脚本和关键错误。

```powershell
.\harness\check-lua.ps1 -Path ".\Content Mod 2\script"
if ($?) { .\harness\check-teardown-api.ps1 -Path ".\Content Mod 2\script" }
if ($?) { .\harness\check-xml.ps1 -Path ".\Content Mod 2" }
if ($?) { .\harness\check-charged-weapons.ps1 -Path ".\Content Mod 2" }
if ($?) { .\harness\check-noncharged-lasers.ps1 -Path ".\Content Mod 2" }
if ($?) { .\harness\check-ballistic-weapons.ps1 -Path ".\Content Mod 2" }
if ($?) { .\harness\check-weapon-rendering.ps1 -Path ".\Content Mod 2" }
if ($?) { .\harness\check-weapon-directory-structure.ps1 -Path ".\Content Mod 2" }
if ($?) { .\harness\data\weapons\check-explicit-weapon-definitions.ps1 -Path ".\Content Mod 2" }
if ($?) { .\harness\data\components\check-explicit-component-definitions.ps1 -Path ".\Content Mod 2" }
if ($?) { .\harness\data\ships\check-ship-definitions.ps1 -Path ".\Content Mod 2" }
if ($?) { .\harness\test-check-lua.ps1 }
if ($?) { .\harness\test-check-teardown-api.ps1 }
if ($?) { .\harness\test-check-xml.ps1 }
if ($?) { .\harness\test-check-charged-weapons.ps1 }
if ($?) { .\harness\test-check-noncharged-lasers.ps1 }
if ($?) { .\harness\test-check-ballistic-weapons.ps1 }
if ($?) { .\harness\test-check-weapon-rendering.ps1 }
if ($?) { .\harness\test-check-weapon-directory-structure.ps1 }
if ($?) { .\harness\data\weapons\test-check-explicit-weapon-definitions.ps1 }
if ($?) { .\harness\data\components\test-check-explicit-component-definitions.ps1 }
if ($?) { .\harness\data\ships\test-check-ship-definitions.ps1 }
```

所有命令成功时，明确报告“全部检查通过”。
