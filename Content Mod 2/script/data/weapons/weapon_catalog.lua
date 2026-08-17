-- 统一武器数据表
-- 将多个武器的参数放在一起，便于维护与扩展

weaponData = weaponData or {}

#include "schema.lua"
#include "ai_candidate_runtime_projection.lua"
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

function weaponCatalogRegisterRuntimeDefinition(weaponType)
    local requested = tostring(weaponType or "")
    if cm2CatalogAuthorityV1 ~= nil
        and cm2CatalogAuthorityV1.isFrozen ~= nil
        and cm2CatalogAuthorityV1.isFrozen() then
        return false, "runtime weapon definition registration is frozen"
    end
    local definition = weaponData[requested]
    if requested == "" or definition == nil or definition.runtimeReady == false then
        return false, "runtime weapon definition is unavailable"
    end
    if weaponBehaviorProfiles[tostring(definition.behaviorType or "")] ~= true then
        return false, "runtime weapon behavior is not registered"
    end
    for _, slot in ipairs(definition.slotTypes or {}) do
        local slotType = string.upper(tostring(slot or ""))
        if slotType ~= "" then
            weaponSlotPools[slotType] = weaponSlotPools[slotType] or {}
            local present = false
            for _, candidate in ipairs(weaponSlotPools[slotType]) do
                if tostring(candidate) == requested then
                    present = true
                    break
                end
            end
            if not present then
                weaponSlotPools[slotType][#weaponSlotPools[slotType] + 1] = requested
                table.sort(weaponSlotPools[slotType], function(leftId, rightId)
                    local left = weaponData[leftId] or {}
                    local right = weaponData[rightId] or {}
                    local leftTier = tonumber(left.catalogTier) or math.huge
                    local rightTier = tonumber(right.catalogTier) or math.huge
                    if leftTier ~= rightTier then return leftTier < rightTier end
                    return tostring(left.englishName or leftId) < tostring(right.englishName or rightId)
                end)
            end
        end
    end
    return true, nil
end

function weaponCatalogGetSlotPool(slotType)
    return weaponSlotPools[string.upper(tostring(slotType or ""))] or {}
end

function weaponCatalogUseRuntimeDefinitions(definitions)
    weaponData = definitions or {}
    weaponSlotPools = {}
    for weaponType, definition in pairs(weaponData) do
        if definition.runtimeReady ~= false then
            for _, slot in ipairs(definition.slotTypes or {}) do
                local slotType = string.upper(tostring(slot or ""))
                if slotType ~= "" then
                    weaponSlotPools[slotType] = weaponSlotPools[slotType] or {}
                    weaponSlotPools[slotType][#weaponSlotPools[slotType] + 1] = weaponType
                end
            end
        end
    end
    for _, pool in pairs(weaponSlotPools) do
        table.sort(pool)
    end
end
