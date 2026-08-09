## 目录结构约束

同一目录层级下的文件夹名称必须表达同一种分类维度。不得将作用域（如 `common`）、行为（如 `guided`）、槽位（如 `x`）和实现阶段（如 `beam`）并列在同一层。需要同时表达多个维度时，按“职责 -> 分类维度 -> 具体实现”逐层嵌套。

每次完成代码修改后，必须运行以下检查脚本。如果任何检查失败，先修复问题再结束会话。

```powershell
.\harness\check-lua.ps1 -Path ".\Content Mod 2\script"
.\harness\check-teardown-api.ps1 -Path ".\Content Mod 2\script"
.\harness\check-xml.ps1 -Path ".\Content Mod 2"
.\harness\check-charged-weapons.ps1 -Path ".\Content Mod 2"
.\harness\check-noncharged-lasers.ps1 -Path ".\Content Mod 2"
.\harness\check-ballistic-weapons.ps1 -Path ".\Content Mod 2"
.\harness\check-weapon-rendering.ps1 -Path ".\Content Mod 2"
.\harness\data\weapons\check-explicit-weapon-definitions.ps1 -Path ".\Content Mod 2"
.\harness\data\components\check-explicit-component-definitions.ps1 -Path ".\Content Mod 2"
.\harness\data\ships\check-ship-definitions.ps1 -Path ".\Content Mod 2"
.\harness\test-check-lua.ps1
.\harness\test-check-teardown-api.ps1
.\harness\test-check-xml.ps1
.\harness\test-check-charged-weapons.ps1
.\harness\test-check-noncharged-lasers.ps1
.\harness\test-check-ballistic-weapons.ps1
.\harness\test-check-weapon-rendering.ps1
.\harness\data\weapons\test-check-explicit-weapon-definitions.ps1
.\harness\data\components\test-check-explicit-component-definitions.ps1
.\harness\data\ships\test-check-ship-definitions.ps1
```

如果修改涉及 `Content Mod 2` 以外的脚本目录，也需检查对应路径：
```powershell
.\harness\check-lua.ps1 -Path ".\Global Mod\script"
.\harness\check-teardown-api.ps1 -Path ".\Global Mod\script"
```
