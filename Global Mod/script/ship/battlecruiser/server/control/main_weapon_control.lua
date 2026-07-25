---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- main_weapon_control.lua
-- 主武器控制模块 - 符合规范的模块文件
-- 只导出 server.mainWeaponControlInit() 和 server.mainWeaponControlTick()

server = server or {}

-- 模块内部状态
local _requestState = {
    fireRequested = false,
    toggleRequested = false,
}

-- ============ 内部辅助函数 ============

local function _consumeFireRequested()
    local requested = _requestState.fireRequested and true or false
    _requestState.fireRequested = false
    return requested
end

local function _consumeToggleRequested()
    local requested = _requestState.toggleRequested and true or false
    _requestState.toggleRequested = false
    return requested
end

local function _resetRequests()
    _requestState.fireRequested = false
    _requestState.toggleRequested = false
end

local _weaponModeOrder = { "xSlot", "lSlot", "mSlot", "gSlot", "hSlot" }
local _mountCollectionByMode = {
    xSlot = "xSlots",
    lSlot = "lSlots",
    mSlot = "mSlots",
    gSlot = "gSlots",
    hSlot = "hSlots",
}

local function _resolveCurrentShipDefinition()
    local shipType = server.defaultShipType or "enigmaticCruiser"
    if server.shipSlotLoadoutResolveShipDefinition ~= nil then
        local resolved = server.shipSlotLoadoutResolveShipDefinition(shipType)
        if resolved ~= nil then return resolved end
    end
    local defs = shipTypeRegistryData or {}
    return defs[shipType] or defs.enigmaticCruiser or {}
end

local function _nextAvailableWeaponMode(current)
    local definition = _resolveCurrentShipDefinition()
    local currentIndex = 1
    for i = 1, #_weaponModeOrder do
        if _weaponModeOrder[i] == current then
            currentIndex = i
            break
        end
    end
    for offset = 1, #_weaponModeOrder do
        local index = ((currentIndex - 1 + offset) % #_weaponModeOrder) + 1
        local mode = _weaponModeOrder[index]
        local mounts = definition[_mountCollectionByMode[mode]] or {}
        if #mounts > 0 then return mode end
    end
    return "xSlot"
end

-- ============ API函数（内部使用，通过API文件暴露） ============

local _weaponControlAPI = {}

function _weaponControlAPI.setFireRequested(active)
    _requestState.fireRequested = active and true or false
end

function _weaponControlAPI.setToggleRequested(active)
    _requestState.toggleRequested = active and true or false
end

function _weaponControlAPI.resetRequests()
    _resetRequests()
end

-- 将API导出到server表，供API文件使用
server._mainWeaponControlAPI = _weaponControlAPI

-- ============ 规范化的模块接口 ============

function server.mainWeaponControlInit()
    _requestState = {
        fireRequested = false,
        toggleRequested = false,
    }
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
        _resetRequests()
        if server.weaponGroupClearFireHeld ~= nil then
            server.weaponGroupClearFireHeld()
        end
        if server.xSlotStateSetHoldRequested ~= nil then
            server.xSlotStateSetHoldRequested(false)
        end
        if server.xSlotStateSetRequestFire ~= nil then
            server.xSlotStateSetRequestFire(false)
        end
        if server.xSlotStateResetRuntime ~= nil then
            server.xSlotStateResetRuntime()
        end
        server.lSlotStateSetRequestFire(false)
        server.lSlotStateResetRuntime()
        server.lSlotStatePushHudReset(true)
        if server.mSlotControlResetRuntime ~= nil then
            server.mSlotControlResetRuntime()
        end
        if server.gSlotControlResetRuntime ~= nil then
            server.gSlotControlResetRuntime()
        end
        if server.guidedProjectileRuntimeInit ~= nil then
            server.guidedProjectileRuntimeInit()
        end
        if server.hSlotStateResetRuntime ~= nil then
            server.hSlotStateResetRuntime()
        end
        return
    end

    if _consumeToggleRequested() then
        if server.weaponGroupClearFireHeld ~= nil then
            server.weaponGroupClearFireHeld()
        end
        if server.xSlotStateSetHoldRequested ~= nil then
            server.xSlotStateSetHoldRequested(false)
        end
        local current = server.shipRuntimeGetCurrentMainWeapon(shipBody)
        local nextMode = _nextAvailableWeaponMode(current)
        server.shipRuntimeSetCurrentMainWeapon(shipBody, nextMode)
        server.shipRuntimeSyncMainWeapon(shipBody, true)
        server.lSlotStatePushHud(true)
    end

    if not _consumeFireRequested() then
        return
    end

    local current = server.shipRuntimeGetCurrentMainWeapon(shipBody)
    if server.weaponGroupRequestFire ~= nil then
        server.weaponGroupRequestFire(current, { shipBodyId = shipBody })
    end
end
