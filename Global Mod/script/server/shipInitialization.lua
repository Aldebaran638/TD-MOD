---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

-- 服务端函数：注册“当前这艘飞船”到 Registry
-- 当前飞船由 server.shipBody 指定；该脚本只维护这一艘飞船
function server.registerCurrentShip(shipType)
    local shipBodyId = server.shipBody
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end
    server.registryShipRegister(shipBodyId, shipType, server.defaultShipType)
    return true
end

-- 服务端函数：确保“当前这艘飞船”在 Registry 中存在
-- 若当前飞船还未注册，则按默认飞船模板补齐运行时状态
function server.ensureCurrentShipState(shipType)
    local shipBodyId = server.shipBody
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end
    return server.registryShipEnsure(shipBodyId, shipType or server.defaultShipType, server.defaultShipType)
end

-- 初始化当前飞船基础环境并完成注册
function server.shipInitializationInit(shipType)
    server.shipBody = FindBody("stellarisShip", false)
    SetBool("StellarisShips/debug/inputTestEnabled", false)
    server.registerCurrentShip(shipType)
end
