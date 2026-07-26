---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.guidedSlotGroupStateByMode = server.guidedSlotGroupStateByMode or {}

local function _guidedGroupCloneVec3(v, defaultX, defaultY, defaultZ)
    local t = v or {}
    return {
        x = tonumber(t.x) or defaultX or 0.0,
        y = tonumber(t.y) or defaultY or 0.0,
        z = tonumber(t.z) or defaultZ or 0.0,
    }
end

local function _guidedGroupResolveShipDefinition(shipType)
    local defs = shipTypeRegistryData or {}
    local requested = shipType or server.defaultShipType or "enigmaticCruiser"
    local shipDef = defs[requested] or defs[server.defaultShipType] or defs.enigmaticCruiser or {}
    if server.shipSlotLoadoutResolveShipDefinition ~= nil then
        shipDef = server.shipSlotLoadoutResolveShipDefinition(requested) or shipDef
    end
    return shipDef
end

local function _guidedGroupBuildLauncherConfig(slotDef)
    local weaponType = tostring((slotDef and slotDef.weaponType) or "none")
    local weaponDef = (weaponData or {})[weaponType] or {}
    return {
        weaponType = weaponType,
        firePosOffset = _guidedGroupCloneVec3(slotDef and slotDef.firePosOffset, 0.0, 0.0, 0.0),
        fireDirRelative = _guidedGroupCloneVec3(slotDef and slotDef.fireDirRelative, 0.0, 0.0, -1.0),
        cooldown = tonumber(weaponDef.cooldown) or 0.0,
        prefabPath = tostring(weaponDef.prefabPath or ""),
        spawnForwardOffset = tonumber(weaponDef.spawnForwardOffset) or 0.0,
        muzzleSpeed = tonumber(weaponDef.muzzleSpeed) or 0.0,
        cruiseSpeed = tonumber(weaponDef.cruiseSpeed) or 0.0,
        maxSpeed = tonumber(weaponDef.maxSpeed) or 0.0,
        acceleration = tonumber(weaponDef.acceleration) or 0.0,
        lifetime = tonumber(weaponDef.lifetime) or 0.0,
        maxRange = tonumber(weaponDef.maxRange) or 0.0,
        turnBlendRate = tonumber(weaponDef.turnBlendRate) or 0.0,
        turnRate = tonumber(weaponDef.turnRate) or 0.0,
        turnImpulse = tonumber(weaponDef.turnImpulse) or 0.0,
        damage = tonumber(weaponDef.damage) or 0.0,
        shieldFix = tonumber(weaponDef.shieldFix) or 1.0,
        armorFix = tonumber(weaponDef.armorFix) or 1.0,
        bodyFix = tonumber(weaponDef.bodyFix) or 1.0,
    }
end

local function _guidedGroupChooseLauncher(state)
    local launchers = state.launchers or {}
    local count = #launchers
    if count <= 0 then return nil end
    local startIndex = math.floor(state.nextLauncherIndex or 1)
    if startIndex < 1 or startIndex > count then startIndex = 1 end
    for offset = 0, count - 1 do
        local idx = ((startIndex - 1 + offset) % count) + 1
        local launcher = launchers[idx]
        local runtime = launcher and launcher.runtime or nil
        if runtime ~= nil and (runtime.cooldownRemain or 0.0) <= 0.0 then
            state.nextLauncherIndex = (idx % count) + 1
            return launcher
        end
    end
    return nil
end

local function _guidedGroupPushHud(state)
    local launchers = state.launchers or {}
    local values = {}
    for i = 1, 4 do
        local launcher = launchers[i] or {}
        local config = launcher.config or {}
        local runtime = launcher.runtime or {}
        values[i] = math.max(0.0, tonumber(runtime.cooldownRemain) or 0.0)
        values[i + 4] = math.max(0.0, tonumber(config.cooldown) or 0.0)
    end
    server.netClientCall(
        "hud.guided",
        0,
        state.hudCallback,
        server.shipBody,
        values[1], values[2], values[3], values[4],
        values[5], values[6], values[7], values[8]
    )
end

