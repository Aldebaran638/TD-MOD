---@diagnostic disable: undefined-global

-- Shared direct-ray query and shield endpoint handling.  Behaviours own their
-- damage and world-effect policies, while this module keeps hit geometry alike.
server = server or {}

local function _raySphereEntryDistance(origin, direction, center, radius)
    local offset = VecSub(origin, center)
    local b = VecDot(offset, direction)
    local c = VecDot(offset, offset) - radius * radius
    local discriminant = b * b - c
    if discriminant < 0.0 then return nil end
    local distance = -b - math.sqrt(discriminant)
    if distance < 0.0 then distance = -b + math.sqrt(discriminant) end
    return distance >= 0.0 and distance or nil
end

function server.weaponRaycastResolveShieldEndpoint(origin, direction, bodyId, maximumDistance)
    if server.registryShipGetShieldRadius == nil then return nil, nil end
    local radius = math.max(0.0, tonumber(server.registryShipGetShieldRadius(
        bodyId, server.shipContextGetType()
    )) or 0.0)
    if radius <= 0.0 then return nil, nil end
    local bodyTransform = GetBodyTransform(bodyId)
    local center = TransformToParentPoint(bodyTransform, GetBodyCenterOfMass(bodyId))
    local distance = _raySphereEntryDistance(origin, direction, center, radius)
    if distance == nil or distance > maximumDistance then return nil, nil end
    local point = VecAdd(origin, VecScale(direction, distance))
    return point, server.weaponBehaviorNormalize(VecSub(point, center), Vec(0, 1, 0))
end

function server.weaponRaycastResolve(context)
    local definition = context.weaponDefinition or {}
    local origin, direction = server.weaponBehaviorResolveFireTransform(context)
    local range = math.max(1.0, tonumber(definition.maxRange) or 500.0)
    QueryRequire("physical")
    QueryRejectBody(context.shipBodyId)
    local hit, distance, normal, shape = QueryRaycast(origin, direction, range)
    local endpoint = VecAdd(origin, VecScale(direction, hit and distance or range))
    local hitBody = 0
    if shape ~= nil and shape ~= 0 then hitBody = GetShapeBody(shape) or 0 end
    if hitBody == context.shipBodyId then
        hit, hitBody, normal = false, 0, direction
        endpoint = VecAdd(origin, VecScale(direction, range))
    end
    local hitRegisteredShip = hitBody ~= 0
        and server.registryShipExists ~= nil
        and server.registryShipExists(hitBody)
    return {
        origin = origin, direction = direction, range = range, hit = hit,
        distance = hit and distance or range, normal = normal or direction, shape = shape,
        endpoint = endpoint, hitBody = hitBody, hitRegisteredShip = hitRegisteredShip,
    }
end

function server.weaponRaycastApplyShieldEndpoint(ray, didHitShield)
    if didHitShield ~= true or ray.hitBody == 0 then return ray.endpoint, ray.normal end
    local endpoint, normal = server.weaponRaycastResolveShieldEndpoint(
        ray.origin, ray.direction, ray.hitBody, ray.distance
    )
    if endpoint ~= nil then
        ray.endpoint, ray.normal = endpoint, normal
    end
    return ray.endpoint, ray.normal
end
