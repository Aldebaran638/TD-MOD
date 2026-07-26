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

function server.shipSlotLoadoutResolveShipDefinition(shipType)
    return _api.resolveShipDefinition(shipType)
end

function server.shipWeaponSyncConfiguration(shipType, recipientPlayerId)
    local resolvedType = tostring(shipType or server.defaultShipType or "enigmaticCruiser")
    local state = server.shipSlotLoadoutGetState(resolvedType) or {}
    local loadout = state.loadout or {}
    ClientCall(
        math.floor(recipientPlayerId or 0),
        "client.updateShipWeaponConfiguration",
        server.shipBody or 0,
        tostring(state.configurationId or ""),
        tostring(loadout.X or ""),
        tostring(loadout.L or ""),
        tostring(loadout.M or ""),
        tostring(loadout.G or ""),
        tostring(loadout.H or "")
    )
end

local function _rebuildWeaponRuntime(shipType)
    if server.xSlotStateResetRuntime ~= nil then server.xSlotStateResetRuntime() end
    if server.lSlotStateResetRuntime ~= nil then server.lSlotStateResetRuntime() end
    if server.mSlotControlResetRuntime ~= nil then server.mSlotControlResetRuntime() end
    if server.gSlotControlResetRuntime ~= nil then server.gSlotControlResetRuntime() end
    if server.hSlotStateResetRuntime ~= nil then server.hSlotStateResetRuntime() end
    if server.guidedProjectileRuntimeInit ~= nil then server.guidedProjectileRuntimeInit() end
    if server.projectileManagerReset ~= nil then server.projectileManagerReset() end
    if server.tachyonMuzzleLightStop ~= nil then server.tachyonMuzzleLightStop("tachyonLance") end

    if server.xSlotStateInit ~= nil then server.xSlotStateInit(shipType) end
    if server.lSlotStateInit ~= nil then server.lSlotStateInit(shipType) end
    if server.mSlotControlInit ~= nil then server.mSlotControlInit(shipType) end
    if server.gSlotControlInit ~= nil then server.gSlotControlInit(shipType) end
    if server.hSlotStateInit ~= nil then server.hSlotStateInit(shipType) end
    if server.weaponGroupInit ~= nil then server.weaponGroupInit(shipType) end

    local shipBody = math.floor(server.shipBody or 0)
    if shipBody ~= 0 and server.shipRuntimeGetCurrentMainWeapon ~= nil then
        local mode = server.shipRuntimeGetCurrentMainWeapon(shipBody)
        local collectionByMode = {
            xSlot = "xSlots", lSlot = "lSlots", mSlot = "mSlots",
            gSlot = "gSlots", hSlot = "hSlots",
        }
        local definition = server.shipSlotLoadoutResolveShipDefinition(shipType) or {}
        local collection = collectionByMode[mode]
        if collection == nil or #((definition or {})[collection] or {}) == 0 then
            server.shipRuntimeSetCurrentMainWeapon(shipBody, "xSlot")
            server.shipRuntimeSyncMainWeapon(shipBody, true)
        end
    end
end

function server.shipWeaponApplyConfiguration(shipType, configurationId, requestedLoadout)
    local resolvedType = tostring(shipType or server.defaultShipType or "enigmaticCruiser")
    local previous = server.shipSlotLoadoutGetState(resolvedType)
    local ok, err = server.shipSlotLoadoutSetConfiguration(resolvedType, configurationId)
    if not ok then return false, err end

    if requestedLoadout ~= nil then
        ok, err = server.shipSlotLoadoutSetLoadout(resolvedType, requestedLoadout)
        if not ok then
            if previous ~= nil then
                server.shipSlotLoadoutSetConfiguration(resolvedType, previous.configurationId)
                server.shipSlotLoadoutSetLoadout(resolvedType, previous.loadout)
            end
            return false, err
        end
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
    hWeapon
)
    local pid = math.floor(playerId or 0)
    local body = math.floor(shipBody or 0)
    if IsPlayerValid ~= nil and not IsPlayerValid(pid) then return false end
    if body == 0 or body ~= math.floor(server.shipBody or 0) then
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
    if tostring(shipType or "") ~= tostring(server.defaultShipType or "enigmaticCruiser") then
        _shipWeaponBindingResult(pid, body, 0)
        return false
    end

    if server.weaponLocalConfigurationBound then
        _shipWeaponBindingResult(pid, body, -1)
        return true
    end

    local ok = server.shipWeaponApplyConfiguration(
        tostring(shipType or "enigmaticCruiser"),
        tostring(configurationId or ""),
        {
            X = tostring(xWeapon or ""),
            L = tostring(lWeapon or ""),
            M = tostring(mWeapon or ""),
            G = tostring(gWeapon or ""),
            H = tostring(hWeapon or ""),
        }
    )
    if not ok then
        _shipWeaponBindingResult(pid, body, 0)
        return false
    end

    server.weaponLocalConfigurationBound = true
    server.weaponLocalConfigurationPlayerId = pid
    _shipWeaponBindingResult(pid, body, 1)
    return true
end