function server.guidedSlotGroupInit(mode, mountCollection, hudCallback, shipType)
    local shipDef = _guidedGroupResolveShipDefinition(shipType)
    local state = {
        mode = tostring(mode or ""),
        mountCollection = tostring(mountCollection or ""),
        hudCallback = tostring(hudCallback or "client.updateGuidedSlotHudState"),
        nextLauncherIndex = 1,
        request = nil,
        launchers = {},
    }
    local slotDefs = shipDef[state.mountCollection] or {}
    for i = 1, #slotDefs do
        state.launchers[i] = {
            config = _guidedGroupBuildLauncherConfig(slotDefs[i]),
            runtime = { cooldownRemain = 0.0 },
        }
    end
    server.guidedSlotGroupStateByMode[state.mode] = state
    return state
end

function server.guidedSlotGroupReset(mode)
    local state = server.guidedSlotGroupStateByMode[tostring(mode or "")]
    if state == nil then return end
    state.nextLauncherIndex = 1
    state.request = nil
    for i = 1, #(state.launchers or {}) do
        local runtime = ((state.launchers or {})[i] or {}).runtime
        if runtime ~= nil then runtime.cooldownRemain = 0.0 end
    end
end

function server.guidedSlotGroupSetFireRequest(mode, shipBodyId, targetVehicleId, targetBodyId)
    local state = server.guidedSlotGroupStateByMode[tostring(mode or "")]
    if state == nil then return false end
    state.request = {
        shipBodyId = math.floor(shipBodyId or 0),
        targetVehicleId = math.floor(targetVehicleId or 0),
        targetBodyId = math.floor(targetBodyId or 0),
        requestedAt = (GetTime ~= nil) and GetTime() or 0.0,
    }
    return true
end

function server.guidedSlotGroupTick(mode, dt)
    local state = server.guidedSlotGroupStateByMode[tostring(mode or "")]
    local shipBody = server.shipBody
    if state == nil or shipBody == nil or shipBody == 0 then return end
    if not server.registryShipEnsure(shipBody, server.defaultShipType, server.defaultShipType) then return end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(shipBody) then
        server.guidedSlotGroupReset(mode)
        return
    end

    for i = 1, #(state.launchers or {}) do
        local runtime = ((state.launchers or {})[i] or {}).runtime
        if runtime ~= nil and (runtime.cooldownRemain or 0.0) > 0.0 then
            runtime.cooldownRemain = math.max(0.0, (runtime.cooldownRemain or 0.0) - (dt or 0.0))
        end
    end
    _guidedGroupPushHud(state)

    local request = state.request
    state.request = nil
    if request == nil then return end
    if server.shipRuntimeGetCurrentMainWeapon ~= nil and server.shipRuntimeGetCurrentMainWeapon(shipBody) ~= state.mode then
        return
    end

    local targetBodyId = math.floor(request.targetBodyId or 0)
    local targetVehicleId = math.floor(request.targetVehicleId or 0)
    if (targetBodyId == 0 or not IsHandleValid(targetBodyId)) and targetVehicleId == 0 then return end
    if targetBodyId ~= 0 and targetBodyId == shipBody then return end
    if targetBodyId ~= 0 and server.registryShipExists(targetBodyId) and server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(targetBodyId) then
        return
    end

    local launcher = _guidedGroupChooseLauncher(state)
    if launcher == nil then return end
    local config = launcher.config or {}
    local runtime = launcher.runtime or {}
    if tostring(config.weaponType or "none") == "none" or tostring(config.prefabPath or "") == "" then return end

    local shipT = GetBodyTransform(shipBody)
    local fireLocal = Vec(config.firePosOffset.x or 0.0, config.firePosOffset.y or 0.0, config.firePosOffset.z or 0.0)
    local fireDirLocal = Vec(config.fireDirRelative.x or 0.0, config.fireDirRelative.y or 0.0, config.fireDirRelative.z or -1.0)
    local fireDirWorld = server.guidedProjectileNormalize(TransformToParentVec(shipT, fireDirLocal), Vec(0, 0, -1))
    local firePosWorld = TransformToParentPoint(shipT, fireLocal)
    firePosWorld = VecAdd(firePosWorld, VecScale(fireDirWorld, config.spawnForwardOffset or 0.0))

    local projectile = server.guidedProjectileSpawn(shipBody, state.mode, config, firePosWorld, fireDirWorld, targetBodyId, targetVehicleId)
    if projectile ~= nil then
        runtime.cooldownRemain = math.max(0.0, tonumber(config.cooldown) or 0.0)
        _guidedGroupPushHud(state)
    end
end
