---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

function server.bodyDriverSyncTick(dt)
    local bodies = FindBodies("stellarisShip", true) or {}
    if #bodies == 0 and server.shipBody ~= nil and server.shipBody ~= 0 then
        bodies = { server.shipBody }
    end
    local driverByBody = {}

    for i = 1, #bodies do
        local body = bodies[i]
        if body ~= nil and body ~= 0 then
            server.registryShipEnsure(body, server.defaultShipType, server.defaultShipType)
            driverByBody[body] = 0
        end
    end

    local players = GetAllPlayers() or {}
    for i = 1, #players do
        local playerId = players[i]
        if IsPlayerValid == nil or IsPlayerValid(playerId) then
            local veh = GetPlayerVehicle(playerId)
            if veh ~= nil and veh ~= 0 then
                local body = GetVehicleBody(veh)
                if body ~= nil and body ~= 0 and driverByBody[body] ~= nil then
                    if driverByBody[body] == 0 then
                        driverByBody[body] = playerId
                    end
                end
            end
        end
    end

    for body, driverId in pairs(driverByBody) do
        server.shipRuntimeSetDriverPlayerId(body, driverId)
        if driverId == 0 then
            server.shipRuntimeSetMoveState(body, 0)
        end
    end
end
