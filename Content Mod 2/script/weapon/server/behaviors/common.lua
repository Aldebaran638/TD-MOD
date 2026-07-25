---@diagnostic disable: undefined-global

server = server or {}

function server.weaponBehaviorNormalize(value, fallback)
    local length = VecLength(value)
    if length < 0.0001 then return fallback or Vec(0, 0, -1) end
    return VecScale(value, 1.0 / length)
end

function server.weaponBehaviorResolveFireTransform(context)
    local mount = context.mountDefinition or {}
    local weapon = context.weaponDefinition or {}
    local offset = mount.firePosOffset or {}
    local relative = mount.fireDirRelative or {}
    local shipTransform = GetBodyTransform(context.shipBodyId)
    local origin = TransformToParentPoint(shipTransform, Vec(
        tonumber(offset.x) or 0.0,
        tonumber(offset.y) or 0.0,
        tonumber(offset.z) or 0.0
    ))
    local direction = server.weaponBehaviorNormalize(
        TransformToParentVec(shipTransform, Vec(
            tonumber(relative.x) or 0.0,
            tonumber(relative.y) or 0.0,
            tonumber(relative.z) or -1.0
        )),
        Vec(0, 0, -1)
    )
    if weapon.forceForward then
        direction = server.weaponBehaviorNormalize(
            TransformToParentVec(shipTransform, Vec(0, 0, -1)),
            direction
        )
    end

    if tostring(weapon.aimControlMode or "") == "forward_converge" then
        local forward = server.weaponBehaviorNormalize(
            TransformToParentVec(shipTransform, Vec(0, 0, -1)),
            direction
        )
        local rayOrigin = TransformToParentPoint(shipTransform, Vec(0, 0, -2))
        local range = math.max(1.0, tonumber(weapon.maxRange) or 500.0)
        QueryRequire("physical")
        QueryRejectBody(context.shipBodyId)
        local hit, distance = QueryRaycast(rayOrigin, forward, range)
        if hit then
            local aimPoint = VecAdd(rayOrigin, VecScale(forward, distance))
            direction = server.weaponBehaviorNormalize(VecSub(aimPoint, origin), forward)
        else
            direction = forward
        end
        return origin, direction
    end

    if weapon.forceForward then return origin, direction end

    local targetBody = math.floor(context.targetBodyId or 0)
    if targetBody ~= 0 and IsHandleValid(targetBody) then
        local targetTransform = GetBodyTransform(targetBody)
        local targetCenter = TransformToParentPoint(targetTransform, GetBodyCenterOfMass(targetBody))
        direction = server.weaponBehaviorNormalize(VecSub(targetCenter, origin), direction)
    elseif server.shipRuntimeGetWeaponAim ~= nil then
        local active, yaw, pitch = server.shipRuntimeGetWeaponAim(context.shipBodyId)
        if active then
            local yr = math.rad(tonumber(yaw) or 0.0)
            local pr = math.rad(tonumber(pitch) or 0.0)
            local localAim = Vec(math.cos(pr) * math.sin(yr), math.sin(pr), -math.cos(pr) * math.cos(yr))
            direction = server.weaponBehaviorNormalize(TransformToParentVec(shipTransform, localAim), direction)
        end
    end
    return origin, direction
end

