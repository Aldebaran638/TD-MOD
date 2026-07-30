---@diagnostic disable: undefined-global

server = server or {}

local function _emptyDamageResult()
    return {
        didDamage = false,
        didHitShield = false,
        impactLayer = "none",
        appliedDamage = 0.0,
        shieldDamage = 0.0,
    }
end

function server.shipDamageApplyRaw(shipBodyId, rawDamage)
    local result = _emptyDamageResult()
    local body = math.floor(shipBodyId or 0)
    local remaining = math.max(0.0, tonumber(rawDamage) or 0.0)
    if body == 0 or remaining <= 0.0 then return result end
    if server.registryShipExists == nil or not server.registryShipExists(body) then
        return result
    end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(body) then
        return result
    end

    local shield, armor, hull = server.registryShipGetHP(body)
    if shield == nil or armor == nil or hull == nil then return result end

    local function applyLayer(layerName, currentHP)
        local current = math.max(0.0, tonumber(currentHP) or 0.0)
        if current <= 0.0 or remaining <= 0.0 then return current end
        if result.impactLayer == "none" then result.impactLayer = layerName end

        local applied = math.min(current, remaining)
        current = current - applied
        remaining = remaining - applied
        result.appliedDamage = result.appliedDamage + applied
        result.didDamage = result.didDamage or applied > 0.0
        if layerName == "shield" and applied > 0.0 then
            result.didHitShield = true
            result.shieldDamage = result.shieldDamage + applied
        end
        return current
    end

    shield = applyLayer("shield", shield)
    armor = applyLayer("armor", armor)
    hull = applyLayer("body", hull)
    server.registryShipSetHP(body, shield, armor, hull)
    return result
end

