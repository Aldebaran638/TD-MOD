-- 统一武器数据表
-- 将多个武器的参数放在一起，便于维护与扩展

weaponData = weaponData or {}

#include "schema.lua"
#include "s/stellaris.lua"
#include "g/stellaris.lua"
#include "h/stellaris.lua"
#include "l/stellaris.lua"
#include "m/stellaris.lua"
#include "p/stellaris.lua"
#include "t/stellaris.lua"
#include "x/stellaris.lua"

-- Every registered, runtime-ready weapon is discoverable by its declared slot
-- types. Ship definitions only describe which slot groups physically exist.
weaponSlotPools = {}

for weaponType, definition in pairs(weaponData) do
    local seenSlots = {}
    if definition.runtimeReady ~= false
        and weaponBehaviorProfiles[tostring(definition.behaviorType or "")] == true then
        for _, slot in ipairs(definition.slotTypes or {}) do
            local slotType = string.upper(tostring(slot or ""))
            if slotType ~= "" and not seenSlots[slotType] then
                seenSlots[slotType] = true
                weaponSlotPools[slotType] = weaponSlotPools[slotType] or {}
                weaponSlotPools[slotType][#weaponSlotPools[slotType] + 1] = weaponType
            end
        end
    end
end

for _, pool in pairs(weaponSlotPools) do
    table.sort(pool, function(leftId, rightId)
        local left = weaponData[leftId] or {}
        local right = weaponData[rightId] or {}
        local leftTier = tonumber(left.catalogTier) or math.huge
        local rightTier = tonumber(right.catalogTier) or math.huge
        if leftTier ~= rightTier then return leftTier < rightTier end
        return tostring(left.englishName or leftId) < tostring(right.englishName or rightId)
    end)
end

function weaponCatalogGetSlotPool(slotType)
    return weaponSlotPools[string.upper(tostring(slotType or ""))] or {}
end
