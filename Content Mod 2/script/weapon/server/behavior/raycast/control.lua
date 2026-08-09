---@diagnostic disable: undefined-global

server = server or {}

local _resolveShieldEndpoint = server.weaponRaycastResolveShieldEndpoint

local function _fireRaycast(context)
    local definition = context.weaponDefinition or {}
    local isChargedRay = tostring(definition.controllerType or "") == "chargedRay"
    local usesDedicatedEnergyLanceFx = isChargedRay
        and tostring(definition.fxProfile or "") == "tachyonLance"
    local ray = server.weaponRaycastResolve(context)
    local origin, direction = ray.origin, ray.direction
    local hit, distance, normal, endpoint = ray.hit, ray.distance, ray.normal, ray.endpoint
    local hitBody = ray.hitBody

    local _, didHitShield, impactLayer = server.weaponDamageApplyToShip(
        hitBody,
        context.weaponType,
        context.shipBodyId
    )
    local hitRegisteredShip = ray.hitRegisteredShip
    local suppressPhysicalExplosion = definition.suppressShipExplosion == true
        and hitRegisteredShip
    if didHitShield then
        local shieldEndpoint, shieldNormal = _resolveShieldEndpoint(origin, direction, hitBody, distance)
        if shieldEndpoint ~= nil then endpoint, normal = shieldEndpoint, shieldNormal end
        ClientCall(
            0,
            "client.playProjectileShieldImpactFx",
            hitBody,
            endpoint[1], endpoint[2], endpoint[3],
            context.weaponType
        )
    end
    if not isChargedRay then
        ClientCall(
            0, "client.playWeaponSound",
            context.weaponType, "fire",
            origin[1], origin[2], origin[3]
        )
        if hit then
            ClientCall(
                0, "client.playWeaponSound",
                context.weaponType, "hit",
                endpoint[1], endpoint[2], endpoint[3]
            )
        end
    end
    if hit and not didHitShield and not suppressPhysicalExplosion then
        local explosionSize = math.max(0.0, tonumber(definition.environmentExplosionSize) or 0.0)
        local explosionCount = math.max(
            1,
            math.min(2, math.floor(tonumber(definition.physicalExplosionCount) or 1))
        )
        if explosionSize > 0.0 then
            for _ = 1, explosionCount do
                Explosion(endpoint, explosionSize)
            end
        end
    end
    if not usesDedicatedEnergyLanceFx then
        ClientCall(
            0, "client.spawnGenericRaycastWeaponFx",
            context.weaponType, tostring(definition.fxProfile or "energyBeam"),
            origin[1], origin[2], origin[3],
            endpoint[1], endpoint[2], endpoint[3],
            normal and normal[1] or 0.0, normal and normal[2] or 1.0, normal and normal[3] or 0.0,
            hit and 1 or 0,
            impactLayer or "none"
        )
    end
    if isChargedRay then
        server.chargedRayVisualTrigger(context.weaponType, definition)
        local event = {
            eventType = "launch_start",
            incrementShotId = 1,
            slotIndex = context.mountIndex,
            weaponType = context.weaponType,
            firePoint = origin,
            hitPoint = endpoint,
            didHit = hit,
            didHitStellarisBody = hitRegisteredShip,
            didHitShield = didHitShield,
            hitTargetBodyId = hitBody,
            normal = normal,
            impactLayer = impactLayer,
        }
        if tostring(context.slotType or "") == "T"
            and server.tSlotRenderPushEvent ~= nil then
            server.tSlotRenderPushEvent(context.shipBodyId, event)
        elseif server.xSlotRenderPushEvent ~= nil then
            server.xSlotRenderPushEvent(context.shipBodyId, event)
        end
    end
    return true
end

server.weaponBehaviorRegister("raycast", { fire = _fireRaycast })

