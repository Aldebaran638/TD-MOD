---
description: 运行所有代码检查脚本（编码、Lua语法、include链）
---

运行以下所有代码检查脚本，输出结果并报告是否有任何失败：

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

如果所有检查通过，报告"全部检查通过"。如果有失败，指出具体哪个脚本报错。
