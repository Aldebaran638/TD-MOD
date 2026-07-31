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
    local outgoingMultiplier = 0.0
    if server.shipRuntimeGetWeaponDamageMultiplier ~= nil
        and server.shipContextGetBody ~= nil then
        outgoingMultiplier = server.shipRuntimeGetWeaponDamageMultiplier(
            server.shipContextGetBody()
        )
    end
    local remaining = math.max(0.0, tonumber(rawDamage) or 0.0)
        * (1.0 + math.max(0.0, tonumber(outgoingMultiplier) or 0.0))
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

function server.shipDamageApplyWeaponDefinition(shipBodyId, definition, rawDamage)
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
    local shieldHardening, armorHardening = 0.0, 0.0
    if server.shipRuntimeGetHardening ~= nil then
        shieldHardening, armorHardening = server.shipRuntimeGetHardening(body)
    end
    local weapon = definition or {}

    local function applyLayer(
        layerName,
        currentHP,
        multiplier,
        penetration,
        hardening
    )
        local current = math.max(0.0, tonumber(currentHP) or 0.0)
        if current <= 0.0 or remaining <= 0.0 then return current end
        local damageMultiplier = math.max(0.0, tonumber(multiplier) or 1.0)
        local basePenetration = math.max(0.0, math.min(1.0,
            tonumber(penetration) or 0.0))
        local layerHardening = math.max(0.0, math.min(1.0,
            tonumber(hardening) or 0.0))
        local effectivePenetration = basePenetration * (1.0 - layerHardening)
        local bypassRaw = remaining * effectivePenetration
        local interceptedRaw = remaining - bypassRaw
        local consumedRaw = 0.0
        local applied = 0.0

        if interceptedRaw > 0.0 and damageMultiplier > 0.0 then
            applied = math.min(current, interceptedRaw * damageMultiplier)
            consumedRaw = applied / damageMultiplier
            current = current - applied
        end
        remaining = bypassRaw + math.max(0.0, interceptedRaw - consumedRaw)

        if applied > 0.0 then
            if result.impactLayer == "none" then result.impactLayer = layerName end
            result.didDamage = true
            result.appliedDamage = result.appliedDamage + applied
            if layerName == "shield" then
                result.didHitShield = true
                result.shieldDamage = result.shieldDamage + applied
            end
        end
        return current
    end

    shield = applyLayer(
        "shield",
        shield,
        weapon.shieldFix,
        weapon.shieldPenetration,
        shieldHardening
    )
    armor = applyLayer(
        "armor",
        armor,
        weapon.armorFix,
        weapon.armorPenetration,
        armorHardening
    )
    hull = applyLayer("body", hull, weapon.bodyFix, 0.0, 0.0)
    server.registryShipSetHP(body, shield, armor, hull)
    return result
end

