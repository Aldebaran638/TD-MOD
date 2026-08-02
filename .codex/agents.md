# 项目验证要求

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

> Codex 实际通过仓库根目录的 `AGENTS.md` 自动加载这些要求；本文件是 `.codex` 内的等效配置副本。

## Teardown 官方特殊头文件

- `#include "script/include/common.lua"` 是 Teardown 官方提供的特殊头文件。
- 该文件不应当在模组目录中查找、创建、复制或作为缺失依赖处理。
