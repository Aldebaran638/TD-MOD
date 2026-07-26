---@diagnostic disable: undefined-global

server = server or {}

function server.weaponBehaviorNormalize(value, fallback)
    local length = VecLength(value)
    if length < 0.0001 then return fallback or Vec(0, 0, -1) end
    return VecScale(value, 1.0 / length)
end

function server.weaponBehaviorClampAimLocal(direction, aimLimitDeg)
    local forward = Vec(0, 0, -1)
    local desired = server.weaponBehaviorNormalize(direction, forward)
    local maximum = math.max(0.0, tonumber(aimLimitDeg) or 0.0)
    if maximum <= 0.0001 then return forward end

    local dot = math.max(-1.0, math.min(1.0, VecDot(desired, forward)))
    local angle = math.deg(math.acos(dot))
    if angle <= maximum then return desired end

    local lateral = server.weaponBehaviorNormalize(
        VecSub(desired, VecScale(forward, dot)),
        Vec(1, 0, 0)
    )
    local radians = math.rad(maximum)
    return server.weaponBehaviorNormalize(
        VecAdd(VecScale(forward, math.cos(radians)), VecScale(lateral, math.sin(radians))),
        forward
    )
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
    local usesCameraAim = tostring(weapon.aimControlMode or "") == "camera_limited"
    if weapon.forceForward and not usesCameraAim then
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

    if weapon.forceForward and not usesCameraAim then return origin, direction end

    local usedCameraAim = false
    if server.shipRuntimeGetWeaponAim ~= nil then
        local active, yaw, pitch = server.shipRuntimeGetWeaponAim(context.shipBodyId)
        if active and usesCameraAim then
            local yr = math.rad(tonumber(yaw) or 0.0)
            local pr = math.rad(tonumber(pitch) or 0.0)
            local localAim = Vec(math.cos(pr) * math.sin(yr), math.sin(pr), -math.cos(pr) * math.cos(yr))
            localAim = server.weaponBehaviorClampAimLocal(localAim, weapon.aimLimitDeg)
            direction = server.weaponBehaviorNormalize(TransformToParentVec(shipTransform, localAim), direction)
            usedCameraAim = true
        end
    end
    if not usedCameraAim then
        local targetBody = math.floor(context.targetBodyId or 0)
        if targetBody ~= 0 and IsHandleValid(targetBody) then
            local targetTransform = GetBodyTransform(targetBody)
            local targetCenter = TransformToParentPoint(targetTransform, GetBodyCenterOfMass(targetBody))
            direction = server.weaponBehaviorNormalize(VecSub(targetCenter, origin), direction)
        end
    end
    -- Direct-fire weapons use the ship-centre aim ray as a parallax reference.
    -- When the crosshair ray reaches nearby geometry, every muzzle converges on
    -- that exact point instead of firing parallel through it. Guided ordnance
    -- and strike craft simply do not opt into this data-driven flag.
    if weapon.closeRangeFocus == true then
        local focusRange = math.min(
            math.max(1.0, tonumber(weapon.maxRange) or 500.0),
            math.max(1.0, tonumber(weapon.closeRangeFocusRange) or 220.0)
        )
        local focusOrigin = TransformToParentPoint(shipTransform, Vec(0, 0, -2))
        QueryRequire("physical")
        QueryRejectBody(context.shipBodyId)
        local hit, distance = QueryRaycast(focusOrigin, direction, focusRange)
        if hit then
            local point = VecAdd(focusOrigin, VecScale(direction, distance))
            direction = server.weaponBehaviorNormalize(VecSub(point, origin), direction)
        end
    end
    return origin, direction
end

