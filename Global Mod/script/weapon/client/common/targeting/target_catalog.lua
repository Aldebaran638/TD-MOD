---@diagnostic disable: undefined-global

client = client or {}

function client.weaponTargetIsLockableBody(bodyId, observerBodyId)
    local body = math.floor(tonumber(bodyId) or 0)
    if body == 0 or not IsHandleValid(body) then return false end
    local isRegistered = client.registryShipExists ~= nil
        and client.registryShipExists(body)
    if isRegistered then
        if client.registryShipIsBodyDead ~= nil
            and client.registryShipIsBodyDead(body) then
            return false
        end
        if client.registryShipIsPlayerLockable ~= nil
            and not client.registryShipIsPlayerLockable(body) then return false end
        if client.registryShipIsCloaked ~= nil
            and client.registryShipIsCloaked(body) then
            -- Sensors still report a cloaked ship, but weapon locks cannot
            -- acquire it at any distance until the cloak is broken.
            return false
        end
        return true
    end

    -- Unregistering a short-lived interceptor clears `exists` but preserves
    -- its historical fields. Reject that stale handle before a reused Body ID
    -- can be mistaken for an ordinary vehicle.
    if client.registryShipKeyPrefix ~= nil then
        local prefix = client.registryShipKeyPrefix(body)
        if GetString(prefix .. "/interceptorClass") ~= ""
            or GetBool(prefix .. "/destroyed") then
            return false
        end
    end
    return true
end

function client.weaponTargetIsExternalBody(bodyId)
    local body = math.floor(bodyId or 0)
    if body == 0 or not IsHandleValid(body) then return false end
    for _, tag in ipairs(weaponExternalTargetTags or {}) do
        if HasTag(body, tostring(tag or "")) then return true end
    end
    return false
end

function client.weaponTargetFindExternalBodies()
    local result = {}
    local seen = {}
    for _, tag in ipairs(weaponExternalTargetTags or {}) do
        for _, bodyId in ipairs(FindBodies(tostring(tag or ""), true) or {}) do
            local body = math.floor(bodyId or 0)
            if body ~= 0 and not seen[body] and IsHandleValid(body) then
                seen[body] = true
                result[#result + 1] = body
            end
        end
    end
    return result
end
