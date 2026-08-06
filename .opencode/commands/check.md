---
description: 运行五类代码检查及其自测试
---

运行以下所有代码检查脚本，输出结果并报告是否有任何失败：

```powershell
.\harness\check-lua.ps1 -Path ".\Content Mod 2\script"
if ($?) { .\harness\check-teardown-api.ps1 -Path ".\Content Mod 2\script" }
if ($?) { .\harness\check-xml.ps1 -Path ".\Content Mod 2" }
if ($?) { .\harness\check-charged-weapons.ps1 -Path ".\Content Mod 2" }
if ($?) { .\harness\check-noncharged-lasers.ps1 -Path ".\Content Mod 2" }
if ($?) { .\harness\test-check-lua.ps1 }
if ($?) { .\harness\test-check-teardown-api.ps1 }
if ($?) { .\harness\test-check-xml.ps1 }
if ($?) { .\harness\test-check-charged-weapons.ps1 }
if ($?) { .\harness\test-check-noncharged-lasers.ps1 }
```

如果所有检查通过，报告"全部检查通过"。如果有失败，指出具体哪个脚本报错。
