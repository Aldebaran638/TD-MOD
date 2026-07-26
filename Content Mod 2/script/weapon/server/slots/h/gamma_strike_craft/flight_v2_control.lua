---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

function server.hSlotV2SpawnBody(prefabPath, spawnPosition, forwardDirection)
    if prefabPath == nil or prefabPath == "" then return 0 end
    local direction = server.hSlotV2Normalize(
        forwardDirection, Vec(0, 0, -1)
    )
    local transform = Transform(
        spawnPosition,
        QuatLookAt(spawnPosition, VecAdd(spawnPosition, direction))
    )
    local entities = Spawn(prefabPath, transform, true, false) or {}
    for i = 1, #entities do
        local entity = entities[i]
        if entity ~= nil and entity ~= 0 and GetEntityType(entity) == "body" then
            return entity
        end
    end
    return 0
end

function server.hSlotV2PickReadyLauncher(state)
    local launchers = state.launchers or {}
    local activeCrafts = state.activeCrafts or {}
    for i = 1, #launchers do
        local runtime = launchers[i] and launchers[i].runtime or nil
        if runtime ~= nil
            and (runtime.cooldownRemain or 0.0) <= 0.0
            and activeCrafts[i] == nil then
            return i, launchers[i]
        end
    end
    return nil, nil
end

function server.hSlotV2ResetRuntime()
    local state = server.hSlotState or {}
    for slotIndex, craft in pairs(state.activeCrafts or {}) do
        local _ = slotIndex
        server.hSlotV2DeleteCraftBody((craft or {}).bodyId or 0)
    end
    state.activeCrafts = {}
    state.fireRequested = false
    for i = 1, #(state.launchers or {}) do
        local runtime = state.launchers[i] and state.launchers[i].runtime or nil
        if runtime ~= nil then runtime.cooldownRemain = 0.0 end
    end
    server.hSlotLastFireRequest = nil
    server.hSlotState = state
end

