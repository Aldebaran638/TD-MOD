---@diagnostic disable: undefined-global

server = server or {}

function server.weaponDamageApplyToShip(hitBody, weaponType)
    local bodyId = math.floor(hitBody or 0)
    local definition = (weaponData or {})[tostring(weaponType or "")] or {}
    if bodyId == 0 or server.registryShipExists == nil or not server.registryShipExists(bodyId) then
        return false, false, "environment"
    end

    local shield, armor, hull = server.registryShipGetHP(bodyId)
    if shield == nil or armor == nil or hull == nil then return false, false, "none" end

    local raw = tonumber(definition.damage)
        or ((tonumber(definition.damageMin) or 0.0) + (tonumber(definition.damageMax) or 0.0)) * 0.5
    local firstLayer = "none"
    local hitShield = false

    local function applyLayer(name, hp, multiplier)
        local current = math.max(0.0, tonumber(hp) or 0.0)
        local fix = math.max(0.0, tonumber(multiplier) or 1.0)
        if current <= 0.0 or raw <= 0.0 or fix <= 0.0 then return current end
        if firstLayer == "none" then firstLayer = name end
        if name == "shield" then hitShield = true end
        local applied = raw * fix
        if applied < current then
            current = current - applied
            raw = 0.0
        else
            raw = math.max(0.0, raw - current / fix)
            current = 0.0
        end
        return current
    end

    shield = applyLayer("shield", shield, definition.shieldFix)
    armor = applyLayer("armor", armor, definition.armorFix)
    hull = applyLayer("body", hull, definition.bodyFix)
    server.registryShipSetHP(bodyId, shield, armor, hull)
    return firstLayer ~= "none", hitShield, firstLayer
end

