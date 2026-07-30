---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- ship_init.lua
-- 飞船初始化模块 - 符合规范的模块文件
-- 只导出 server.shipInitInit() 和 server.shipInitTick()

server = server or {}

-- ============ 内部辅助函数 ============

local function _registerCurrentShip(shipType)
    local shipBodyId = server.shipContextGetBody()
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end
    server.registryShipRegister(shipBodyId, shipType, server.shipContextGetType())
    return true
end

local function _ensureCurrentShipState(shipType)
    local shipBodyId = server.shipContextGetBody()
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end
    local contextType = server.shipContextGetType()
    return server.registryShipEnsure(shipBodyId, shipType or contextType, contextType)
end

-- ============ 规范化的模块接口 ============

function server.shipInitInit(shipType)
    server.shipContextInit(shipType, "stellarisShip")
    SetBool("StellarisShips/debug/inputTestEnabled", false)
    _registerCurrentShip(shipType)
end

function server.shipInitTick(dt)
    -- 初始化模块通常不需要每tick执行
    -- 但保留接口以符合规范
end
