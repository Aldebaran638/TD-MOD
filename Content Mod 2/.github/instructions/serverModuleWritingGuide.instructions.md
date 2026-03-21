# 服务器模块编写指导

服务端模块按职责拆分，主脚本仅做调度，不承载具体业务。

## 必读文档

- 全局状态表（Registry）规范：`globalStateRegistry.instructions.md`

## 当前模块分类

1. 武器发射模块（`weapon_fire`）
	- 负责武器状态机、命中计算、伤害结算、广播触发
	- 例如：`server/weapon_fire/xSlotControl.lua`

2. 移动模块（`movement`）
	- 负责推进、阻尼、悬浮、输入驱动运动状态等
	- 例如：`server/movement/bodyDirectionalMove.lua`、`server/movement/bodyVelocityQuadraticDamping.lua`

## 如何判定“新的服务器模块是哪一类”

按“模块核心职责”归类，而不是按调用来源归类：

1. 只要核心是开火、命中、伤害、武器状态机 -> `weapon_fire`
2. 只要核心是速度、加速度、阻尼、姿态、推进/刹车 -> `movement`
3. 若同时涉及多类职责，必须拆成多个模块，主脚本只做调度串联。

> 结论：新增模块类型必须先在本指导中登记，再落地到对应目录。

## 编写流程

1. 明确模块类型（先按“如何判定”规则归类，并先更新本指导）
2. 明确这个模块是“围绕当前飞船工作”还是“遍历多艘飞船工作”
3. 约定模块主 Tick 命名（如 `server.xSlotControlTick(dt)`）
4. 将具体逻辑全部放入模块
5. 在 `server.serverTick(dt)` 中仅调用模块主 Tick

## 当前飞船模块 vs 全局扫描模块

当前项目里同时存在两种服务端模块写法，必须先分清：

### 1. 当前飞船模块

- 这类模块挂在某一艘具体飞船的 `shipMain.lua` 下工作。
- 它默认处理的是 `server.shipBody` 这一艘飞船。
- 典型例子：当前 `xSlotControl.lua`。
- 这类模块优先通过：
	- `server.shipBody`
	- `server.registerCurrentShip(...)`
	- `server.ensureCurrentShipState(...)`
	- `server.registryShipGetSnapshot(server.shipBody)`
	来获取上下文。

### 2. 全局扫描模块

- 这类模块会遍历场景中的多艘飞船或多名玩家。
- 典型例子：驾驶员同步、全局输入接收、全局广播整理。
- 这类模块可以按 `bodyId` 循环处理，但仍然必须通过统一 Registry 接口读写状态。

如果一个模块其实只服务于当前飞船，就不要把它写成“扫描所有 body 的大循环模块”。

## 约束

- 禁止在 `server.serverTick(dt)` 内直接编写业务逻辑。
- 飞船状态必须通过统一 Registry 接口读写（例如 `server.registryShipEnsure`、`server.registryShipGetSnapshot`、`server.registryShipSetHP`）。
- 若模块属于“当前飞船模块”，应优先基于 `server.shipBody` 工作，而不是额外做全局遍历。
- 若模块属于“全局扫描模块”，才按 `bodyId` 或玩家列表遍历，并按每个对象分别读写 Registry。
- 广播接口与参数顺序必须保持兼容，避免客户端接收函数签名失配。

## Registry 访问层要求

- 模块不要自己拼一套新的 Registry 根路径常量。
- 模块不要直接把 Registry 当成本地状态缓存乱写。
- 需要读写飞船状态时，优先复用 `server/registry/shipRegistry.lua` 中已有函数。
- 若现有访问层缺少某个键的读写函数，应先补访问层，再让业务模块调用。

## 写模块前先确认的问题

1. 这个模块只处理当前飞船，还是会处理多艘飞船？
2. 它要读哪些 Registry 键？
3. 它要写哪些 Registry 键？
4. 这些键在访问层里是否已经有统一函数？
5. 如果新增了键名，是否需要同步更新全局 Registry 指导文档？

## 命名建议

- 模块文件：`<domain>Control.lua`
- 模块主 Tick：`server.<domain>Tick(dt)`
- 广播函数：`server.<domain>_broadcast...`
- 对外服务端入口：`server_<domain>_...`