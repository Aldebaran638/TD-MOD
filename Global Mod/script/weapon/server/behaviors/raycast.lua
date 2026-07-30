---@diagnostic disable: undefined-global

server = server or {}

local function _raySphereEntryDistance(origin, direction, center, radius)
    local offset = VecSub(origin, center)
    local b = VecDot(offset, direction)
    local c = VecDot(offset, offset) - radius * radius
    local discriminant = b * b - c
    if discriminant < 0.0 then return nil end
    local distance = -b - math.sqrt(discriminant)
    if distance < 0.0 then
        distance = -b + math.sqrt(discriminant)
    end
    if distance < 0.0 then return nil end
    return distance
end

local function _resolveShieldEndpoint(origin, direction, bodyId, maximumDistance)
    if server.registryShipGetShieldRadius == nil then return nil, nil end
    local radius = math.max(
        0.0,
        tonumber(server.registryShipGetShieldRadius(
            bodyId,
            server.shipContextGetType()
        )) or 0.0
    )
    if radius <= 0.0 then return nil, nil end
    local bodyTransform = GetBodyTransform(bodyId)
    local center = TransformToParentPoint(bodyTransform, GetBodyCenterOfMass(bodyId))
    local distance = _raySphereEntryDistance(origin, direction, center, radius)
    if distance == nil or distance > maximumDistance then return nil, nil end
    local point = VecAdd(origin, VecScale(direction, distance))
    return point, server.weaponBehaviorNormalize(VecSub(point, center), Vec(0, 1, 0))
end

local function _fireRaycast(context)
    local definition = context.weaponDefinition or {}
    local origin, direction = server.weaponBehaviorResolveFireTransform(context)
    local range = math.max(1.0, tonumber(definition.maxRange) or 500.0)
    QueryRequire("physical")
    QueryRejectBody(context.shipBodyId)
    local hit, distance, normal, shape = QueryRaycast(origin, direction, range)
    local endpoint = VecAdd(origin, VecScale(direction, hit and distance or range))
    local hitBody = 0
    if shape ~= nil and shape ~= 0 then hitBody = GetShapeBody(shape) or 0 end
    -- 直射武器绝不可命中发射船自身；QueryRejectBody 是第一层，
    -- 此处保留命中结算层的兜底，避免异常查询结果造成自伤。
    if hitBody == context.shipBodyId then
        hit = false
        hitBody = 0
        normal = direction
        endpoint = VecAdd(origin, VecScale(direction, range))
    end

    local _, didHitShield, impactLayer = server.weaponDamageApplyToShip(hitBody, context.weaponType)
    local hitRegisteredShip = hitBody ~= 0
        and server.registryShipExists ~= nil
        and server.registryShipExists(hitBody)
    local suppressPhysicalExplosion = definition.suppressShipExplosion == true
        and hitRegisteredShip
    if didHitShield then
        local shieldEndpoint, shieldNormal = _resolveShieldEndpoint(
            origin,
            direction,
            hitBody,
            hit and distance or range
        )
        if shieldEndpoint ~= nil then
            endpoint = shieldEndpoint
            normal = shieldNormal
        end
        ClientCall(
            0,
            "client.playProjectileShieldImpactFx",
            hitBody,
            endpoint[1], endpoint[2], endpoint[3],
            context.weaponType
        )
    end
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
    ClientCall(
        0, "client.spawnGenericRaycastWeaponFx",
        context.weaponType, tostring(definition.fxProfile or "energyBeam"),
        origin[1], origin[2], origin[3],
        endpoint[1], endpoint[2], endpoint[3],
        normal and normal[1] or 0.0, normal and normal[2] or 1.0, normal and normal[3] or 0.0,
        hit and 1 or 0,
        impactLayer or "none"
    )
    return true
end

server.weaponBehaviorRegister("raycast", { fire = _fireRaycast })

