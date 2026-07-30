---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.shipDestructibilityState = server.shipDestructibilityState or {
    unlockedByBody = {},
}

local function _forEachShipShape(body, callback)
    if body == nil or body == 0 or not IsHandleValid(body) then return end
    local shapes = GetBodyShapes(body) or {}
    for index = 1, #shapes do
        local shape = shapes[index]
        if shape ~= nil and shape ~= 0 and IsHandleValid(shape) then
            callback(shape)
        end
    end
end

function server.shipDestructibilityInit(body)
    if body == nil or body == 0 or not IsHandleValid(body) then return false end
    SetTag(body, "unbreakable")
    _forEachShipShape(body, function(shape)
        SetTag(shape, "unbreakable")
    end)
    server.shipDestructibilityState.unlockedByBody[body] = nil
    return true
end

function server.shipDestructibilityUnlock(body)
    if body == nil or body == 0 or not IsHandleValid(body) then return false end
    local state = server.shipDestructibilityState
    if state.unlockedByBody[body] then return false end

    RemoveTag(body, "unbreakable")
    _forEachShipShape(body, function(shape)
        RemoveTag(shape, "unbreakable")
    end)
    state.unlockedByBody[body] = true
    return true
end