function server.hSlotV2UpdateCraft(shipBody, state, slotIndex, craft, config, frameDt)
    if craft.bodyId == nil or craft.bodyId == 0 or not IsHandleValid(craft.bodyId) then
        server.hSlotV2SetDebugReason(slotIndex, "craft_invalid_handle", craft)
        server.hSlotV2FinishCraft(state, slotIndex)
        return
    end

    local bodyTransform = GetBodyTransform(craft.bodyId)
    craft.pos = bodyTransform.pos
    local currentVelocity = GetBodyVelocity(craft.bodyId)
    local fallbackDirection = server.hSlotV2Normalize(
        TransformToParentVec(bodyTransform, Vec(0, 0, -1)),
        craft.forward or Vec(0, 0, -1)
    )
    craft.forward = server.hSlotV2Normalize(currentVelocity, fallbackDirection)

    if not server.hSlotV2UpdateDamageState(
        shipBody, state, slotIndex, craft, config, frameDt
    ) then
        return
    end

    craft.lifeRemain = (craft.lifeRemain or 0.0) - frameDt
    if craft.lifeRemain <= 0.0 then
        server.hSlotV2SetDebugReason(slotIndex, "life_timeout_explode", craft)
        server.hSlotV2CraftExplode(shipBody, craft, config)
        server.hSlotV2FinishCraft(state, slotIndex)
        return
    end

    if craft.state == "disabled" then
        craft.fireRemain = math.huge
        SetBodyActive(craft.bodyId, true)
        return
    end

    local targetBodyId = math.floor(craft.targetBodyId or 0)
    local targetCenter = server.hSlotV2GetBodyCenter(targetBodyId)
    local targetIsRegistered = targetBodyId ~= 0
        and server.registryShipExists(targetBodyId)
    local targetIsDead = targetIsRegistered
        and server.registryShipIsBodyDead ~= nil
        and server.registryShipIsBodyDead(targetBodyId)
    if targetIsDead then targetCenter = nil end
    if targetCenter ~= nil then
        craft.lastTargetCenter = targetCenter
    elseif not targetIsRegistered then
        targetCenter = craft.lastTargetCenter
    end
    if targetIsRegistered and (targetIsDead or targetCenter == nil) then
        craft.state = "returning"
    end

    if craft.state ~= "returning" and craft.state ~= "docking" then
        craft.attackRemain = (craft.attackRemain or config.attackDuration) - frameDt
        if craft.attackRemain <= 0.0 or targetCenter == nil then
            craft.state = "returning"
            craft.returnRemain = math.max(
                tonumber(craft.returnRemain) or 0.0,
                math.max(0.5, tonumber(config.returnTimeout) or 6.0)
            )
            server.hSlotV2SetDebugReason(
                slotIndex, "attack_window_elapsed_return", craft
            )
        end
    end

    if craft.state == "returning" or craft.state == "docking" then
        craft.returnRemain = (craft.returnRemain or config.returnTimeout) - frameDt
        if craft.returnRemain <= 0.0 then
            server.hSlotV2SetDebugReason(slotIndex, "return_timeout_explode", craft)
            server.hSlotV2CraftExplode(shipBody, craft, config)
            server.hSlotV2FinishCraft(state, slotIndex)
            return
        end
    end

    local desiredDirection, recovered = server.hSlotV2ResolveMission(
        shipBody, craft, targetCenter, config, frameDt
    )
    if recovered then
        server.hSlotV2SetDebugReason(slotIndex, "return_recovered_finish", craft)
        server.hSlotV2FinishCraft(state, slotIndex, "ready")
        return
    end
    if desiredDirection == nil then return end

    craft.avoidCheckRemain = (craft.avoidCheckRemain or 0.0) - frameDt
    craft.avoidRemain = math.max(0.0, (craft.avoidRemain or 0.0) - frameDt)
    local avoidanceDirection = nil
    if craft.avoidRemain > 0.0 and craft.avoidDir ~= nil then
        avoidanceDirection = craft.avoidDir
    elseif craft.avoidCheckRemain <= 0.0 then
        local queryCount
        avoidanceDirection, craft.avoidBlocked, _, _, queryCount =
            server.hSlotV2ResolveAvoidance(
                shipBody, craft, desiredDirection, config
            )
        craft.lastAvoidQueryCount = queryCount or 0
        craft.avoidCheckRemain = math.max(
            0.03, tonumber(config.avoidCheckInterval) or 0.1
        )
        if craft.avoidBlocked then
            craft.avoidDir = avoidanceDirection
            craft.avoidRemain = math.max(
                0.12, tonumber(config.avoidHoldDuration) or 0.42
            )
        else
            craft.avoidDir = nil
            craft.avoidRemain = 0.0
        end
    else
        avoidanceDirection = desiredDirection
        craft.avoidBlocked = false
    end
    avoidanceDirection = server.hSlotV2Normalize(
        avoidanceDirection or desiredDirection,
        craft.forward or desiredDirection
    )

    local turnBlend = math.min(
        1.0,
        math.max(0.0, tonumber(config.turnLerp) or 4.0) * frameDt
    )
    local blendedDirection = server.hSlotV2Normalize(
        VecAdd(
            VecScale(craft.forward or avoidanceDirection, 1.0 - turnBlend),
            VecScale(avoidanceDirection, turnBlend)
        ),
        avoidanceDirection
    )
    local speed = server.hSlotV2ResolveSpeed(
        craft, blendedDirection, config
    )
    local nextPosition = VecAdd(
        craft.pos, VecScale(blendedDirection, speed * frameDt)
    )
    local collisionHandled = server.hSlotV2Sweep(
        shipBody, craft, nextPosition, config
    )
    if collisionHandled then
        server.hSlotV2SetDebugReason(slotIndex, "step_collision_evade", craft)
        return
    end

    craft.forward = blendedDirection
    craft.pos = nextPosition
    craft.desiredRot = QuatLookAt(
        craft.pos, VecAdd(craft.pos, blendedDirection)
    )
    SetBodyActive(craft.bodyId, true)
    SetBodyVelocity(craft.bodyId, VecScale(blendedDirection, speed))
    ConstrainOrientation(
        craft.bodyId,
        0,
        GetBodyTransform(craft.bodyId).rot,
        craft.desiredRot,
        config.turnRate or 0.0,
        config.turnImpulse or 0.0
    )

    if craft.state == "attack_run"
        and not craft.damaged
        and targetCenter ~= nil then
        server.hSlotV2UpdateBeam(
            shipBody, craft, targetCenter, config, frameDt
        )
    end
end

