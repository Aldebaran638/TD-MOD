---@diagnostic disable: undefined-global

server = server or {}
server.weaponControllerRegistry = server.weaponControllerRegistry or {}

function server.weaponControllerRegister(controllerType, controller)
    local id = tostring(controllerType or "")
    if id == "" then return false, "missing controller type" end
    if type(controller) ~= "table" or type(controller.requestFire) ~= "function" then
        return false, "controller must provide requestFire"
    end
    if server.weaponControllerRegistry[id] ~= nil then
        return false, "duplicate controller " .. id
    end
    server.weaponControllerRegistry[id] = controller
    return true, nil
end

function server.weaponControllerGet(controllerType)
    return server.weaponControllerRegistry[tostring(controllerType or "")]
end

function server.weaponControllerResolve(weaponDefinition)
    local controllerType = tostring((weaponDefinition or {}).controllerType or "")
    if controllerType == "" then return nil end
    return server.weaponControllerGet(controllerType)
end

function server.weaponControllerValidateDefinition(weaponDefinition)
    local controllerType = tostring((weaponDefinition or {}).controllerType or "")
    if controllerType == "" then return true, nil end
    if server.weaponControllerGet(controllerType) == nil then
        return false, "unknown controllerType " .. controllerType
    end
    return true, nil
end

function server.weaponControllerClearHeld()
    for _, controller in pairs(server.weaponControllerRegistry or {}) do
        if controller.ownsHold and type(controller.setHeld) == "function" then
            controller.setHeld({}, false)
        end
    end
end
