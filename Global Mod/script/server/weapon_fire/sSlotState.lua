---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.sSlotState = server.sSlotState or {
    nextMissileId = 1,
    nextLauncherIndex = 1,
    launchers = {},
    activeMissiles = {},
}

server.sSlotProbeHeadLocal = Vec(0, 0, -3.2)
server.sSlotProbeMidLocal = Vec(0, 0, -1.0)

function server.sSlotCloneVec3(v, defaultX, defaultY, defaultZ)
    local t = v or {}
    return {
        x = tonumber(t.x) or defaultX or 0.0,
        y = tonumber(t.y) or defaultY or 0.0,
        z = tonumber(t.z) or defaultZ or 0.0,
    }
end

function server.sSlotResolveShipDefinition(shipType)
    local defs = shipTypeRegistryData or {}
    local requested = shipType or server.defaultShipType or "enigmaticCruiser"
    return defs[requested] or defs[server.defaultShipType] or defs.enigmaticCruiser or {}
end

function server.sSlotResolveWeaponDefinition(weaponType)
    local defs = sSlotWeaponRegistryData or {}
    local requested = weaponType or "swarmerMissile"
    return defs[requested] or defs.swarmerMissile or {}
end

function server.sSlotNormalize(v, fallback)
    local len = VecLength(v)
    if len < 0.0001 then
        return fallback or Vec(0, 0, -1)
    end
    return VecScale(v, 1.0 / len)
end

function server.sSlotGetBodyCenterWorld(bodyId)
    if bodyId == nil or bodyId == 0 or not IsHandleValid(bodyId) then
        return nil
    end
    local bodyT = GetBodyTransform(bodyId)
    local centerLocal = GetBodyCenterOfMass(bodyId)
    return TransformToParentPoint(bodyT, centerLocal)
end

function server.sSlotGetProbePoints(bodyT)
    return {
        center = bodyT.pos,
        head = TransformToParentPoint(bodyT, server.sSlotProbeHeadLocal),
        mid = TransformToParentPoint(bodyT, server.sSlotProbeMidLocal),
    }
end

function server.sSlotBuildLauncherConfig(slotDef)
    local weaponType = tostring((slotDef and slotDef.weaponType) or "swarmerMissile")
    local weaponDef = server.sSlotResolveWeaponDefinition(weaponType)
    return {
        weaponType = weaponType,
        firePosOffset = server.sSlotCloneVec3(slotDef and slotDef.firePosOffset, 0.0, 0.0, 0.0),
        fireDirRelative = server.sSlotCloneVec3(slotDef and slotDef.fireDirRelative, 0.0, 0.0, -1.0),
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
        armorFix = tonumber(weaponDef.armorFix) or 1.0,
        bodyFix = tonumber(weaponDef.bodyFix) or 1.0,
    }
end

function server.sSlotBuildLauncherRuntime()
    return {
        cooldownRemain = 0.0,
    }
end

function server.sSlotPlayFireSound(firePos)
    local p = firePos or Vec(0, 0, 0)
    ClientCall(0, "client.playMissileFireSound", p[1], p[2], p[3])
end

function server.sSlotPlayImpactSound(hitPos)
    local p = hitPos or Vec(0, 0, 0)
    ClientCall(0, "client.playMissileImpactSound", p[1], p[2], p[3])
end

function server.sSlotPlayImpactFx(hitPos, impactLayer)
    local p = hitPos or Vec(0, 0, 0)
    ClientCall(0, "client.playMissileImpactFx", p[1], p[2], p[3], impactLayer or "body")
end

function server.sSlotDeleteMissileBody(bodyId)
    if bodyId ~= nil and bodyId ~= 0 and IsHandleValid(bodyId) then
        Delete(bodyId)
    end
end

function server.sSlotRemoveMissileAt(index)
    local active = server.sSlotState.activeMissiles or {}
    local missile = active[index]
    if missile ~= nil then
        server.sSlotDeleteMissileBody(missile.bodyId or 0)
        ClientCall(0, "client.finishMissileVisual", missile.id or 0)
    end

    local last = #active
    if index >= 1 and index <= last then
        active[index] = active[last]
        active[last] = nil
    end
end

