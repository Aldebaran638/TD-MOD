---@diagnostic disable: undefined-global

server = server or {}

local _components = {}
local _registrationSequence = 0
local _phaseCache = {}

local function _phaseOrder(component, phase)
    return tonumber(component[phase .. "Order"] or component.order or 1000) or 1000
end

local function _orderedComponents(phase)
    if _phaseCache[phase] ~= nil then
        return _phaseCache[phase]
    end
    local ordered = {}
    for _, component in pairs(_components) do
        if type(component[phase]) == "function" then
            ordered[#ordered + 1] = component
        end
    end
    table.sort(ordered, function(left, right)
        local leftOrder = _phaseOrder(left, phase)
        local rightOrder = _phaseOrder(right, phase)
        if leftOrder == rightOrder then
            return left.registrationSequence < right.registrationSequence
        end
        return leftOrder < rightOrder
    end)
    _phaseCache[phase] = ordered
    return ordered
end

local function _runPhase(phase, ...)
    for _, component in ipairs(_orderedComponents(phase)) do
        if type(component.isActive) ~= "function"
            or component.isActive(phase, ...) then
            component[phase](...)
        end
    end
end

function server.weaponRuntimeRegister(componentId, component)
    local id = tostring(componentId or "")
    if id == "" then return false, "missing component id" end
    if type(component) ~= "table" then return false, "component must be a table" end
    if _components[id] ~= nil then return false, "duplicate component " .. id end

    _registrationSequence = _registrationSequence + 1
    component.id = id
    component.registrationSequence = _registrationSequence
    _components[id] = component
    _phaseCache = {}
    return true, nil
end

function server.weaponRuntimeInit(shipType)
    _runPhase("init", shipType)
end

function server.weaponRuntimeRebuild(shipType)
    _runPhase("rebuildReset", shipType)
    _runPhase("rebuildInit", shipType)
end

function server.weaponRuntimeDeactivate()
    _runPhase("deactivate")
end

function server.weaponRuntimeClearCommands()
    _runPhase("clearCommands")
end

function server.weaponRuntimeCommandTick(dt)
    _runPhase("commandTick", dt)
end

function server.weaponRuntimeSimulationTick(dt)
    _runPhase("simulationTick", dt)
end

function server.weaponRuntimeUpdate(dt)
    _runPhase("update", dt)
end

function server.weaponRuntimePostUpdate()
    _runPhase("postUpdate")
end

function server.weaponRuntimeGetRegisteredIds()
    local ids = {}
    for id, _ in pairs(_components) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    return ids
end
