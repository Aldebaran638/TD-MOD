---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

function server.sSlotLauncherTick(dt)
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        return
    end
    if not server.registryShipEnsure(shipBody, server.defaultShipType, server.defaultShipType) then
        return
    end

    local state = server.sSlotState
    if state == nil then
        return
    end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(shipBody) then
        server.sSlotStateResetRuntime()
        return
    end

    local launchers = state.launchers or {}
    for i = 1, #launchers do
        local runtime = launchers[i] and launchers[i].runtime or nil
        if runtime ~= nil and (runtime.cooldownRemain or 0.0) > 0.0 then
            runtime.cooldownRemain = math.max(0.0, (runtime.cooldownRemain or 0.0) - (dt or 0.0))
        end
    end

    server.sSlotControlSyncHud()

    local active = state.activeMissiles or {}
    local i = #active
    while i >= 1 do
        local missile = active[i]
        local bodyId = missile and missile.bodyId or 0
        if bodyId == 0 or not IsHandleValid(bodyId) then
            server.sSlotRemoveMissileAt(i)
        else
            local currentPos = server.sSlotGetBodyCenterWorld(bodyId)
            if currentPos == nil then
                server.sSlotRemoveMissileAt(i)
            end
        end

        i = i - 1
    end

    local request = server.sSlotConsumeFireRequest()
    if request == nil then
        return
    end
    if server.shipRuntimeGetCurrentMainWeapon ~= nil and server.shipRuntimeGetCurrentMainWeapon(shipBody) ~= "sSlot" then
        return
    end

    local targetBodyId = math.floor(request.targetBodyId or 0)
    local targetVehicleId = math.floor(request.targetVehicleId or 0)
    if (targetBodyId == 0 or not IsHandleValid(targetBodyId)) and targetVehicleId == 0 then
        return
    end
    if targetBodyId ~= 0 and targetBodyId == shipBody then
        return
    end
    if targetBodyId ~= 0 and server.registryShipExists(targetBodyId) and server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(targetBodyId) then
        return
    end

    local launcher = server.sSlotChooseLauncher(state)
    if launcher == nil then
        return
    end

    local launcherConfig = launcher.config or {}
    local launcherRuntime = launcher.runtime or {}
    local shipT = GetBodyTransform(shipBody)
    local fireLocal = Vec(
        launcherConfig.firePosOffset.x or 0.0,
        launcherConfig.firePosOffset.y or 0.0,
        launcherConfig.firePosOffset.z or 0.0
    )
    local fireDirLocal = Vec(
        launcherConfig.fireDirRelative.x or 0.0,
        launcherConfig.fireDirRelative.y or 0.0,
        launcherConfig.fireDirRelative.z or -1.0
    )
    local fireDirWorld = server.sSlotNormalize(TransformToParentVec(shipT, fireDirLocal), Vec(0, 0, -1))
    local firePosWorld = TransformToParentPoint(shipT, fireLocal)
    firePosWorld = VecAdd(firePosWorld, VecScale(fireDirWorld, launcherConfig.spawnForwardOffset or 0.0))

    local missileBody = server.sSlotSpawnMissileBody(launcherConfig.prefabPath, firePosWorld, fireDirWorld)
    if missileBody == nil or missileBody == 0 then
        return
    end

    SetBodyDynamic(missileBody, true)
    SetBodyActive(missileBody, true)
    local ownerVelocity = GetBodyVelocity(shipBody)
    local startVelocity = VecAdd(ownerVelocity, VecScale(fireDirWorld, launcherConfig.muzzleSpeed or 0.0))
    SetBodyVelocity(missileBody, startVelocity)

    local missileId = state.nextMissileId or 1
    state.nextMissileId = missileId + 1

    ClientCall(
        0,
        "client.spawnMissileVisual",
        missileId,
        firePosWorld[1], firePosWorld[2], firePosWorld[3],
        startVelocity[1], startVelocity[2], startVelocity[3]
    )

    ClientCall(
        0,
        "client.spawnMissileWarpFx",
        firePosWorld[1], firePosWorld[2], firePosWorld[3]
    )

    local spawnedProbes = server.sSlotGetProbePoints(GetBodyTransform(missileBody))
    table.insert(active, {
        id = missileId,
        bodyId = missileBody,
        ownerShipBody = shipBody,
        targetBodyId = targetBodyId,
        targetVehicleId = targetVehicleId,
        damage = launcherConfig.damage or 0.0,
        armorFix = launcherConfig.armorFix or 1.0,
        bodyFix = launcherConfig.bodyFix or 1.0,
        cruiseSpeed = launcherConfig.cruiseSpeed or 0.0,
        maxSpeed = launcherConfig.maxSpeed or 0.0,
        acceleration = launcherConfig.acceleration or 0.0,
        maxRange = launcherConfig.maxRange or 0.0,
        turnBlendRate = launcherConfig.turnBlendRate or 0.0,
        turnRate = launcherConfig.turnRate or 0.0,
        turnImpulse = launcherConfig.turnImpulse or 0.0,
        lifeRemain = launcherConfig.lifetime or 0.0,
        distanceTravelled = 0.0,
        prePhysicsCenterPos = Vec(spawnedProbes.center[1], spawnedProbes.center[2], spawnedProbes.center[3]),
        prePhysicsHeadPos = Vec(spawnedProbes.head[1], spawnedProbes.head[2], spawnedProbes.head[3]),
        prePhysicsMidPos = Vec(spawnedProbes.mid[1], spawnedProbes.mid[2], spawnedProbes.mid[3]),
        desiredRot = QuatLookAt(firePosWorld, VecAdd(firePosWorld, fireDirWorld)),
    })

    launcherRuntime.cooldownRemain = math.max(0.0, launcherConfig.cooldown or 0.0)
    server.sSlotPlayFireSound(firePosWorld)
end
