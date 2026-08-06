# 项目验证要求

每次完成代码修改后，必须运行以下检查脚本。如果任何检查失败，先修复问题再结束会话。

```powershell
.\harness\check-lua.ps1 -Path ".\Content Mod 2\script"
.\harness\check-teardown-api.ps1 -Path ".\Content Mod 2\script"
.\harness\check-xml.ps1 -Path ".\Content Mod 2"
.\harness\check-charged-weapons.ps1 -Path ".\Content Mod 2"
.\harness\check-noncharged-lasers.ps1 -Path ".\Content Mod 2"
.\harness\test-check-lua.ps1
.\harness\test-check-teardown-api.ps1
.\harness\test-check-xml.ps1
.\harness\test-check-charged-weapons.ps1
.\harness\test-check-noncharged-lasers.ps1
```

如果修改涉及 `Content Mod 2` 以外的脚本目录，也需检查对应路径：

```powershell
.\harness\check-lua.ps1 -Path ".\Global Mod\script"
.\harness\check-teardown-api.ps1 -Path ".\Global Mod\script"
```

需要主动执行整套项目检查时，使用项目 Skill：`$check`。

## Harness 与检查器维护约束

Harness 和项目检查脚本仅用于验证实现。除非用户明确要求修改检查体系，否则不得修改 `harness/check-*.ps1`、`harness/test-check-*.ps1`、Harness 固件或测试夹具来适配本轮代码；检查失败时应修复产品代码，或如实报告检查器契约已经过时。
