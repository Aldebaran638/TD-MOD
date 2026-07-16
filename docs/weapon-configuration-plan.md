# CM2 武器配置系统改造计划

## 适用范围

本计划只适用于：

- `Content Mod 2/script/`
- 神秘战列巡洋舰脚本
- 新武器配置系统及其 UI

本阶段不处理：

- `Global Mod/`
- `script_titan/`
- `script_riddle_escort/`

## 总体目标

将飞船框架与具体武器配置分离，使玩家可以在客户端 UI 中为每个武器槽独立选择武器。

遵守两个结构原则：

1. 船体系统与武器系统分离。
2. 运行脚本与纯配置数据分离。

## 第一阶段：建立 Harness

状态：已完成。

### 编码检查

脚本：

- `check-encoding.ps1`
- `test-check-encoding.ps1`

检查内容：

- UTF-8 BOM
- UTF-16 LE/BE
- 疑似无 BOM UTF-16
- 损坏的 UTF-8
- 可能的 ANSI/GBK 编码
- 非 CRLF 换行符

### Lua 与 Include 检查

脚本：

- `check-lua.ps1`
- `test-check-lua.ps1`

检查内容：

- Lua 语法错误
- 缺失的 `#include`
- 格式错误的 `#include`
- 越出检查根目录的 include
- 循环 include 调用链
- Teardown 内置 `script/include/...` 特殊引用

## 第二阶段：整理文件夹结构

状态：已完成，并已通过 Teardown 实机验证。

当前核心结构：

```text
Content Mod 2/script/
├── shipMain.lua
├── client.lua
├── ship/
│   └── battlecruiser/
│       ├── client/
│       └── server/
├── weapon/
│   ├── client/
│   └── server/
└── data/
    ├── ship/
    └── weapon/
        ├── x/
        ├── l/
        ├── m/
        ├── g/
        └── h/
```

完成内容：

- 船体代码移动到 `ship/battlecruiser/`。
- 武器代码移动到 `weapon/`。
- 飞船配置移动到 `data/ship/`。
- 武器配置移动到 `data/weapon/`。
- 所有 `#include` 路径已经更新。
- 根入口 `script/shipMain.lua` 保持不变。
- 未修改现有武器行为和状态机。

## 第三阶段：武器配置 UI MVP

状态：下一步执行。

### 目标

编写一个与当前战斗系统隔离的客户端 UI 模块，用于验证玩家能否为每个具体武器槽独立选择武器。

第一版流程：

```text
打开武器配置 UI
        ↓
读取战巡武器框架
        ↓
显示框架中的具体武器槽
        ↓
读取对应槽位可选择的武器
        ↓
玩家为每个槽位选择武器
        ↓
在客户端内存中生成 loadout
```

### MVP 必须完成

1. 从飞船数据中读取当前武器框架。
2. 为每个实际槽位生成稳定的槽位标识，例如 `X1`、`X2`、`L1`、`L2`。
3. 从武器数据中读取武器类型和基础展示信息。
4. 根据槽位类型列出可选择武器。
5. 支持玩家切换每个槽位安装的武器。
6. 将选择结果保存在客户端 Lua 内存中。
7. 能够在 UI 中查看当前生成的完整 loadout。

### MVP 暂不实现

- 不写入 Registry。
- 不修改当前服务端武器状态机。
- 不实际替换战斗中的武器。
- 不进行反作弊或复杂权限验证。
- 不实现配置持久化。
- 不同步给其他客户端。

### 隔离要求

新 UI 代码应放在：

```text
Content Mod 2/script/weapon/client/config_ui/
```

在 MVP 验证完成前，新模块不应直接修改现有武器控制器、伤害代码或服务端 loadout。

## 第四阶段：服务端接入

状态：第三阶段完成后执行。

计划流程：

```text
客户端完成配置
        ↓
玩家点击应用
        ↓ ServerCall
发送完整 loadout
        ↓
服务端保存到当前飞船的 Lua 内存
        ↓
服务端按照新配置重建武器运行状态
```

原则：

- 客户端负责决定配置。
- 服务端负责接收并执行配置。
- 不使用 Registry 保存完整武器配置。
- 服务端只做防止脚本报错所需的最低限度检查。
- 配置只在初始化或玩家应用更改时同步，不进行每帧同步。

## 每阶段完成条件

每次修改完成后必须运行：

```powershell
.\check-encoding.ps1 -Path ".\Content Mod 2\script"
.\check-lua.ps1 -Path ".\Content Mod 2\script"
.\test-check-encoding.ps1
.\test-check-lua.ps1
```

涉及运行逻辑、生命周期或 include 路径变化时，还必须进入 Teardown 进行实机验证。
