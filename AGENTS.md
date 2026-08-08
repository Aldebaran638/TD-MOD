# 项目验证要求

每次完成代码修改后，必须通过完整 Harness 检查。如果任何检查失败，先修复问题再结束会话。提交前由仓库 Git `pre-commit` Hook 自动执行同一套检查。

```powershell
.\harness\check-all.ps1
```

检查入口按以下顺序运行：

```powershell
.\harness\check-lua.ps1 -Path ".\Content Mod 2\script"
.\harness\check-teardown-api.ps1 -Path ".\Content Mod 2\script"
.\harness\check-xml.ps1 -Path ".\Content Mod 2"
.\harness\check-charged-weapons.ps1 -Path ".\Content Mod 2"
.\harness\check-noncharged-lasers.ps1 -Path ".\Content Mod 2"
.\harness\check-ballistic-weapons.ps1 -Path ".\Content Mod 2"
.\harness\data\weapons\check-explicit-weapon-definitions.ps1 -Path ".\Content Mod 2"
.\harness\data\components\check-explicit-component-definitions.ps1 -Path ".\Content Mod 2"
.\harness\data\ships\check-ship-definitions.ps1 -Path ".\Content Mod 2"
.\harness\test-check-lua.ps1
.\harness\test-check-teardown-api.ps1
.\harness\test-check-xml.ps1
.\harness\test-check-charged-weapons.ps1
.\harness\test-check-noncharged-lasers.ps1
.\harness\test-check-ballistic-weapons.ps1
.\harness\data\weapons\test-check-explicit-weapon-definitions.ps1
.\harness\data\components\test-check-explicit-component-definitions.ps1
.\harness\data\ships\test-check-ship-definitions.ps1
```

如果修改涉及 `Content Mod 2` 以外的脚本目录，也需检查对应路径：

```powershell
.\harness\check-lua.ps1 -Path ".\Global Mod\script"
.\harness\check-teardown-api.ps1 -Path ".\Global Mod\script"
```

需要主动执行整套项目检查时，使用项目 Skill：`$check`。

## Harness 与检查器维护约束

Harness 和项目检查脚本仅用于验证实现。除非用户明确要求修改检查体系，否则不得修改 `harness/check-*.ps1`、`harness/test-check-*.ps1`、Harness 固件或测试夹具来适配本轮代码；检查失败时应修复产品代码，或如实报告检查器契约已经过时。

## Git 提交信息规范

提交信息必须使用“提交性质: 注释”格式。提交性质使用简短类别，例如：

- `feat`: 新功能
- `fix`: 缺陷修复
- `refactor`: 重构
- `docs`: 文档
- `test`: 测试或 Harness
- `chore`: 构建、配置或维护

示例：`feat: 统一弹道武器配置字段`。
