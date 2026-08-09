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
    local contextType = server.shipContextGetType()
    local requested = shipType or contextType
    local shipDef = shipDefinitionGet(requested, contextType)
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
        interceptorShipType = tostring(weaponDef.interceptorShipType or ""),
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
        guidanceProfile = tostring(weaponDef.guidanceProfile or ""),
        damageMin = tonumber(weaponDef.damageMin) or tonumber(weaponDef.damage) or 0.0,
        damageMax = tonumber(weaponDef.damageMax) or tonumber(weaponDef.damage) or 0.0,
        shieldFix = tonumber(weaponDef.shieldFix) or 1.0,
        armorFix = tonumber(weaponDef.armorFix) or 1.0,
        bodyFix = tonumber(weaponDef.bodyFix) or 1.0,
        shieldPenetration = tonumber(weaponDef.shieldPenetration) or 0.0,
        armorPenetration = tonumber(weaponDef.armorPenetration) or 0.0,
        destroyedExplosionSize = tonumber(weaponDef.destroyedExplosionSize) or 0.5,
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

local function _guidedGroupBuildHudSignature(state)
    local parts = {
        tostring(state.mode or ""),
        tostring(server.shipRuntimeGetCurrentMainWeapon ~= nil
            and server.shipRuntimeGetCurrentMainWeapon(server.shipContextGetBody())
            or ""),
    }
    for i = 1, 4 do
        local launcher = (state.launchers or {})[i] or {}
        local runtime = launcher.runtime or {}
        parts[#parts + 1] = string.format(
            "%.1f",
            server.netSyncQuantize(runtime.cooldownRemain or 0.0, 0.1)
        )
    end
    return table.concat(parts, "|")
end

local function _guidedGroupResolveHudPlayer(state)
    local shipBody = server.shipContextGetBody()
    local playerId = server.shipRuntimeGetDriverPlayerId ~= nil
        and math.floor(server.shipRuntimeGetDriverPlayerId(shipBody) or 0)
        or 0
    if playerId <= 0 then return 0 end
    if IsPlayerValid ~= nil and not IsPlayerValid(playerId) then return 0 end

    local vehicle = GetPlayerVehicle(playerId)
    if vehicle == nil or vehicle == 0 or GetVehicleBody(vehicle) ~= shipBody then
        if server.shipRuntimeSetDriverPlayerId ~= nil then
            server.shipRuntimeSetDriverPlayerId(shipBody, 0)
        end
        state.hudSync.dirty = true
        return 0
    end
    return playerId
end

local function _guidedGroupPushHud(state, playerId, signature)
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
        playerId,
        state.hudCallback,
        server.shipContextGetBody(),
        values[1], values[2], values[3], values[4],
        values[5], values[6], values[7], values[8]
    )
    state.hudSync.lastSignature = signature
    state.hudSync.age = 0.0
    state.hudSync.dirty = false
end

local function _guidedGroupMaybePushHud(state, dt, force)
    local sync = state.hudSync
    sync.age = (sync.age or 0.0) + math.max(0.0, tonumber(dt) or 0.0)

    local playerId = _guidedGroupResolveHudPlayer(state)
    if playerId <= 0 then return end

    local signature = _guidedGroupBuildHudSignature(state)
    local changed = signature ~= tostring(sync.lastSignature or "")
    local periodic = sync.age >= 0.2
    local keepAlive = sync.age >= 1.0
    if force or sync.dirty or (changed and periodic) or keepAlive then
        _guidedGroupPushHud(state, playerId, signature)
    end
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
        hudSync = {
            age = 0.0,
            lastSignature = "",
            dirty = true,
        },
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

function server.guidedSlotGroupEnsure(mode, mountCollection, shipType)
    local id = tostring(mode or "")
    local state = server.guidedSlotGroupStateByMode[id]
    if state ~= nil then return state end
    return server.guidedSlotGroupInit(
        id,
        tostring(mountCollection or ""),
        "client.updateMSlotHudState",
        shipType
    )
end

function server.guidedSlotGroupReset(mode)
    local state = server.guidedSlotGroupStateByMode[tostring(mode or "")]
    if state == nil then return end
    state.nextLauncherIndex = 1
    state.request = nil
    state.hudSync.dirty = true
    for i = 1, #(state.launchers or {}) do
        local runtime = ((state.launchers or {})[i] or {}).runtime
        if runtime ~= nil then runtime.cooldownRemain = 0.0 end
    end
end

function server.guidedSlotGroupMarkHudDirty(mode)
    local state = server.guidedSlotGroupStateByMode[tostring(mode or "")]
    if state ~= nil and state.hudSync ~= nil then
        state.hudSync.dirty = true
    end
end

function server.guidedSlotGroupMarkAllHudDirty()
    for _, state in pairs(server.guidedSlotGroupStateByMode or {}) do
        if state.hudSync ~= nil then state.hudSync.dirty = true end
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

function server.guidedSlotGroupClearRequest(mode)
    local state = server.guidedSlotGroupStateByMode[tostring(mode or "")]
    if state ~= nil then state.request = nil end
end

function server.guidedSlotGroupNeedsTick(mode)
    local state = server.guidedSlotGroupStateByMode[tostring(mode or "")]
    if state == nil then return false end
    if state.request ~= nil then return true end
    for _, launcher in ipairs(state.launchers or {}) do
        if (tonumber((launcher.runtime or {}).cooldownRemain) or 0.0) > 0.0 then
            return true
        end
    end
    local body = server.shipContextGetBody()
    return body ~= 0
        and server.shipRuntimeGetDriverPlayerId(body) > 0
        and server.shipRuntimeGetCurrentMainWeapon(body) == tostring(mode or "")
end

function server.guidedSlotGroupNeedsAnyTick()
    for mode in pairs(server.guidedSlotGroupStateByMode or {}) do
        if server.guidedSlotGroupNeedsTick(mode) then return true end
    end
    return false
end

function server.guidedSlotGroupTick(mode, dt)
    local state = server.guidedSlotGroupStateByMode[tostring(mode or "")]
    local shipBody = server.shipContextGetBody()
    if state == nil or shipBody == nil or shipBody == 0 then return end
    local shipType = server.shipContextGetType()
    if not server.registryShipEnsure(shipBody, shipType, shipType) then return end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(shipBody) then
        server.guidedSlotGroupReset(mode)
        return
    end

    for i = 1, #(state.launchers or {}) do
        local runtime = ((state.launchers or {})[i] or {}).runtime
        if runtime ~= nil and (runtime.cooldownRemain or 0.0) > 0.0 then
            local wasCooling = (runtime.cooldownRemain or 0.0) > 0.0
            runtime.cooldownRemain = math.max(0.0, (runtime.cooldownRemain or 0.0) - (dt or 0.0))
            if wasCooling and runtime.cooldownRemain <= 0.0 then
                state.hudSync.dirty = true
            end
        end
    end
    _guidedGroupMaybePushHud(state, dt, false)

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
        state.hudSync.dirty = true
        _guidedGroupMaybePushHud(state, 0.0, true)
    end
end

function server.guidedSlotGroupTickAll(dt)
    for mode in pairs(server.guidedSlotGroupStateByMode or {}) do
        server.guidedSlotGroupTick(mode, dt)
    end
end

function server.guidedSlotGroupResetAll()
    for mode in pairs(server.guidedSlotGroupStateByMode or {}) do
        server.guidedSlotGroupReset(mode)
    end
end
