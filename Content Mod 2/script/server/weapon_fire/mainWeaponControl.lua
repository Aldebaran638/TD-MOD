---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.mainWeaponRequestState = server.mainWeaponRequestState or {
    fireRequested = false,
    toggleRequested = false,
}

function server.mainWeaponRequestInit()
    server.mainWeaponRequestState = {
        fireRequested = false,
        toggleRequested = false,
    }
end

function server.mainWeaponRequestReset()
    local state = server.mainWeaponRequestState or {}
    state.fireRequested = false
    state.toggleRequested = false
    server.mainWeaponRequestState = state
end

function server.mainWeaponRequestSetFireRequested(active)
    local state = server.mainWeaponRequestState or {}
    state.fireRequested = active and true or false
    server.mainWeaponRequestState = state
end

function server.mainWeaponRequestSetToggleRequested(active)
    local state = server.mainWeaponRequestState or {}
    state.toggleRequested = active and true or false
    server.mainWeaponRequestState = state
end

local function _consumeMainWeaponFireRequested()
    local state = server.mainWeaponRequestState or {}
    local requested = state.fireRequested and true or false
    state.fireRequested = false
    server.mainWeaponRequestState = state
    return requested
end

local function _consumeMainWeaponToggleRequested()
    local state = server.mainWeaponRequestState or {}
    local requested = state.toggleRequested and true or false
    state.toggleRequested = false
    server.mainWeaponRequestState = state
    return requested
end

function server.mainWeaponControlTick(dt)
    local _ = dt
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        return
    end
    if not server.registryShipEnsure(shipBody, server.defaultShipType, server.defaultShipType) then
        return
    end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(shipBody) then
        server.mainWeaponRequestReset()
        if server.xSlotStateSetRequestFire ~= nil then
            server.xSlotStateSetRequestFire(false)
        end
        if server.xSlotStateResetRuntime ~= nil then
            server.xSlotStateResetRuntime()
        end
        server.lSlotStateSetRequestFire(false)
        server.lSlotStateResetRuntime()
        server.lSlotStatePushHudReset(true)
        return
    end

    if _consumeMainWeaponToggleRequested() then
        local current = server.registryShipGetCurrentMainWeapon(shipBody)
        local nextMode = (current == "lSlot") and "xSlot" or "lSlot"
        server.registryShipSetCurrentMainWeapon(shipBody, nextMode)
        server.lSlotStatePushHud(true)
    end

    if not _consumeMainWeaponFireRequested() then
        return
    end

    local current = server.registryShipGetCurrentMainWeapon(shipBody)
    if current == "lSlot" then
        server.lSlotStateSetRequestFire(true)
    else
        if server.xSlotStateSetRequestFire ~= nil then
            server.xSlotStateSetRequestFire(true)
        end
    end
end
