---
description: 运行全部代码检查及其自测试
---

运行以下所有代码检查脚本，输出结果并报告是否有任何失败：

```powershell
.\harness\check-lua.ps1 -Path ".\Content Mod 2\script"
if ($?) { .\harness\check-teardown-api.ps1 -Path ".\Content Mod 2\script" }
if ($?) { .\harness\check-xml.ps1 -Path ".\Content Mod 2" }
if ($?) { .\harness\check-charged-weapons.ps1 -Path ".\Content Mod 2" }
if ($?) { .\harness\check-noncharged-lasers.ps1 -Path ".\Content Mod 2" }
if ($?) { .\harness\check-ballistic-weapons.ps1 -Path ".\Content Mod 2" }
if ($?) { .\harness\data\weapons\check-explicit-weapon-definitions.ps1 -Path ".\Content Mod 2" }
if ($?) { .\harness\data\ships\check-battlecruiser-definition.ps1 -Path ".\Content Mod 2" }
if ($?) { .\harness\test-check-lua.ps1 }
if ($?) { .\harness\test-check-teardown-api.ps1 }
if ($?) { .\harness\test-check-xml.ps1 }
if ($?) { .\harness\test-check-charged-weapons.ps1 }
if ($?) { .\harness\test-check-noncharged-lasers.ps1 }
if ($?) { .\harness\test-check-ballistic-weapons.ps1 }
if ($?) { .\harness\data\weapons\test-check-explicit-weapon-definitions.ps1 }
if ($?) { .\harness\data\ships\test-check-battlecruiser-definition.ps1 }
```

如果所有检查通过，报告"全部检查通过"。如果有失败，指出具体哪个脚本报错。
