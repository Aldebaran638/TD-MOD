---@diagnostic disable: undefined-global

server = server or {}

function server.weaponDamageRoll(definition)
    local data = definition or {}
    local minimum = tonumber(data.damageMin)
    local maximum = tonumber(data.damageMax)
    if minimum == nil and maximum == nil then
        return math.max(0.0, tonumber(data.damage) or 0.0)
    end

    minimum = math.max(0.0, minimum or maximum or 0.0)
    maximum = math.max(minimum, maximum or minimum)
    if maximum <= minimum then return minimum end
    return minimum + (maximum - minimum) * math.random()
end

function server.weaponDamageApplyToShip(hitBody, weaponType, attackerBodyId)
    local bodyId = math.floor(hitBody or 0)
    local definition = (weaponData or {})[tostring(weaponType or "")] or {}
    if bodyId == 0 or server.registryShipExists == nil or not server.registryShipExists(bodyId) then
        return false, false, "environment"
    end

    local raw = server.weaponDamageRoll(definition)
    local result = server.shipDamageApplyWeaponDefinition(
        bodyId,
        definition,
        raw,
        attackerBodyId
    )
    return result.didDamage, result.didHitShield, result.impactLayer
end

