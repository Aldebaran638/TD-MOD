---@diagnostic disable: undefined-global

server = server or {}

function server.shipRequestMatchesContext(shipBodyId)
    local requestedBody = math.floor(tonumber(shipBodyId) or 0)
    return requestedBody ~= 0 and requestedBody == server.shipContextGetBody()
end

function server.shipRequestIsDriver(playerId, shipBodyId)
    local pid = math.floor(tonumber(playerId) or 0)
    if pid <= 0 or not server.shipRequestMatchesContext(shipBodyId) then
        return false
    end
    if IsPlayerValid ~= nil and not IsPlayerValid(pid) then
        return false
    end

    local vehicle = GetPlayerVehicle(pid)
    if vehicle == nil or vehicle == 0 then return false end
    local body = math.floor(GetVehicleBody(vehicle) or 0)
    if body == math.floor(shipBodyId) then return true end

    local shipVehicle = GetBodyVehicle(math.floor(shipBodyId))
    return shipVehicle ~= nil and shipVehicle ~= 0 and shipVehicle == vehicle
end

local function _syncWeaponHud()
    for groupId, _ in pairs(server.weaponGroupStateById or {}) do
        server.weaponGroupSyncHud(groupId, true)
    end
end

function server.shipRequestAuthorize(playerId, shipBodyId)
    local pid = math.floor(tonumber(playerId) or 0)
    local body = math.floor(tonumber(shipBodyId) or 0)
    if not server.shipRequestMatchesContext(body) then return false end
    if server.registryShipExists ~= nil and not server.registryShipExists(body) then
        return false
    end
    if not server.shipRequestIsDriver(pid, body) then return false end

    local previousDriver = server.shipRuntimeGetDriverPlayerId(body)
    if previousDriver ~= pid then
        server.shipRuntimeResetControl(body)
        server.weaponRuntimeClearCommands()
        server.shipRuntimeSetDriverPlayerId(body, pid)
        _syncWeaponHud()
    end
    return true
end
