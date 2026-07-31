---@diagnostic disable: undefined-global

client = client or {}

function client.weaponTargetIsLockableBody(bodyId, observerBodyId)
    local body = math.floor(tonumber(bodyId) or 0)
    local observer = math.floor(tonumber(observerBodyId) or 0)
    if body == 0 or not IsHandleValid(body) then return false end
    if client.registryShipExists ~= nil and client.registryShipExists(body) then
        if client.registryShipIsPlayerLockable ~= nil
            and not client.registryShipIsPlayerLockable(body) then return false end
        if client.registryShipIsCloaked ~= nil
            and client.registryShipIsCloaked(body) then
            if observer == 0 or not IsHandleValid(observer) then return false end
            local distance = VecLength(VecSub(
                GetBodyTransform(observer).pos,
                GetBodyTransform(body).pos
            ))
            return distance <= 80.0
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
