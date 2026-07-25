---@diagnostic disable: undefined-global

server = server or {}

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

    local _, didHitShield = server.weaponDamageApplyToShip(hitBody, context.weaponType)
    if hit and not didHitShield then
        local explosionSize = math.max(0.0, tonumber(definition.environmentExplosionSize) or 0.0)
        if explosionSize > 0.0 then Explosion(endpoint, explosionSize) end
    end
    ClientCall(
        0, "client.spawnGenericRaycastWeaponFx",
        context.weaponType, tostring(definition.fxProfile or "energyBeam"),
        origin[1], origin[2], origin[3],
        endpoint[1], endpoint[2], endpoint[3],
        normal and normal[1] or 0.0, normal and normal[2] or 1.0, normal and normal[3] or 0.0
    )
    return true
end

server.weaponBehaviorRegister("raycast", { fire = _fireRaycast })