function server.hSlotV2ControlTick(dt)
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then return end
    if not server.registryShipEnsure(
        shipBody, server.defaultShipType, server.defaultShipType
    ) then
        return
    end

    local state = server.hSlotState
    if state == nil then return end
    if server.registryShipIsBodyDead ~= nil
        and server.registryShipIsBodyDead(shipBody) then
        server.hSlotV2SetDebugReason(0, "owner_ship_dead", nil)
        server.hSlotV2ResetRuntime()
        return
    end

    local frameDt = math.max(0.0, tonumber(dt) or 0.0)
    local launchers = state.launchers or {}
    for i = 1, #launchers do
        local launcher = launchers[i]
        launcher.config = server.hSlotV2ResolveConfig(launcher.config)
        local runtime = launcher.runtime
        if runtime ~= nil and (runtime.cooldownRemain or 0.0) > 0.0 then
            runtime.cooldownRemain = math.max(
                0.0, (runtime.cooldownRemain or 0.0) - frameDt
            )
        end
    end

    for slotIndex = 1, #launchers do
        local craft = (state.activeCrafts or {})[slotIndex]
        if craft ~= nil then
            server.hSlotV2UpdateCraft(
                shipBody,
                state,
                slotIndex,
                craft,
                launchers[slotIndex].config,
                frameDt
            )
        end
    end

    if server.hSlotControlSyncHud ~= nil then
        server.hSlotControlSyncHud()
    end

    if not state.fireRequested then
        server.hSlotV2SetDebugStage("tick_idle_v2")
        return
    end
    state.fireRequested = false

    local request = server.hSlotLastFireRequest
    server.hSlotLastFireRequest = nil
    local debugState = server.hSlotDebugState or {}
    debugState.fireFlag = 0
    debugState.requestHas = request ~= nil and 1 or 0
    debugState.requestTarget = request ~= nil
        and math.floor(request.targetBodyId or 0)
        or 0
    debugState.stage = request ~= nil and "request_consumed_v2" or "request_empty_v2"
    server.hSlotDebugState = debugState
    if request == nil then return end

    local targetBodyId = math.floor(request.targetBodyId or 0)
    if targetBodyId == 0 then
        server.hSlotV2SetDebugReason(0, "request_target_missing", nil)
        return
    end

    local slotIndex, launcher = server.hSlotV2PickReadyLauncher(state)
    if slotIndex == nil or launcher == nil then
        server.hSlotV2SetDebugReason(
            0, "fire_requested_but_no_ready_launcher", nil
        )
        server.hSlotV2SetDebugStage("no_ready_launcher_v2")
        return
    end
    local config = server.hSlotV2ResolveConfig(launcher.config)

    local shipTransform = GetBodyTransform(shipBody)
    local firePos = config.firePosOffset or {}
    local fireDir = config.fireDirRelative or {}
    local spawnPosition = TransformToParentPoint(
        shipTransform,
        Vec(
            tonumber(firePos.x) or 0.0,
            tonumber(firePos.y) or 0.0,
            tonumber(firePos.z) or -1.0
        )
    )
    local forwardDirection = server.hSlotV2Normalize(
        TransformToParentVec(
            shipTransform,
            Vec(
                tonumber(fireDir.x) or 0.0,
                tonumber(fireDir.y) or 0.0,
                tonumber(fireDir.z) or -1.0
            )
        ),
        Vec(0, 0, -1)
    )
    spawnPosition = VecAdd(
        spawnPosition,
        VecScale(forwardDirection, config.spawnForwardOffset or 0.0)
    )

    local craftBody = server.hSlotV2SpawnBody(
        config.prefabPath, spawnPosition, forwardDirection
    )
    if craftBody == nil or craftBody == 0 then
        server.hSlotV2SetDebugReason(slotIndex, "spawn_failed", nil)
        return
    end

    SetBodyDynamic(craftBody, true)
    SetBodyActive(craftBody, true)
    server.registryShipRegister(
        craftBody,
        config.craftShipType or "gammaStrikeCraft",
        "gammaStrikeCraft"
    )
    if not server.registryShipExists(craftBody) then
        server.hSlotV2DeleteCraftBody(craftBody)
        server.hSlotV2SetDebugReason(slotIndex, "spawn_registry_failed", nil)
        return
    end
    SetBodyVelocity(
        craftBody,
        VecScale(
            forwardDirection,
            math.max(4.0, tonumber(config.craftSpeed) or 30.0)
        )
    )

    state.activeCrafts[slotIndex] = {
        slotIndex = slotIndex,
        bodyId = craftBody,
        weaponType = tostring(config.weaponType or "gammaStrikeCraft"),
        targetBodyId = targetBodyId,
        pos = spawnPosition,
        forward = forwardDirection,
        state = "approach",
        attackRemain = math.max(
            0.5, tonumber(config.attackDuration) or 10.0
        ),
        attackRunRemain = 0.0,
        disengageRemain = 0.0,
        lifeRemain = math.max(
            0.5, tonumber(config.craftLifetime) or 24.0
        ),
        returnRemain = math.max(
            0.5, tonumber(config.returnTimeout) or 6.0
        ),
        fireRemain = 0.0,
        healthCheckRemain = 0.0,
        avoidCheckRemain = 0.0,
        avoidRemain = 0.0,
        avoidDir = nil,
        avoidBlocked = false,
        damaged = false,
        integrity = 1.0,
    }
    server.hSlotV2SetDebugReason(
        slotIndex, "spawn_success_v2", state.activeCrafts[slotIndex]
    )
    server.hSlotV2SetDebugStage("active_registered_v2")
    if server.hSlotControlSyncHud ~= nil then
        server.hSlotControlSyncHud()
    end
end

function server.hSlotV2Install()
    if server.hSlotV2Installed then return end
    server.hSlotV2Installed = true
    server.hSlotControlTick = server.hSlotV2ControlTick
end
