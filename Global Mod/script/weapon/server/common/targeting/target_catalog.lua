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

function server.weaponTargetIsLockableBody(bodyId)
    local body = math.floor(bodyId or 0)
    if body == 0 or not IsHandleValid(body) then return false end
    if server.registryShipExists ~= nil and server.registryShipExists(body) then
        return server.registryShipIsBodyDead == nil
            or not server.registryShipIsBodyDead(body)
    end
    return server.weaponTargetIsExternalBody(body)
end
