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

local function _mainWeaponTypeUsable(weaponType)
    return weaponType ~= nil and weaponType ~= "" and weaponType ~= "none"
end

local function _mainWeaponModeUsable(mode)
    if mode == "tSlot" then
        local slots = (server.xSlotState and server.xSlotState.slots) or {}
        for i = 1, #slots do
            local weaponType = (((slots[i] or {}).config) or {}).weaponType
            if _mainWeaponTypeUsable(weaponType) then
                return true
            end
        end
        return false
    end

    if mode == "lSlot" then
        local slots = (server.lSlotState and server.lSlotState.slots) or {}
        for i = 1, #slots do
            local weaponType = (((slots[i] or {}).config) or {}).weaponType
            if _mainWeaponTypeUsable(weaponType) then
                return true
            end
        end
        return false
    end

    if mode == "mSlot" then
        local launchers = (server.sSlotState and server.sSlotState.launchers) or {}
        for i = 1, #launchers do
            local weaponType = (((launchers[i] or {}).config) or {}).weaponType
            if _mainWeaponTypeUsable(weaponType) then
                return true
            end
        end
        return false
    end

    return false
end

function server.mainWeaponResolvePreferredMode()
    local order = { "tSlot", "lSlot", "mSlot" }
    for i = 1, #order do
        if _mainWeaponModeUsable(order[i]) then
            return order[i]
        end
    end
    return "tSlot"
end

local function _resolveNextAvailableMainWeaponMode(currentMode)
    local order = { "tSlot", "lSlot", "mSlot" }
    local currentIndex = 1

    for i = 1, #order do
        if order[i] == currentMode then
            currentIndex = i
            break
        end
    end

    for offset = 1, #order do
        local idx = ((currentIndex - 1 + offset) % #order) + 1
        local candidate = order[idx]
        if _mainWeaponModeUsable(candidate) then
            return candidate
        end
    end

    return currentMode or "tSlot"
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
        if server.sSlotStateResetRuntime ~= nil then
            server.sSlotStateResetRuntime()
        end
        return
    end

    if _consumeMainWeaponToggleRequested() then
        local current = server.shipRuntimeGetCurrentMainWeapon(shipBody)
        local nextMode = _resolveNextAvailableMainWeaponMode(current)
        server.shipRuntimeSetCurrentMainWeapon(shipBody, nextMode)
        server.shipRuntimeSyncMainWeapon(shipBody, true)
        if nextMode == "lSlot" then
            server.lSlotStatePushHud(true)
        elseif nextMode == "tSlot" then
            if server.xSlotStatePushHud ~= nil then
                server.xSlotStatePushHud(true)
            end
        elseif nextMode == "mSlot" and server.sSlotControlSyncHud ~= nil then
            server.sSlotControlSyncHud()
        end
    end

    if not _consumeMainWeaponFireRequested() then
        return
    end

    local current = server.shipRuntimeGetCurrentMainWeapon(shipBody)
    if current == "lSlot" then
        server.lSlotStateSetRequestFire(true)
    elseif current == "tSlot" then
        if server.xSlotStateSetRequestFire ~= nil then
            server.xSlotStateSetRequestFire(true)
        end
    end
end
