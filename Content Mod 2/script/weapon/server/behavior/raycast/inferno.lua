---@diagnostic disable: undefined-global

-- Perdition Beam's one-shot, high-energy ray behaviour.  Registered ships are
-- damaged only through the ship damage system; Teardown world APIs are isolated
-- to the non-ship branch below.
server = server or {}
server.infernoRaycastState = server.infernoRaycastState or { worldEvents = {}, shipEvents = {} }

local function _safeNormalize(value, fallback)
    return server.weaponBehaviorNormalize(value, fallback or Vec(0, 0, -1))
end

local function _isRegisteredShip(bodyId)
    return bodyId ~= 0 and server.registryShipExists ~= nil and server.registryShipExists(bodyId)
end

local function _rayHitsTaggedTarget(ray, tag)
    local targetTag = tostring(tag or "")
    if targetTag == "" or HasTag == nil then return false end
    local shape = math.floor((ray or {}).shape or 0)
    local body = math.floor((ray or {}).hitBody or 0)
    return (shape ~= 0 and HasTag(shape, targetTag))
        or (body ~= 0 and HasTag(body, targetTag))
end

local function _worldExplosionCount(ray, definition, profile)
    local def = definition or {}
    local world = profile or {}
    local count = math.max(1, math.floor(
        tonumber(world.explosionCount) or tonumber(def.infernoWorldExplosionCount) or 5
    ))
    local dragonTag = world.dragonTag or def.infernoDragonTargetTag
    if _rayHitsTaggedTarget(ray, dragonTag) then
        count = math.max(1, math.floor(
            tonumber(world.dragonExplosionCount) or tonumber(def.infernoDragonExplosionCount) or count
        ))
    end
    return math.min(16, count)
end

local function _bodyCenter(bodyId)
    if bodyId == 0 or (IsHandleValid ~= nil and not IsHandleValid(bodyId)) then return nil end
    local transform = GetBodyTransform(bodyId)
    return TransformToParentPoint(transform, GetBodyCenterOfMass(bodyId))
end

local function _pushRenderEvent(context, ray, didHitShield, impactLayer)
    if tostring(context.slotType or "") ~= "T" or server.tSlotRenderPushEvent == nil then return end
    server.tSlotRenderPushEvent(context.shipBodyId, {
        eventType = "launch_start", incrementShotId = 1, slotIndex = context.mountIndex,
        weaponType = context.weaponType, firePoint = ray.origin, hitPoint = ray.endpoint,
        didHit = ray.hit, didHitStellarisBody = ray.hitRegisteredShip,
        didHitShield = didHitShield, hitTargetBodyId = ray.hitBody, normal = ray.normal,
        impactLayer = impactLayer or "none",
    })
end

local function _playShotSound(ray, weaponType)
    ClientCall(0, "client.playWeaponSound", weaponType, "fire", ray.origin[1], ray.origin[2], ray.origin[3])
    if ray.hit then
        ClientCall(0, "client.playWeaponSound", weaponType, "hit", ray.endpoint[1], ray.endpoint[2], ray.endpoint[3])
    end
end

local function _isOwnedInterceptor(bodyId, ownerBodyId)
    return server.registryShipGetOwnerBody ~= nil
        and server.registryShipGetOwnerBody(bodyId) == ownerBodyId
end

local function _applyShipPulse(context, center, radius, rawDamage)
    if server.registryShipGetRegisteredCount == nil or server.registryShipGetRegisteredBodyIdAt == nil then return end
    local def = context.weaponDefinition or {}
    local core = math.max(0.0, tonumber(def.infernoPulseCoreRadius) or 24.0)
    local maximum = math.max(core + 0.001, tonumber(radius) or tonumber(def.infernoPulseMaxRadius) or 60.0)
    local coreScale = math.max(0.0, tonumber(def.infernoPulseCoreScale) or 0.33)
    local edgeScale = math.max(0.0, tonumber(def.infernoPulseEdgeScale) or 0.05)
    local seen = {}
    local count = math.max(0, math.floor(server.registryShipGetRegisteredCount() or 0))
    for index = 1, count do
        local bodyId = math.floor(server.registryShipGetRegisteredBodyIdAt(index) or 0)
        if bodyId ~= 0 and not seen[bodyId] and _isRegisteredShip(bodyId)
            and bodyId ~= context.shipBodyId and not _isOwnedInterceptor(bodyId, context.shipBodyId) then
            seen[bodyId] = true
            local targetCenter = _bodyCenter(bodyId)
            if targetCenter ~= nil then
                local distance = VecLength(VecSub(targetCenter, center))
                if distance <= maximum then
                    local t = math.max(0.0, math.min(1.0, (distance - core) / (maximum - core)))
                    local scale = distance <= core and coreScale or coreScale + (edgeScale - coreScale) * t
                    server.weaponDamageApplyRolledToShip(
                        bodyId, context.weaponType, rawDamage * math.max(0.0, scale), context.shipBodyId
                    )
                end
            end
        end
    end
