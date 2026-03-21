---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

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

    server.registryShipEnsure(body, server.defaultShipType, server.defaultShipType)
    local driverId = server.registryShipGetDriverPlayerId(body)
    if driverId ~= playerId then
        return
    end

    -- 兼容旧 RPC 调用：统一写入请求态，后续由 tick 消费
    server.registryShipSetMoveRequestState(body, moveState)
end

function server.bodyMoveStateReceiveTick(dt)
    local body = server.shipBody
    if body == nil or body == 0 then
        return
    end

    server.registryShipEnsure(body, server.defaultShipType, server.defaultShipType)
    local driverId = server.registryShipGetDriverPlayerId(body)
    if driverId == nil or driverId == 0 then
        server.registryShipSetMoveState(body, 0)
    else
        local requestState = server.registryShipGetMoveRequestState(body)
        server.registryShipSetMoveState(body, requestState)
    end
end
