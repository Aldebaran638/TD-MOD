---@diagnostic disable: undefined-global

server = server or {}

function server.weaponDamageApplyToShip(hitBody, weaponType)
    local bodyId = math.floor(hitBody or 0)
    local definition = (weaponData or {})[tostring(weaponType or "")] or {}
    if bodyId == 0 or server.registryShipExists == nil or not server.registryShipExists(bodyId) then
        return false, false, "environment"
    end

    local raw = tonumber(definition.damage)
        or ((tonumber(definition.damageMin) or 0.0) + (tonumber(definition.damageMax) or 0.0)) * 0.5
    local result = server.shipDamageApplyWeaponDefinition(bodyId, definition, raw)
    return result.didDamage, result.didHitShield, result.impactLayer
end

