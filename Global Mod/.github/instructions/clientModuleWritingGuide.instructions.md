# 客户端模块编写指导

> 适用范围：Global Mod 客户端脚本。

## 1. 模块分类

客户端模块分为三类：

1. IO 输入模块（`input_handling/*Input.lua`）
2. 广播接收模块（`receive_boardcast/*ReceiveBroadcast.lua`）
3. 渲染模块（`draw_modules/*Fx.lua`）

## 2. 主脚本职责（强制）

`client.clientTick(dt)` 只做调度，不写复杂业务循环：

- 调用输入模块 tick
- 调用广播接收模块 tick
- 调用“状态边界分发模块”
- 调用渲染模块 tick

禁止在主脚本中散写业务状态机细节。

## 3. 输入链路规范（请求驱动）

输入模块只负责“采样输入 + 写请求键”，不直接改服务端权威状态。

- xSlot：写 `StellarisShips/server/ships/byId/<bodyId>/xSlots/<i>/request`
- move：写 `StellarisShips/server/ships/byId/<bodyId>/move/requestState` 与 `move/request`

目标船判定统一使用：

- `StellarisShips/server/ships/byId/<bodyId>/exists == true`

推荐策略：

- 状态变化时立即写入
- 0.2s 保活重写一次（防丢包导致卡状态）

新增或复用 request 键时，AI 必须先向用户确认：

1. 键路径与键名
2. 数据类型与取值语义
3. 是否复用现有 request 键
4. 是否同步修改 Registry 相关指导文档

## 4. 渲染链路规范

渲染以服务端同步状态为准：

- 持续态：每帧读当前状态并更新表现
- 一次性特效：仅在状态边界（前后帧状态变化）触发

## 5. 调试规范

输入调试使用统一开关：

- `StellarisShips/debug/inputTestEnabled`（Bool）

仅在开关为 true 时输出 `DebugWatch`。发布前应关闭。

## 6. 语法兼容规范

禁止使用 `::continue::` / `goto continue` 风格流程控制。

统一改为：

- if 嵌套过滤
- 提前 return

## 7. 变更前确认

若接口契约、键名、状态值存在疑问，先按根目录共享规范发起确认，避免猜测实现。

输入模块改动时，AI 还必须确认：

1. 输入键位与映射逻辑（例如 W/S/LMB）
2. 触发方式（按下瞬间/按住连续/变化触发）
3. 是否启用保活与保活间隔