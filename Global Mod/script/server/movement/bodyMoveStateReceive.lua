---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local function _isAnyPlayerOnShip(shipBodyId)
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end

    local players = GetAllPlayers() or {}
    for i = 1, #players do
        local playerId = players[i]
        if IsPlayerValid == nil or IsPlayerValid(playerId) then
            local veh = GetPlayerVehicle(playerId)
            if veh ~= nil and veh ~= 0 then
                local body = GetVehicleBody(veh)
                if body ~= nil and body ~= 0 and body == shipBodyId then
                    return true
                end
            end
        end
    end

    return false
end

function server_bodyMoveStateSet(playerId, moveState)
    if playerId == nil or (IsPlayerValid ~= nil and not IsPlayerValid(playerId)) then
        return
    end

    local veh = GetPlayerVehicle(playerId)
    if veh == nil or veh == 0 then
        return
    end

    local body = GetVehicleBody(veh)
    if body == nil or body == 0 then
        return
    end

    if HasTag ~= nil and (not HasTag(body, "stellarisShip")) then
        return
    end

    if server.shipBody ~= nil and server.shipBody ~= 0 and body ~= server.shipBody then
        return
    end

    server.registryShipEnsure(body, server.defaultShipType, server.defaultShipType)
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(body) then
        server.registryShipSetMoveRequestState(body, 0)
        server.registryShipSetMoveState(body, 0)
        return
    end
    server.registryShipSetMoveRequestState(body, moveState)
end

function server.bodyMoveStateReceiveTick(dt)
    local _ = dt
    local body = server.shipBody
    if body == nil or body == 0 then
        return
    end

    server.registryShipEnsure(body, server.defaultShipType, server.defaultShipType)
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(body) then
        server.registryShipSetMoveRequestState(body, 0)
        server.registryShipSetMoveState(body, 0)
        return
    end

    if not _isAnyPlayerOnShip(body) then
        server.registryShipSetMoveRequestState(body, 0)
        server.registryShipSetMoveState(body, 0)
        return
    end

    local requestState = server.registryShipGetMoveRequestState(body)
    server.registryShipSetMoveState(body, requestState)
end
