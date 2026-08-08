# 项目验证要求

每次完成代码修改后，必须运行以下检查脚本。如果任何检查失败，先修复问题再结束会话。

```powershell
.\harness\check-lua.ps1 -Path ".\Content Mod 2\script"
.\harness\check-teardown-api.ps1 -Path ".\Content Mod 2\script"
.\harness\check-xml.ps1 -Path ".\Content Mod 2"
.\harness\check-charged-weapons.ps1 -Path ".\Content Mod 2"
.\harness\check-noncharged-lasers.ps1 -Path ".\Content Mod 2"
.\harness\check-ballistic-weapons.ps1 -Path ".\Content Mod 2"
.\harness\data\weapons\check-explicit-weapon-definitions.ps1 -Path ".\Content Mod 2"
.\harness\data\ships\check-battlecruiser-definition.ps1 -Path ".\Content Mod 2"
.\harness\test-check-lua.ps1
.\harness\test-check-teardown-api.ps1
.\harness\test-check-xml.ps1
.\harness\test-check-charged-weapons.ps1
.\harness\test-check-noncharged-lasers.ps1
.\harness\test-check-ballistic-weapons.ps1
.\harness\data\weapons\test-check-explicit-weapon-definitions.ps1
.\harness\data\ships\test-check-battlecruiser-definition.ps1
```

如果修改涉及 `Content Mod 2` 以外的脚本目录，也需检查对应路径：

```powershell
.\harness\check-lua.ps1 -Path ".\Global Mod\script"
.\harness\check-teardown-api.ps1 -Path ".\Global Mod\script"
```

> Codex 实际通过仓库根目录的 `AGENTS.md` 自动加载这些要求；本文件是 `.codex` 内的等效配置副本。

## Teardown 官方特殊头文件

- `#include "script/include/common.lua"` 是 Teardown 官方提供的特殊头文件。
- 该文件不应当在模组目录中查找、创建、复制或作为缺失依赖处理。

群星文件夹地址:
"D:\SteamLibrary\steamapps\common\Stellaris"
