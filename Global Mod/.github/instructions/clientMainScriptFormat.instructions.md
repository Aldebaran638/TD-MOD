# 客户端主脚本格式


以下是client.ships表的固定结构.没有用户明确要求,该结构不允许被修改.
```lua
client.ships[shipBodyId] = {
    id = shipBodyId,      -- 刚体唯一ID
    weapons = {
        xSlot = {
            -- 状态机
            state = "idle",        -- 飞船x槽状态(由服务器广播) idle / charging / launching .初始为idle
            -- 武器信息
            weaponType = nil,      -- 飞船x槽活动的武器类型(当x槽状态不为idle的时候,需要根据武器类型渲染蓄力特效以及发射特效).当x槽处于idle状态,武器类型不会被用上(x槽状态被更新后会由服务器顺带广播)
            -- 服务器广播数据
            firePoint = nil,       -- 飞船x槽发射点((x槽状态被更新后会由服务器顺带广播)
            hitPoint  = nil,       -- 飞船x槽命中点(x槽状态被更新后会由服务器顺带广播)
            hitTarget = nil,       -- 飞船x槽命中目标ID(如果没有命中或者命中的是非群星body则为无效值)(x槽状态被更新后会由服务器顺带广播)
            didHit = nil,          -- 是否命中(x槽状态被更新后会由服务器顺带广播)
            didHitStellarisBody = nil, -- 是否命中的shape所属的body是群星body(x槽状态被更新后会由服务器顺带广播)
        }
    }
}
```

客户端主脚本固定结构(必须严格按照以下要求编写,除非有明确变更申请,否则不允许修改):
```lua
client = client or {}

-- 客户端初始化函数

function client.init()

    # 客户端主脚本格式（优化版）

    概述
    -- 本文件说明 `client` 主脚本的固定结构、关键数据模型与运行时流程。除非有明确变更申请，固定数据结构不得随意修改。

    关键数据结构
    - `client.ships`（固定结构，禁止修改）
    ```lua
    -- client.ships[shipBodyId] 基本结构（只列出关键字段）
    client.ships[shipBodyId] = {
        id = shipBodyId,
        weapons = {
            xSlot = {
                state = "idle",          -- 由服务器广播: "idle"/"charging"/"launching"
                lastState = "idle",      -- 客户端维护，用于检测状态变化
                weaponType = nil,
                firePoint = nil,
                hitPoint = nil,
                hitTarget = nil,
                didHit = nil,
                didHitStellarisBody = nil,
            }
        }
    }
    ```

    脚本组织建议
    - 目录约定：
        - `receive_boardcast/`：放置广播接收模块（`*ReceiveBroadcast.lua`）
        - `input_handling/`：放置 IO 输入处理模块（`*Input.lua`）
        - `draw_modules/`：放置渲染/特效模块（`*Fx.lua`）
    - 包含顺序：先初始化数据结构，再包含接收/输入模块，最后包含渲染模块。避免模块在未初始化时访问 `client.ships`。

    初始化与注册
    ```lua
    client = client or {}

    function client.init()
        client.ships = {}
        client.myShipBody = FindBody("launcher", false)
        client.onBodyRegister(client.myShipBody)
        -- 其他初始化（配置、事件订阅、特效参数）
    end

    -- 注册函数：在刚体创建后的第一帧调用，必须初始化所有必需子字段
    function client.onBodyRegister(shipBodyId)
        client.ships[shipBodyId] = {
            id = shipBodyId,
            weapons = { xSlot = { state = "idle", lastState = "idle" } }
        }
    end
    ```

    包含模块示例（按目录组织）
    ```lua
    #include "receive_boardcast/ModuleName1ReceiveBroadcast.lua"
    #include "input_handling/ModuleName1Input.lua"
    #include "draw_modules/ModuleName1Fx.lua"
    ```

    # 客户端主脚本格式

    > 适用范围：`Global Mod/client/client.lua`

    ## 1. 主脚本定位

    主脚本只负责模块调度，不承载复杂业务细节。

    ## 2. 推荐包含顺序

    1. `receive_boardcast/*ReceiveBroadcast.lua`
    2. `input_handling/*Input.lua`
    3. `draw_modules/*Fx.lua`

    ## 3. `client.clientTick(dt)` 调度顺序（强制）

    1. 输入模块 tick（写请求键）
    2. 广播接收模块 tick（更新本地状态）
    3. 状态边界分发模块 tick（一次性触发）
    4. 渲染模块 tick（持续表现）
    5. 可选调试 tick（受开关控制）

    ## 4. 输入相关约束

    - 输入模块函数命名：`client.<name>Tick(dt)`
    - 输入模块仅写请求键，不直接改服务端权威状态
    - 调试开关：`StellarisShips/debug/inputTestEnabled`

    ## 5. 禁止事项

    - 禁止主 tick 内散写业务 for 循环（应下沉到模块）
    - 禁止在主 tick 里写硬编码 registry 路径
    - 禁止使用 `::continue::` / `goto continue`

    ## 6. 最小示例

    ```lua
    function client.clientTick(dt)
        client.xSlotInputTick(dt)
        client.bodyMoveInputTick(dt)

        if client.debugTestXSlotInputTick ~= nil then
            client.debugTestXSlotInputTick(dt)
        end
        if client.debugTestBodyMoveInputTick ~= nil then
            client.debugTestBodyMoveInputTick(dt)
        end
    end
    ```
