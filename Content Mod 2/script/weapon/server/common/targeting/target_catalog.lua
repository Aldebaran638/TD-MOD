---@diagnostic disable: undefined-global

server = server or {}

function server.weaponTargetIsExternalBody(bodyId)
    local body = math.floor(bodyId or 0)
    if body == 0 or not IsHandleValid(body) then return false end
    for _, tag in ipairs(weaponExternalTargetTags or {}) do
        if HasTag(body, tostring(tag or "")) then return true end
    end
    return false
end

function server.weaponTargetIsLockableBody(bodyId, observerBodyId)
    local body = math.floor(bodyId or 0)
    if body == 0 or not IsHandleValid(body) then return false end
    local isRegistered = server.registryShipExists ~= nil
        and server.registryShipExists(body)
    if isRegistered then
        if server.registryShipIsBodyDead ~= nil
            and server.registryShipIsBodyDead(body) then
            return false
        end
        if server.registryShipIsPlayerLockable ~= nil
            and not server.registryShipIsPlayerLockable(body) then return false end
        if server.registryShipIsBodyDead ~= nil
            and server.registryShipIsBodyDead(body) then return false end
        if server.registryShipIsCloaked ~= nil
            and server.registryShipIsCloaked(body) then
            -- Sensors still report a cloaked ship, but weapon locks cannot
            -- acquire it at any distance until the cloak is broken.
            return false
        end
        return true
    end

    -- A removed missile/craft keeps its historical Registry fields. Do not
    -- allow a reused Body ID to become a normal target.
    if server.registryShipKeyPrefix ~= nil then
        local prefix = server.registryShipKeyPrefix(body)
        if GetString(prefix .. "/interceptorClass") ~= ""
            or GetBool(prefix .. "/destroyed") then
            return false
        end
    end

    -- 普通载具不在群星 Registry 中，但仍是合法的锁定目标。
    -- 只有明确来自外部目标标签的无载具 Body 才走 external 分支。
    local vehicleId = GetBodyVehicle(body)
    if vehicleId ~= nil and vehicleId ~= 0 then
        return true
    end
    return server.weaponTargetIsExternalBody(body)
end
