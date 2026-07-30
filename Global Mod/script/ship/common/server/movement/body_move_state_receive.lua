---@diagnostic disable: undefined-global

server = server or {}

local _driverValidationInterval = 0.25
local _driverValidationAge = _driverValidationInterval

local function _resetDriver(body)
    server.shipRuntimeResetControl(body)
    server.weaponRuntimeClearCommands()
    server.shipRuntimeSetDriverPlayerId(body, 0)
end

local function _driverStillValid(playerId, body)
    local pid = math.floor(tonumber(playerId) or 0)
    if pid <= 0 then return false end
    if IsPlayerValid ~= nil and not IsPlayerValid(pid) then return false end
    local vehicle = GetPlayerVehicle(pid)
    return vehicle ~= nil
        and vehicle ~= 0
        and math.floor(GetVehicleBody(vehicle) or 0) == body
end

-- 兼容旧的单项移动请求；新的客户端使用控制快照端点。
function server_bodyMoveStateSet(playerId, moveState)
    local body = server.shipContextGetBody()
    if not server.shipRequestAuthorize(playerId, body) then return end
    if server.registryShipIsBodyDead ~= nil
        and server.registryShipIsBodyDead(body) then
        _resetDriver(body)
        return
    end
    server.shipRuntimeSetMoveRequestState(body, moveState)
end

function server.bodyMoveStateReceiveTick(dt)
    local body = server.shipContextGetBody()
    if body == 0 then return end
    local shipType = server.shipContextGetType()
    server.registryShipEnsure(body, shipType, shipType)

    if server.registryShipIsBodyDead ~= nil
        and server.registryShipIsBodyDead(body) then
        _resetDriver(body)
        return
    end

    _driverValidationAge = _driverValidationAge + math.max(0.0, tonumber(dt) or 0.0)
    local driver = server.shipRuntimeGetDriverPlayerId(body)
    if _driverValidationAge >= _driverValidationInterval then
        _driverValidationAge = 0.0
        if driver > 0 and not _driverStillValid(driver, body) then
            _resetDriver(body)
            driver = 0
        end
    end

    if driver <= 0 then
        server.shipRuntimeSetMoveState(body, 0)
        return
    end
    server.shipRuntimeSetMoveState(
        body,
        server.shipRuntimeGetMoveRequestState(body)
    )
end
