每次完成代码修改后，必须运行以下检查脚本。如果任何检查失败，先修复问题再结束会话。

```powershell
.\check-encoding.ps1 -Path ".\Content Mod 2"
.\check-lua.ps1 -Path ".\Content Mod 2\script"
.\check-weapon-system.ps1 -Path ".\Content Mod 2"
.\check-strike-craft-motion.ps1 -Path ".\Content Mod 2"
.\check-xml.ps1 -Path ".\Content Mod 2"
.\test-check-encoding.ps1
.\test-check-lua.ps1
.\test-check-weapon-system.ps1
.\test-check-strike-craft-motion.ps1
.\test-check-xml.ps1
```

如果修改涉及 `Content Mod 2` 以外的脚本目录，也需检查对应路径：
```powershell
.\check-encoding.ps1 -Path ".\Global Mod\script"
.\check-lua.ps1 -Path ".\Global Mod\script"
```
