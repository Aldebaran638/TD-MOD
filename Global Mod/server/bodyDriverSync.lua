---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local registryShipRoot = "StellarisShips/server/ships/byId/"
local registryShipIndexRoot = "StellarisShips/server/ships/index"

-- 全局服务端模块：每帧同步所有已注册飞船的驾驶员 playerId
-- 通过 Registry 索引枚举所有飞船，用 GetBodyVehicle 建立
-- vehicleHandle→shipBodyId 映射，再与 GetPlayerVehicle 比对，
-- 找到每艘船的当前驾驶员并写回 Registry 的 driverPlayerId 键
function server.bodyDriverSyncTick(dt)
    -- 1. 从 Registry 索引读取所有已注册飞船
    local count = GetInt(registryShipIndexRoot .. "/count")
    if count == nil or count <= 0 then
        return
    end

    -- 2. 枚举飞船，建立 vehicleHandle → shipBodyId 的映射
    local vehicleToShipBody = {}
    local registeredBodies = {}
    for i = 1, count do
        local bodyId = GetInt(registryShipIndexRoot .. "/" .. tostring(i) .. "/bodyId")
        if bodyId ~= nil and bodyId ~= 0 then
            registeredBodies[#registeredBodies + 1] = bodyId
            local veh = GetBodyVehicle(bodyId)
            if veh ~= nil and veh ~= 0 then
                vehicleToShipBody[veh] = bodyId
            end
        end
    end

    -- 3. 初始化每艘飞船的 driverId 为 0
    local driverByBody = {}
    for i = 1, #registeredBodies do
        driverByBody[registeredBodies[i]] = 0
    end

    -- 4. 遍历所有玩家，查找谁在驾驶哪艘船
    local players = GetAllPlayers() or {}
    for i = 1, #players do
        local playerId = players[i]
        if IsPlayerValid == nil or IsPlayerValid(playerId) then
            local veh = GetPlayerVehicle(playerId)
            if veh ~= nil and veh ~= 0 then
                local shipBody = vehicleToShipBody[veh]
                if shipBody ~= nil and driverByBody[shipBody] == 0 then
                    driverByBody[shipBody] = playerId
                end
            end
        end
    end

    -- 5. 将结果写回 Registry（同步到所有客户端）
    for bodyId, driverId in pairs(driverByBody) do
        SetInt(registryShipRoot .. tostring(bodyId) .. "/driverPlayerId", driverId, true)
    end
end
