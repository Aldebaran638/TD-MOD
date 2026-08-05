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

local function _resolveProfileForSync(shipType, state, loadout)
    local profile = server.shipComponentProfile
    if profile ~= nil and profile.sensor ~= nil then
        return profile
    end
    local definition = server.shipContextGetDefinition() or {}
    local configuration = shipComponentFindConfiguration(
        definition,
        state.configurationId
    )
    if configuration == nil then return {} end
    return shipComponentResolveProfile(
        definition,
        server.shipComponentLoadout or {},
        configuration,
        loadout
    ) or {}
end

function server.shipWeaponSyncConfiguration(shipType, recipientPlayerId)
    local resolvedType = tostring(shipType or server.shipContextGetType())
    local state = server.shipSlotLoadoutGetState(resolvedType) or {}
    local loadout = state.loadout or {}
    local profile = _resolveProfileForSync(resolvedType, state, loadout)
    local sensor = profile.sensor or {}
    local energy = profile.energy or {}
    local mobility = profile.mobility or {}
    local cloak = profile.cloak or {}
    ClientCall(
        math.floor(recipientPlayerId or 0),
        "client.updateShipWeaponConfiguration",
        server.shipContextGetBody(),
        tostring(state.configurationId or ""),
        tostring(loadout.T or ""),
        tostring(loadout.X or ""),
        tostring(loadout.L or ""),
        tostring(loadout.L2 or loadout.L or ""),
        tostring(loadout.M or ""),
        tostring(loadout.G or ""),
        tostring(loadout.H or ""),
        tostring(loadout.P or ""),
        tonumber(sensor.range) or 0.0,
        tonumber(sensor.interval) or 1.0,
        tonumber(sensor.trackingAdd) or 0.0,
        tonumber(energy.output) or 0.0,
        tonumber(energy.use) or 0.0,
        tonumber(energy.balance) or 0.0,
        tonumber(energy.weaponDamageMultiplier) or 0.0,
        tonumber(mobility.speedMultiplier) or 0.0,
        tonumber(mobility.turnResponseMultiplier) or 0.0,
        tonumber(mobility.turnForceMultiplier) or 0.0,
        cloak.available and 1 or 0,
        tonumber(cloak.strength) or 0.0,
        tonumber(cloak.shieldReduction) or 0.0,
        math.floor(tonumber(cloak.shipLimit) or 0)
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

local function _shipWeaponBindingResult(
    playerId,
    shipBody,
    resultCode,
    errorMessage
)
    ClientCall(
        math.floor(playerId or 0),
        "client.weaponConfigurationBindingResult",
        math.floor(shipBody or 0),
        math.floor(resultCode or 0),
        tostring(errorMessage or "")
    )
end

function server.shipWeaponBindLocalConfiguration(
    playerId,
    shipBody,
    shipType,
    configurationId,
    tWeapon,
    xWeapon,
    lWeapon,
    lWeapon2,
    mWeapon,
    gWeapon,
    hWeapon,
    pWeapon,
    componentPayload
)
    local pid = math.floor(playerId or 0)
    local body = math.floor(shipBody or 0)
    if IsPlayerValid ~= nil and not IsPlayerValid(pid) then return false end
    if body == 0 or body ~= server.shipContextGetBody() then
        _shipWeaponBindingResult(pid, body, 0, "ship body mismatch")
        return false
    end

    local vehicle = GetPlayerVehicle(pid)
    if vehicle == nil or vehicle == 0 or GetVehicleBody(vehicle) ~= body then
        _shipWeaponBindingResult(pid, body, 0, "player is not aboard this ship")
        return false
    end
    if IsPlayerVehicleDriver ~= nil and not IsPlayerVehicleDriver(vehicle, pid) then
        _shipWeaponBindingResult(pid, body, 0, "player is not the ship driver")
        return false
    end
    if tostring(shipType or "") ~= server.shipContextGetType() then
        _shipWeaponBindingResult(pid, body, 0, "ship type mismatch")
        return false
    end

    if server.weaponLocalConfigurationBound then
        _shipWeaponBindingResult(pid, body, -1, "")
        return true
    end

    local resolvedType = tostring(shipType or server.shipContextGetType())
    local requestedComponents = nil
    local componentDecodeError = nil
    requestedComponents, componentDecodeError =
        shipComponentDecodeLoadout(componentPayload)
    if requestedComponents == nil then
        _shipWeaponBindingResult(pid, body, 0, componentDecodeError)
        return false
    end
    local weaponSnapshot, weaponError = server.shipSlotLoadoutValidateSnapshot(
        resolvedType,
        tostring(configurationId or ""),
        {
            T = tostring(tWeapon or ""),
            X = tostring(xWeapon or ""),
            L = tostring(lWeapon or ""),
            L2 = tostring(lWeapon2 or lWeapon or ""),
            M = tostring(mWeapon or ""),
            G = tostring(gWeapon or ""),
            H = tostring(hWeapon or ""),
            P = tostring(pWeapon or ""),
        }
    )
    if weaponSnapshot == nil then
        _shipWeaponBindingResult(pid, body, 0, weaponError)
        return false
    end
    local componentLoadout, componentProfile, componentError =
        server.shipComponentPrepareLoadout(
            resolvedType,
            tostring(configurationId or ""),
            requestedComponents,
            weaponSnapshot.loadout
        )
    if componentLoadout == nil then
        _shipWeaponBindingResult(pid, body, 0, componentError)
        return false
    end

    if not server.shipSlotLoadoutApplySnapshot(weaponSnapshot) then
        _shipWeaponBindingResult(pid, body, 0, "weapon snapshot apply failed")
        return false
    end
    local ok, applyError = server.shipComponentApplyPrepared(
        componentLoadout,
        componentProfile,
        true
    )
    if not ok then
        _shipWeaponBindingResult(pid, body, 0, applyError)
        return false
    end
    _rebuildWeaponRuntime(resolvedType)
    server.shipWeaponSyncConfiguration(resolvedType)

    server.weaponLocalConfigurationBound = true
    server.weaponLocalConfigurationPlayerId = pid
    _shipWeaponBindingResult(pid, body, 1, "")
    return true
end
