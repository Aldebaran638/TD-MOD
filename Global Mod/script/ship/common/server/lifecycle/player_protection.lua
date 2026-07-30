---@diagnostic disable: undefined-global

server = server or {}

server.shipPlayerProtectionState = server.shipPlayerProtectionState or {
    healthFloorByPlayer = {},
}

local function _shipPlayerProtectionIsInside(playerId, shipBody)
    local vehicle = GetPlayerVehicle(playerId)
    return vehicle ~= nil and vehicle ~= 0
        and GetVehicleBody(vehicle) == shipBody
end

local function _shipPlayerProtectionRestoreHealth(playerId)
    local state = server.shipPlayerProtectionState
    local currentHealth = GetPlayerHealth(playerId)
    local healthFloor = state.healthFloorByPlayer[playerId]

    if healthFloor == nil then
        state.healthFloorByPlayer[playerId] = currentHealth
    elseif currentHealth < healthFloor then
        SetPlayerHealth(healthFloor, playerId)
    elseif currentHealth > healthFloor then
        state.healthFloorByPlayer[playerId] = currentHealth
    end
end

function server.shipPlayerProtectionTick()
    local shipBody = server.shipContextGetBody()
    if shipBody == nil or shipBody == 0 then return end

    local state = server.shipPlayerProtectionState
    for _, playerId in ipairs(GetAllPlayers() or {}) do
        if _shipPlayerProtectionIsInside(playerId, shipBody) then
            DisablePlayerDamage(playerId)
            _shipPlayerProtectionRestoreHealth(playerId)
        else
            state.healthFloorByPlayer[playerId] = nil
        end
    end
end

function server.shipPlayerProtectionPostUpdate()
    local shipBody = server.shipContextGetBody()
    if shipBody == nil or shipBody == 0 then return end

    for _, playerId in ipairs(GetAllPlayers() or {}) do
        if _shipPlayerProtectionIsInside(playerId, shipBody) then
            _shipPlayerProtectionRestoreHealth(playerId)
        end
    end
end
