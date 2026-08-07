-- 统一武器数据表
-- 将多个武器的参数放在一起，便于维护与扩展

weaponData = weaponData or {}

#include "schema.lua"
#include "x/tachyon_lance.lua"
#include "x/focused_arc_emitter.lua"
#include "x/giga_cannon.lua"
#include "l/large_gamma_laser.lua"
#include "l/large_plasma_cannon.lua"
#include "l/large_gauss_cannon.lua"
#include "l/kinetic_artillery.lua"
#include "l/large_stormfire_autocannon.lua"
#include "l/psionic_lightning.lua"
#include "m/medium_gamma_laser.lua"
#include "m/medium_plasma_cannon.lua"
#include "m/phase_disruptor.lua"
#include "m/medium_gauss_cannon.lua"
#include "m/medium_stormfire_autocannon.lua"
#include "m/swarmer_missile.lua"
#include "g/devastator_torpedoes.lua"
#include "g/neutron_launcher.lua"
#include "h/gamma_strike_craft.lua"
#include "p/flak_artillery.lua"
#include "p/guardian_point_defense.lua"
#include "t/perdition_beam.lua"
#include "stellaris_4_4_6.lua"

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
