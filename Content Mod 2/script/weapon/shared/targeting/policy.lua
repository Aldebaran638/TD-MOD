---@diagnostic disable: undefined-global

-- Shared weapon targeting policy.  Weapon data describes the targeting mode;
-- an explicit requiresTargetLock value is the authoritative override.
weaponTargetingPolicy = weaponTargetingPolicy or {}

function weaponTargetingPolicy.requiresTargetLock(definition)
    local weapon = definition or {}
    if weapon.requiresTargetLock ~= nil then
        return weapon.requiresTargetLock == true
    end
    return tostring(weapon.targetingMode or "") == "target_lock"
end
