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
    if server.registryShipExists ~= nil and server.registryShipExists(body) then
        if server.registryShipIsPlayerLockable ~= nil
            and not server.registryShipIsPlayerLockable(body) then return false end
        if server.registryShipIsBodyDead ~= nil
            and server.registryShipIsBodyDead(body) then return false end
        if server.registryShipIsCloaked ~= nil
            and server.registryShipIsCloaked(body) then
            local observer = math.floor(tonumber(observerBodyId) or 0)
            if observer == 0 or not IsHandleValid(observer) then return false end
            return VecLength(VecSub(
                GetBodyTransform(observer).pos,
                GetBodyTransform(body).pos
            )) <= 80.0
        end
        return true
    end
    return server.weaponTargetIsExternalBody(body)
end
