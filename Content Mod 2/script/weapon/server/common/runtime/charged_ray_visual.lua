---@diagnostic disable: undefined-global

-- Charged-ray visual lifecycle. Weapon runtime code selects a profile; the
-- profile implementation owns its engine-specific lights and cleanup.
server = server or {}
server.chargedRayVisualHandlers = server.chargedRayVisualHandlers or {}

function server.chargedRayVisualRegister(profileId, handler)
    local profile = tostring(profileId or "")
    if profile == "" or type(handler) ~= "table" then
        return false, "invalid charged-ray visual profile"
    end
    if server.chargedRayVisualHandlers[profile] ~= nil then
        return false, "duplicate charged-ray visual profile " .. profile
    end
    server.chargedRayVisualHandlers[profile] = handler
    return true, nil
end

local function _resolveHandler(weaponDefinition)
    local profile = tostring((weaponDefinition or {}).muzzleLightProfile or "")
    if profile == "" then return nil end
    return server.chargedRayVisualHandlers[profile]
end

local function _call(weaponType, weaponDefinition, method, ...)
    local handler = _resolveHandler(weaponDefinition)
    local callback = handler ~= nil and handler[method] or nil
    if type(callback) ~= "function" then return false end
    callback(weaponType, weaponDefinition, ...)
    return true
end

function server.chargedRayVisualInit()
    for _, handler in pairs(server.chargedRayVisualHandlers or {}) do
        if type(handler.init) == "function" then handler.init() end
    end
end

function server.chargedRayVisualBeginCharge(weaponType, weaponDefinition)
    return _call(weaponType, weaponDefinition, "beginCharge")
end

function server.chargedRayVisualTrigger(weaponType, weaponDefinition)
    return _call(weaponType, weaponDefinition, "trigger")
end

function server.chargedRayVisualStop(weaponType, weaponDefinition)
    return _call(weaponType, weaponDefinition, "stop")
end

function server.chargedRayVisualStopAll()
    for profile, handler in pairs(server.chargedRayVisualHandlers or {}) do
        if type(handler.stop) == "function" then
            handler.stop(
                tostring(handler.defaultWeaponType or ""),
                { muzzleLightProfile = profile }
            )
        end
    end
end

function server.chargedRayVisualTick(dt)
    for _, handler in pairs(server.chargedRayVisualHandlers or {}) do
        if type(handler.tick) == "function" then handler.tick(dt) end
    end
end
