---@diagnostic disable: undefined-global

server = server or {}
server.weaponBehaviorRegistry = server.weaponBehaviorRegistry or {}

function server.weaponBehaviorRegister(behaviorType, controller)
    local id = tostring(behaviorType or "")
    if id == "" or type(controller) ~= "table" or type(controller.fire) ~= "function" then
        return false
    end
    server.weaponBehaviorRegistry[id] = controller
    return true
end

function server.weaponBehaviorGet(behaviorType)
    return server.weaponBehaviorRegistry[tostring(behaviorType or "")]
end

function server.weaponBehaviorValidateDefinition(definition)
    local def = definition or {}
    local id = tostring(def.behaviorType or "")
    if id == "" then return false, "missing behaviorType" end
    if server.weaponBehaviorGet(id) == nil then
        return false, "unknown behaviorType " .. id
    end
    return true, nil
end

