# 战列巡洋舰服务端入口规范

`script/shipMain.lua` 是单艘战列巡洋舰的服务端组合入口，不是全局飞船管理器。

## 入口职责

- 初始化 `server.shipBody`。
- 注册并维护当前飞船的 Registry 状态。
- 按依赖顺序 include 数据、访问层和业务模块。
- 在生命周期函数中调用各模块入口。

入口文件不得实现具体武器结算、移动计算或特效逻辑。

## 目录边界

- `data/ships/`：飞船配置与目录。
- `data/weapons/<slot>/`：按槽位存放武器配置。
- `ship/battlecruiser/server/bootstrap/`：飞船初始化。
- `ship/battlecruiser/server/control/`：飞船级开火编排。
- `ship/battlecruiser/server/movement/`：移动与姿态。
- `ship/battlecruiser/server/registry/`：Registry 访问层。
- `ship/battlecruiser/server/state/`：飞船运行状态。
- `weapon/server/common/`：跨武器共享服务。
- `weapon/server/guided/`：M/G 槽共享制导弹运行时。
- `weapon/server/slots/<slot>/<weapon>/`：具体武器的状态与控制。

槽位只负责槽位级状态和调度；具体武器的蓄力、发射、弹丸和命中逻辑归具体武器。

## Tick 约束

`server.serverTick(dt)` 只做状态确保和模块调度。业务逻辑必须放在所属模块中。

飞船状态统一通过 Registry API 读写，不要在业务模块中重复拼接 Registry 根路径。

Lua 文件统一使用小写 `snake_case`；引擎入口 `shipMain.lua` 保留既有名称。
