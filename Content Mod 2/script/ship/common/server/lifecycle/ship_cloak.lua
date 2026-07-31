---@diagnostic disable: undefined-global

server = server or {}
server.shipCloakState = server.shipCloakState or { active = false }

local function _cloakBody()
    return server.shipContextGetBody()
end

local function _setActive(body, active, strength)
    server.shipCloakState.active = active and true or false
    server.shipRuntimeSetCloakActive(body, active)
    server.registryShipSetCloak(body, active, strength)
end

function server.shipCloakInit()
    local body = _cloakBody()
    server.shipCloakState = { active = false }
    if body == 0 or not server.registryShipExists(body) then return false end
    local available, strength = server.shipRuntimeGetCloak(body)
    server.registryShipSetCloak(body, false, available and strength or 0.0)
    return available
end

function server.shipCloakIsActive(body)
    return body == _cloakBody() and server.shipCloakState.active
end

function server.shipCloakBreakForWeapon(body)
    if not server.shipCloakIsActive(body) then return false end
    local available, strength = server.shipRuntimeGetCloak(body)
    _setActive(body, false, available and strength or 0.0)
    return true
end

function server.shipRequestToggleCloak(playerId, shipBodyId, requested)
    if not server.shipRequestAuthorize(playerId, shipBodyId) then return false end
    if shipBodyId ~= _cloakBody() then return false end
    local available, strength, shieldReduction = server.shipRuntimeGetCloak(shipBodyId)
    if not available then return false end
    local active = math.floor(tonumber(requested) or 0) ~= 0
    if active then
        _setActive(shipBodyId, true, strength)
        server.shipCloakApplyShieldCap(shipBodyId, shieldReduction)
    else
        _setActive(shipBodyId, false, strength)
    end
    return true
end

function server.shipCloakApplyShieldCap(body, reduction)
    if not server.shipCloakIsActive(body) then return end
    local maxShield = select(1, server.registryShipGetMaxHP(body)) or 0.0
    if maxShield <= 0.0 then return end
    local shield = select(1, server.registryShipGetHP(body)) or 0.0
    local cap = maxShield * (1.0 - math.max(0.0, math.min(1.0, tonumber(reduction) or 0.0)))
    if shield > cap then
        local _, armor, hull = server.registryShipGetHP(body)
        server.registryShipSetHP(body, cap, armor, hull)
    end
end

function server.shipCloakTick(_dt)
    local body = _cloakBody()
    if body == 0 or not server.registryShipExists(body) then return end
    if not server.shipCloakState.active then return end
    if server.registryShipIsBodyDead(body) then
        server.shipCloakBreakForWeapon(body)
        return
    end
    local available, strength, reduction = server.shipRuntimeGetCloak(body)
    if not available then
        _setActive(body, false, 0.0)
        return
    end
    server.shipCloakApplyShieldCap(body, reduction)
    server.registryShipSetCloak(body, true, strength)
end
