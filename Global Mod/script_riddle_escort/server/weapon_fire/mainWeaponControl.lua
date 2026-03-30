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
    if mode == "sSlot" then
        local slots = (server.escortSSlotState and server.escortSSlotState.slots) or {}
        for i = 1, #slots do
            local weaponType = (((slots[i] or {}).config) or {}).weaponType
            if _mainWeaponTypeUsable(weaponType) then
                return true
            end
        end
        return false
    end

    if mode == "pSlot" then
        local slots = (server.escortPSlotState and server.escortPSlotState.slots) or {}
        for i = 1, #slots do
            local weaponType = (((slots[i] or {}).config) or {}).weaponType
            if _mainWeaponTypeUsable(weaponType) then
                return true
            end
        end
        return false
    end

    if mode == "gSlot" then
        local launchers = (server.escortGSlotState and server.escortGSlotState.launchers) or {}
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
    local order = { "sSlot", "pSlot", "gSlot" }
    for i = 1, #order do
        if _mainWeaponModeUsable(order[i]) then
            return order[i]
        end
    end
    return "sSlot"
end

local function _resolveNextAvailableMainWeaponMode(currentMode)
    local order = { "sSlot", "pSlot", "gSlot" }
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

    return currentMode or "sSlot"
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
        if server.escortSSlotStateResetRuntime ~= nil then
            server.escortSSlotStateResetRuntime()
        end
        if server.escortPSlotStateResetRuntime ~= nil then
            server.escortPSlotStateResetRuntime()
        end
        if server.escortGSlotStateResetRuntime ~= nil then
            server.escortGSlotStateResetRuntime()
        end
        return
    end

    if _consumeMainWeaponToggleRequested() then
        local current = server.shipRuntimeGetCurrentMainWeapon(shipBody)
        local nextMode = _resolveNextAvailableMainWeaponMode(current)
        server.shipRuntimeSetCurrentMainWeapon(shipBody, nextMode)
        server.shipRuntimeSyncMainWeapon(shipBody, true)
        if nextMode == "sSlot" then
            server.escortSSlotStatePushHud(true)
        elseif nextMode == "pSlot" then
            server.escortPSlotStatePushHud(true)
        elseif nextMode == "gSlot" and server.escortGSlotControlSyncHud ~= nil then
            server.escortGSlotControlSyncHud(true)
        end
    end

    if not _consumeMainWeaponFireRequested() then
        return
    end

    local current = server.shipRuntimeGetCurrentMainWeapon(shipBody)
    if current == "sSlot" then
        server.escortSSlotStateSetRequestFire(true)
    elseif current == "pSlot" then
        server.escortPSlotStateSetRequestFire(true)
    elseif current == "gSlot" then
        server.escortGSlotStateSetRequestFire(true)
    end
end
