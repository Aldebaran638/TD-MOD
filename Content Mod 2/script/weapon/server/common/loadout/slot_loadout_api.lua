---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- slot_loadout_api.lua
-- 飞船槽位装载管理的API文件
-- 提供对外访问槽位配置的接口

server = server or {}

-- 从主模块获取内部API实现
local _api = server._slotLoadoutAPI

-- 如果API未加载，提供空实现
if _api == nil then
    _api = {}
end

function server.shipSlotLoadoutGetState(shipType)
    return _api.getState(shipType)
end

function server.shipSlotLoadoutSetConfiguration(shipType, configurationId)
    return _api.setConfiguration(shipType, configurationId)
end

function server.shipSlotLoadoutSetLoadout(shipType, requestedLoadout)
    return _api.setLoadout(shipType, requestedLoadout)
end

function server.shipSlotLoadoutValidateSnapshot(
    shipType,
    configurationId,
    requestedLoadout
)
    return _api.validateSnapshot(shipType, configurationId, requestedLoadout)
end

function server.shipSlotLoadoutApplySnapshot(snapshot)
    return _api.applySnapshot(snapshot)
end

function server.shipSlotLoadoutResolveShipDefinition(shipType)
    return _api.resolveShipDefinition(shipType)
end

function server.shipWeaponSyncConfiguration(shipType, recipientPlayerId)
    local resolvedType = tostring(shipType or server.shipContextGetType())
    local state = server.shipSlotLoadoutGetState(resolvedType) or {}
    local loadout = state.loadout or {}
    ClientCall(
        math.floor(recipientPlayerId or 0),
        "client.updateShipWeaponConfiguration",
        server.shipContextGetBody(),
        tostring(state.configurationId or ""),
        tostring(loadout.X or ""),
        tostring(loadout.L or ""),
        tostring(loadout.M or ""),
        tostring(loadout.G or ""),
        tostring(loadout.H or "")
    )
end

local function _rebuildWeaponRuntime(shipType)
    server.weaponRuntimeRebuild(shipType)

    local shipBody = server.shipContextGetBody()
    if shipBody ~= 0 and server.shipRuntimeGetCurrentMainWeapon ~= nil then
        local mode = server.shipRuntimeGetCurrentMainWeapon(shipBody)
        local definition = server.shipSlotLoadoutResolveShipDefinition(shipType) or {}
        local collection = nil
        for _, group in ipairs(definition.weaponGroups or {}) do
            if tostring(group.groupId or "") == tostring(mode or "") then
                collection = tostring(group.mountCollection or "")
                break
            end
        end
        if collection == nil or #((definition or {})[collection] or {}) == 0 then
            local firstGroup = (definition.weaponGroups or {})[1] or {}
            server.shipRuntimeSetCurrentMainWeapon(
                shipBody,
                tostring(firstGroup.groupId or "")
            )
            server.shipRuntimeSyncMainWeapon(shipBody, true)
        end
    end
end

function server.shipWeaponApplyConfiguration(shipType, configurationId, requestedLoadout)
    local resolvedType = tostring(shipType or server.shipContextGetType())
    local requested = requestedLoadout
    if requested == nil then
        requested = (server.shipSlotLoadoutGetState(resolvedType) or {}).loadout
    end
    local snapshot, err = server.shipSlotLoadoutValidateSnapshot(
        resolvedType,
        configurationId,
        requested
    )
    if snapshot == nil then return false, err end
    if not server.shipSlotLoadoutApplySnapshot(snapshot) then
        return false, "failed to apply validated weapon configuration"
    end

    _rebuildWeaponRuntime(resolvedType)
    server.shipWeaponSyncConfiguration(resolvedType)
    return true, nil
end

local function _shipWeaponBindingResult(playerId, shipBody, resultCode)
    ClientCall(
        math.floor(playerId or 0),
        "client.weaponConfigurationBindingResult",
        math.floor(shipBody or 0),
        math.floor(resultCode or 0)
    )
end

function server.shipWeaponBindLocalConfiguration(
    playerId,
    shipBody,
    shipType,
    configurationId,
    xWeapon,
    lWeapon,
    mWeapon,
    gWeapon,
    hWeapon,
    componentPayload
)
    local pid = math.floor(playerId or 0)
    local body = math.floor(shipBody or 0)
    if IsPlayerValid ~= nil and not IsPlayerValid(pid) then return false end
    if body == 0 or body ~= server.shipContextGetBody() then
        _shipWeaponBindingResult(pid, body, 0)
        return false
    end

    local vehicle = GetPlayerVehicle(pid)
    if vehicle == nil or vehicle == 0 or GetVehicleBody(vehicle) ~= body then
        _shipWeaponBindingResult(pid, body, 0)
        return false
    end
    if IsPlayerVehicleDriver ~= nil and not IsPlayerVehicleDriver(vehicle, pid) then
        _shipWeaponBindingResult(pid, body, 0)
        return false
    end
    if tostring(shipType or "") ~= server.shipContextGetType() then
        _shipWeaponBindingResult(pid, body, 0)
        return false
    end

    if server.weaponLocalConfigurationBound then
        _shipWeaponBindingResult(pid, body, -1)
        return true
    end

    local resolvedType = tostring(shipType or server.shipContextGetType())
    local requestedComponents = nil
    requestedComponents = shipComponentDecodeLoadout(componentPayload)
    if requestedComponents == nil then
        _shipWeaponBindingResult(pid, body, 0)
        return false
    end
    local componentLoadout, componentProfile =
        server.shipComponentPrepareLoadout(
            resolvedType,
            tostring(configurationId or ""),
            requestedComponents
        )
    if componentLoadout == nil then
        _shipWeaponBindingResult(pid, body, 0)
        return false
    end
    local weaponSnapshot = server.shipSlotLoadoutValidateSnapshot(
        resolvedType,
        tostring(configurationId or ""),
        {
            X = tostring(xWeapon or ""),
            L = tostring(lWeapon or ""),
            M = tostring(mWeapon or ""),
            G = tostring(gWeapon or ""),
            H = tostring(hWeapon or ""),
        }
    )
    if weaponSnapshot == nil then
        _shipWeaponBindingResult(pid, body, 0)
        return false
    end

    if not server.shipSlotLoadoutApplySnapshot(weaponSnapshot) then
        _shipWeaponBindingResult(pid, body, 0)
        return false
    end
    local ok = server.shipComponentApplyPrepared(
        componentLoadout,
        componentProfile,
        true
    )
    if not ok then
        _shipWeaponBindingResult(pid, body, 0)
        return false
    end
    _rebuildWeaponRuntime(resolvedType)
    server.shipWeaponSyncConfiguration(resolvedType)

    server.weaponLocalConfigurationBound = true
    server.weaponLocalConfigurationPlayerId = pid
    _shipWeaponBindingResult(pid, body, 1)
    return true
end
