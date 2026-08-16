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

local function _resolveCurrentShipDefinition()
    local shipType = server.shipContextGetType()
    if server.shipSlotLoadoutResolveShipDefinition ~= nil then
        local resolved = server.shipSlotLoadoutResolveShipDefinition(shipType)
        if resolved ~= nil then
            return resolved
        end
    end
    return shipDefinitionGet(shipType, shipType)
end

local function _definitionWeaponGroups(definition)
    local directGroups = (definition or {}).weaponGroups or {}
    if #directGroups > 0 then return directGroups end

    local defaultId = tostring((definition or {}).defaultSlotConfigurationId or "")
    local fallback = nil
    for _, configuration in ipairs((definition or {}).slotConfigurations or {}) do
        fallback = fallback or configuration.slotGroups
        if tostring(configuration.configurationId or "") == defaultId then
            return configuration.slotGroups or {}
        end
    end
    return fallback or {}
end

local function _groupHasMounts(definition, group)
    local mountCollection = tostring((group or {}).mountCollection or "")
    if mountCollection ~= "" then
        return #((definition or {})[mountCollection] or {}) > 0
    end
    return math.floor(tonumber((group or {}).count) or 0) > 0
end

local function _nextAvailableWeaponMode(current)
    local definition = _resolveCurrentShipDefinition()
    local groups = _definitionWeaponGroups(definition)
    if #groups == 0 then return "" end
    local currentIndex = 1
    for i = 1, #groups do
        if tostring(groups[i].groupId or "") == tostring(current or "") then
            currentIndex = i
            break
        end
    end
    for offset = 1, #groups do
        local index = ((currentIndex - 1 + offset) % #groups) + 1
        local group = groups[index] or {}
        if not group.automatic and _groupHasMounts(definition, group) then
            return tostring(group.groupId or "")
        end
    end
    return tostring((groups[1] or {}).groupId or "")
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

function _weaponControlAPI.hasPendingRequests()
    return _requestState.fireRequested or _requestState.toggleRequested
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
    local shipBody = server.shipContextGetBody()
    if shipBody == nil or shipBody == 0 then
        return
    end
    if not server.registryShipEnsure(
        shipBody,
        server.shipContextGetType(),
        server.shipContextGetType()
    ) then
        return
    end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(shipBody) then
        _resetRequests()
        server.weaponRuntimeDeactivate()
        return
    end

    if _consumeToggleRequested() then
        if server.weaponGroupClearFireHeld ~= nil then
            server.weaponGroupClearFireHeld()
        end
        local current = server.shipRuntimeGetCurrentMainWeapon(shipBody)
        local nextMode = _nextAvailableWeaponMode(current)
        server.shipRuntimeSetCurrentMainWeapon(shipBody, nextMode)
        server.shipRuntimeSyncMainWeapon(shipBody, true)
        server.weaponGroupSyncHud(nextMode, true)
    end

    if not _consumeFireRequested() then
        return
    end

    local current = server.shipRuntimeGetCurrentMainWeapon(shipBody)
    if server.weaponGroupRequestFire ~= nil then
        server.weaponGroupRequestFire(current, { shipBodyId = shipBody })
    end
end
