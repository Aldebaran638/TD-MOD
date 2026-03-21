# 客户端 IO 输入模块（AI 执行指导）

> 适用范围：`Global Mod/client/input_handling/*Input.lua`
>
> 本文档只约束**客户端输入模块**，不讨论服务端实现细节。

## 1. 输入模块的一般作用

输入模块的目标是：把“本地玩家输入意图”稳定写入 Registry 的 request 键。

固定流程：

1. 读取本地输入（键盘/鼠标）
2. 解析输入为标准状态（如 0/1/2）
3. 定位本地玩家当前载具与 bodyId
4. 通过 `.../exists` 判断该船是否纳入群星系统
5. 写入 request 键

## 2. Registry request 键规则（重点）

统一根路径：

`StellarisShips/server/ships/byId/<bodyId>/...`

输入模块应优先写“request 类键”，而不是直接写最终权威状态键。

常用键示例：

- `xSlots/<i>/request`（Int, 0/1）
- `move/requestState`（Int, 0/1/2）
- `move/request`（Int, 0/1）

### 2.1 新键与复用键确认流程（AI 必做）

当用户没有明确键名时，AI 必须主动确认：

1. 新增键路径与键名是什么
2. 数据类型与取值语义是什么
3. 是否复用现有 request 键
4. 是否允许同步修改“全局 Registry 指导文档”

禁止 AI 在未确认时自行拍板新增键名。

## 3. 与用户确认的细节清单

实现前，AI 需要向用户确认以下输入模块细节：

1. 输入逻辑（按键 -> 状态映射）
2. 触发方式（按下瞬间/按住连续/变化触发）
3. 发送策略（是否保活、保活间隔）
4. request 键路径与取值
5. 是否更新相关指导文档

## 4. 推荐发送策略

根据输入类型选择：

1. 边沿触发输入（例如 `lmb`）：按下瞬间写一次
2. 状态输入（例如移动）：状态变化立即写 + 固定间隔保活写

推荐保活间隔：`0.2s`。

## 5. 目标判定规范

是否为群星船的判定依据：

`StellarisShips/server/ships/byId/<bodyId>/exists == true`

不要再依赖 `HasTag(..., "stellarisShip")` 作为输入模块的最终判定标准。

## 6. 调试规范

统一开关：

- `StellarisShips/debug/inputTestEnabled`（Bool）

开启后建议输出：

1. 当前本地玩家 ID
2. 当前驾驶 bodyId
3. 当前船 Registry 关键键值

发布前关闭调试开关。

## 7. 代码风格与兼容

1. 禁止 `::continue::` / `goto continue`
2. 使用 if 过滤 + 提前 return
3. 函数命名统一：`client.<moduleName>Tick(dt)`
4. 注释应面向新手可读，重点解释系统设计相关步骤（按键检测、request 写入、发送策略）