end

local function _applyDynamicImpulse(center, profile)
    local impulse = (profile or {}).impulse or {}
    local radius = math.max(0.0, tonumber(impulse.radius) or 28.0)
    local maxBodies = math.max(0, math.floor(tonumber(impulse.maxBodies) or 20))
    local maxMass = math.max(0.0, tonumber(impulse.maxMass) or 250.0)
    local strength = tonumber(impulse.strength) or 420.0
    local massScale = math.max(0.001, tonumber(impulse.massScale) or 0.08)
    local extent = Vec(radius, radius, radius)
    QueryRequire("physical")
    local bodies = QueryAabbBodies(VecSub(center, extent), VecAdd(center, extent)) or {}
    local applied = 0
    for _, bodyId in ipairs(bodies) do
        if applied >= maxBodies then break end
        if bodyId ~= 0 and not _isRegisteredShip(bodyId) and IsBodyDynamic(bodyId) then
            local mass = math.max(0.001, tonumber(GetBodyMass(bodyId)) or 0.0)
            if mass <= maxMass then
                local bodyCenter = _bodyCenter(bodyId)
                if bodyCenter ~= nil then
                    local offset = VecSub(bodyCenter, center)
                    local distance = VecLength(offset)
                    if distance <= radius then
                        local direction = _safeNormalize(offset, Vec(0, 1, 0))
                        local scale = (1.0 - distance / radius) * (1.0 - distance / radius)
                        ApplyBodyImpulse(bodyId, bodyCenter, VecScale(
                            direction,
                            strength * scale / math.max(1.0, mass * massScale)
                        ))
                        applied = applied + 1
                    end
                end
            end
        end
    end
end

local function _startWorldEvent(ray, definition)
    if not server.weaponEffectBudgetTakeWorld(2.0) then return end
    local world = (definition or {}).infernoWorldProfile or {}
    local entrance = world.entranceHole or { 11.0, 9.0, 7.0 }
    local tunnelCount = math.max(0, math.floor(tonumber(world.tunnelNodeCount) or 3))
    local tunnelSpacing = tonumber(world.tunnelNodeSpacing) or 10.0
    local tunnelStart = tonumber(world.tunnelStartRadius) or 8.0
    local tunnelStep = tonumber(world.tunnelRadiusStep) or -1.7
    local tunnelVoxelOffset = tonumber(world.tunnelVoxelOffset) or -1.5
    local tunnelMaterialOffset = tonumber(world.tunnelMaterialOffset) or -3.0
    local endpoint, direction = ray.endpoint, ray.direction
    MakeHole(endpoint, entrance[1] or 11.0, entrance[2] or 9.0, entrance[3] or 7.0)
    for node = 1, tunnelCount do
        local point = VecAdd(endpoint, VecScale(direction, node * tunnelSpacing))
        local size = tunnelStart + node * tunnelStep
        MakeHole(point, size, math.max(2.0, size + tunnelVoxelOffset),
            math.max(1.0, size + tunnelMaterialOffset))
    end
    -- The first impact point receives a configured concentrated detonation.
    -- This branch is only reached for ordinary world geometry; registered
    -- ships never enter it and therefore never receive physical explosions.
    for _ = 1, _worldExplosionCount(ray, definition, world) do
        Explosion(endpoint, 4.0)
    end
    _applyDynamicImpulse(endpoint, world)
    server.infernoRaycastState.worldEvents[#server.infernoRaycastState.worldEvents + 1] = {
        point = endpoint, direction = direction, shape = ray.shape or 0, age = 0.0,
        pulse = 0.0, secondary = false, fires = 0, profile = world,
    }
end