function server.sSlotClearAllMissiles()
    local active = server.sSlotState.activeMissiles or {}
    for i = #active, 1, -1 do
        server.sSlotDeleteMissileBody((active[i] or {}).bodyId or 0)
        active[i] = nil
    end
end

function server.sSlotConsumeFireRequest()
    local request = server.sSlotLastFireRequest
    server.sSlotLastFireRequest = nil
    return request
end

function server.sSlotChooseLauncher(state)
    local launchers = state.launchers or {}
    local count = #launchers
    if count <= 0 then
        return nil
    end

    local startIndex = math.floor(state.nextLauncherIndex or 1)
    if startIndex < 1 or startIndex > count then
        startIndex = 1
    end

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

function server.sSlotBuildBodyTransform(spawnPos, forwardDir)
    local eye = spawnPos or Vec(0, 0, 0)
    local target = VecAdd(eye, server.sSlotNormalize(forwardDir, Vec(0, 0, -1)))
    return Transform(eye, QuatLookAt(eye, target))
end

function server.sSlotSpawnMissileBody(prefabPath, spawnPos, forwardDir)
    if prefabPath == nil or prefabPath == "" then
        return 0
    end

    local entities = Spawn(prefabPath, server.sSlotBuildBodyTransform(spawnPos, forwardDir), true, false) or {}
    for i = 1, #entities do
        local entityId = entities[i]
        if entityId ~= nil and entityId ~= 0 and GetEntityType(entityId) == "body" then
            return entityId
        end
    end
    return 0
end

function server.sSlotStateInit(shipType)
    server.sSlotClearAllMissiles()

    local shipDef = server.sSlotResolveShipDefinition(shipType)
    if server.shipSlotLoadoutResolveShipDefinition ~= nil then
        shipDef = server.shipSlotLoadoutResolveShipDefinition(shipType) or shipDef
    end
    local state = {
        nextMissileId = 1,
        nextLauncherIndex = 1,
        launchers = {},
        activeMissiles = {},
    }

    local slotDefs = {}
    local sSlots = shipDef.sSlots or {}
    local gSlots = shipDef.gSlots or {}
    for i = 1, #sSlots do
        slotDefs[#slotDefs + 1] = sSlots[i]
    end
    for i = 1, #gSlots do
        slotDefs[#slotDefs + 1] = gSlots[i]
    end

    for i = 1, #slotDefs do
        state.launchers[i] = {
            config = server.sSlotBuildLauncherConfig(slotDefs[i]),
            runtime = server.sSlotBuildLauncherRuntime(),
        }
    end

    server.sSlotState = state
    server.sSlotLastFireRequest = nil
    return state
end

function server.sSlotStateResetRuntime()
    local state = server.sSlotState or {}
    server.sSlotClearAllMissiles()

    state.nextMissileId = 1
    state.nextLauncherIndex = 1
    local launchers = state.launchers or {}
    for i = 1, #launchers do
        local runtime = launchers[i] and launchers[i].runtime or nil
        if runtime ~= nil then
            runtime.cooldownRemain = 0.0
        end
    end
    server.sSlotLastFireRequest = nil
end

function server.sSlotControlSyncHud()
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        return
    end

    local state = server.sSlotState or {}
    local launchers = state.launchers or {}
    local cd1, cd2, cd3, cd4 = 0.0, 0.0, 0.0, 0.0
    local maxCd1, maxCd2, maxCd3, maxCd4 = 1.0, 1.0, 1.0, 1.0

    for i = 1, 4 do
        local launcher = launchers[i]
        if launcher then
            local config = launcher.config or {}
            local runtime = launcher.runtime or {}
            if i == 1 then
                cd1 = runtime.cooldownRemain or 0.0
                maxCd1 = config.cooldown or 0.0
            elseif i == 2 then
                cd2 = runtime.cooldownRemain or 0.0
                maxCd2 = config.cooldown or 0.0
            elseif i == 3 then
                cd3 = runtime.cooldownRemain or 0.0
                maxCd3 = config.cooldown or 0.0
            elseif i == 4 then
                cd4 = runtime.cooldownRemain or 0.0
                maxCd4 = config.cooldown or 0.0
            end
        end
    end

    ClientCall(0, "client.updateSSlotHudState", shipBody, cd1, cd2, cd3, cd4, maxCd1, maxCd2, maxCd3, maxCd4)
end
