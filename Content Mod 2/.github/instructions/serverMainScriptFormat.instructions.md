# 服务器主脚本格式

当前项目以 **Registry** 作为跨脚本共享状态载体，不再使用 `server.ships` 作为跨文件状态源。

## 当前飞船上下文（重点）

- `shipMain.lua` 对应的是“当前这艘飞船”的主脚本，不是全局飞船管理器。
- 主脚本通过 `server.shipBody` 记录“自己正在维护的飞船 bodyId”。
- 主脚本内的初始化、确保存在、模块调度，都围绕 `server.shipBody` 这一艘船展开。
- 新代码不要再写旧式的“传入任意 `shipBodyId` 做通用管理”的主脚本函数模板。

## 推荐 Registry 键结构（示意）

```lua
StellarisShips/server/ships/byId/<bodyId>/exists
StellarisShips/server/ships/byId/<bodyId>/shipType
StellarisShips/server/ships/byId/<bodyId>/shieldHP
StellarisShips/server/ships/byId/<bodyId>/armorHP
StellarisShips/server/ships/byId/<bodyId>/bodyHP
StellarisShips/server/ships/byId/<bodyId>/driverPlayerId
StellarisShips/server/ships/byId/<bodyId>/moveState
StellarisShips/server/ships/byId/<bodyId>/move/request
StellarisShips/server/ships/byId/<bodyId>/move/requestState
StellarisShips/server/ships/byId/<bodyId>/xSlots/count
StellarisShips/server/ships/byId/<bodyId>/xSlots/<i>/weaponType
StellarisShips/server/ships/byId/<bodyId>/xSlots/<i>/cd
StellarisShips/server/ships/byId/<bodyId>/xSlots/<i>/request
StellarisShips/server/ships/byId/<bodyId>/xSlots/<i>/state
```

## 脚本组织建议

- 目录约定（与客户端分层风格一致）：
	- `server/registry/`：Registry 访问层
	- `server/weapon_fire/`：武器发射类模块（如 `xSlotControl.lua`）
	- `server/movement/`：移动类模块
	- 未来可扩展：`server/broadcast/`、`server/input/`、`server/simulation/` 等
- 主脚本只做：
	- 当前飞船 body 的初始化
	- 访问层 include
	- 业务模块 include
	- 生命周期入口分发

## 主脚本推荐函数

主脚本应优先提供“当前飞船语义”的函数，而不是旧的通用多船函数：

```lua
function server.registerCurrentShip(shipType)
	-- 把 server.shipBody 对应的当前飞船注册到 Registry
end

function server.ensureCurrentShipState(shipType)
	-- 确保 server.shipBody 对应的当前飞船在 Registry 中存在
end
```

这两个函数内部可以调用统一访问层，例如：

```lua
server.registryShipRegister(server.shipBody, shipType, defaultShipType)
server.registryShipEnsure(server.shipBody, shipType, defaultShipType)
server.registryShipGetSnapshot(server.shipBody)
```

## 初始化建议

- `server.init()` 里先找到当前飞船 body（例如 `FindBody("launcher", false)`）。
- 把结果写入 `server.shipBody`。
- 紧接着调用 `server.registerCurrentShip(...)`，让当前飞船在 Registry 中完成首帧注册。
- 模块自己的局部运行态（如武器状态机缓存）也在这里初始化。

## Tick 约束（强制）

`server.serverTick(dt)` 中不允许出现具体业务逻辑，只允许：

1. 确保当前飞船 Registry 状态存在
2. 调用各模块主 Tick

示意：

```lua
function server.serverTick(dt)
	DebugWatch("server.serverTick", 112221)
	server.ensureCurrentShipState(defaultShipType)
	server.xSlotControlTick(dt)
end
```

具体业务（状态机、广播、命中结算、推进力计算等）必须放在模块文件中。

## 禁止事项

- 不要在主脚本里直接散写 `SetInt`、`SetBool`、`SetFloat` 去操作飞船状态键。
- 不要再新增旧式的 `server.onBodyRegister(shipBodyId, shipType)`、`server.ensureShipState(shipBodyId, shipType)` 这一类主脚本包装函数。
- 不要把具体武器逻辑、移动逻辑直接塞进 `server.serverTick(dt)`。