local function _fireInfernoRaycast(context)
    local ray = server.weaponRaycastResolve(context)
    local rawDamage = server.weaponDamageRoll(context.weaponDefinition or {})
    local didHitShield, impactLayer = false, "none"

    if ray.hitRegisteredShip then
        local result = server.weaponDamageApplyRolledToShip(
            ray.hitBody, context.weaponType, rawDamage, context.shipBodyId
        )
        didHitShield, impactLayer = result.didHitShield, result.impactLayer
        server.weaponRaycastApplyShieldEndpoint(ray, didHitShield)
        if didHitShield then
            ClientCall(0, "client.playProjectileShieldImpactFx", ray.hitBody, ray.endpoint[1], ray.endpoint[2], ray.endpoint[3], context.weaponType)
        end
        _applyShipPulse(context, ray.endpoint, nil, rawDamage)
        server.infernoRaycastState.shipEvents[#server.infernoRaycastState.shipEvents + 1] = {
            context = context, point = ray.endpoint, rawDamage = rawDamage, age = 0.0, aftershock = false,
        }
    elseif ray.hit then
        _startWorldEvent(ray, context.weaponDefinition)
    end

    _playShotSound(ray, context.weaponType)
    _pushRenderEvent(context, ray, didHitShield, impactLayer)
    return true
end

local function _tickWorldEvents(dt)
    local events = server.infernoRaycastState.worldEvents
    for index = #events, 1, -1 do
        local event = events[index]
        local profile = event.profile or {}
        event.age = event.age + dt
        event.pulse = event.pulse + dt
        local interval = math.max(0.001, tonumber(profile.residualInterval) or 0.16)
        local duration = math.max(0.0, tonumber(profile.residualDuration) or 0.70)
        if event.pulse >= interval and event.age < duration then
            event.pulse = event.pulse - interval
            if server.weaponEffectBudgetTakeWorld(0.35) then
                local radius = (tonumber(profile.residualStartRadius) or 3.5)
                    + event.age * (tonumber(profile.residualRadiusGrowth) or 4.0)
                MakeHole(event.point, radius,
                    math.max(1.0, radius + (tonumber(profile.residualVoxelOffset) or -1.0)),
                    math.max(0.5, radius + (tonumber(profile.residualMaterialOffset) or -2.0)))
                if event.shape ~= 0 and (IsHandleValid == nil or IsHandleValid(event.shape)) then
                    AddHeat(event.shape, event.point, 1.0)
                end
                PaintRGBA(event.point, radius * (tonumber(profile.residualPaintScale) or 1.4), 0.12, 0.025, 0.005, 0.75)
                if event.fires < math.max(0, math.floor(tonumber(profile.residualFireCount) or 6)) then
                    SpawnFire(VecAdd(event.point, VecScale(event.direction, event.fires * 1.2)))
                    event.fires = event.fires + 1
                end
            end
        end
        if not event.secondary and event.age >= (tonumber(profile.secondaryDelay) or 0.34) then
            event.secondary = true
            if server.weaponEffectBudgetTakeWorld(1.0) then
                Explosion(event.point, tonumber(profile.secondaryExplosionSize) or 2.0)
            end
        end
        if event.age >= duration then table.remove(events, index) end
    end
end

local function _tickShipEvents(dt)
    local events = server.infernoRaycastState.shipEvents
    for index = #events, 1, -1 do
        local event = events[index]
        event.age = event.age + dt
        local delay = math.max(0.0, tonumber((event.context.weaponDefinition or {}).infernoAftershockDelay) or 0.25)
        if not event.aftershock and event.age >= delay then
            event.aftershock = true
            local scale = math.max(0.0, tonumber((event.context.weaponDefinition or {}).infernoAftershockScale) or 0.16)
            local maximum = tonumber((event.context.weaponDefinition or {}).infernoPulseMaxRadius) or 60.0
            _applyShipPulse(event.context, event.point, maximum, event.rawDamage * scale)
        end
        if event.aftershock then table.remove(events, index) end
    end
end

local function _tickInfernoRaycast(dt)
    local delta = math.max(0.0, tonumber(dt) or 0.0)
    _tickWorldEvents(delta)
    _tickShipEvents(delta)
end

server.weaponBehaviorRegister("infernoRaycast", { fire = _fireInfernoRaycast, tick = _tickInfernoRaycast })
