---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local _hSlotV2LegacyFireBeam = server.hSlotV2FireBeam

local function _hSlotV2FireSetting(config, name, fallback)
    local weaponType = tostring((config or {}).weaponType or "gammaStrikeCraft")
    local source = (hSlotWeaponRegistryData or {})[weaponType]
        or (hSlotWeaponRegistryData or {}).gammaStrikeCraft
        or {}
    return tonumber(source[name]) or tonumber((config or {})[name]) or fallback
end

local function _hSlotV2ResolvePhysicalFirePose(craft, targetCenter, config)
    if craft == nil or craft.bodyId == nil or craft.bodyId == 0
        or not IsHandleValid(craft.bodyId) or targetCenter == nil then
        return nil, nil, nil, nil, nil
    end

    local bodyTransform = GetBodyTransform(craft.bodyId)
    local bodyForward = server.hSlotV2Normalize(
        TransformToParentVec(bodyTransform, Vec(0, 0, -1)),
        craft.forward or Vec(0, 0, -1)
    )
    local muzzleOffset = math.max(
        0.1, _hSlotV2FireSetting(config, "muzzleForwardOffset", 1.2)
    )
    local origin = VecAdd(bodyTransform.pos, VecScale(bodyForward, muzzleOffset))
    local toTarget = VecSub(targetCenter, origin)
    local distance = VecLength(toTarget)
    if distance <= 0.0001 then
        return nil, nil, nil, nil, bodyForward
    end

    local direction = VecScale(toTarget, 1.0 / distance)
    return origin, direction, distance, VecDot(bodyForward, direction), bodyForward
end

local function _hSlotV2MuzzlePathClear(shipBody, craft, origin, direction, config)
    local safeDistance = math.max(
        0.1, _hSlotV2FireSetting(config, "beamSelfSafeDistance", 3.0)
    )
    QueryRequire("physical")
    QueryRejectBody(shipBody)
    QueryRejectBody(craft.bodyId)
    local hit = QueryRaycast(origin, direction, safeDistance, 0.05)
    return not hit
end

function server.hSlotV2UpdateBeam(shipBody, craft, targetCenter, config, dt)
    if craft == nil or craft.bodyId == nil or craft.bodyId == 0
        or not IsHandleValid(craft.bodyId) or targetCenter == nil then
        return
    end

    craft.fireRemain = (craft.fireRemain or 0.0) - (dt or 0.0)
    local origin, direction, distance, alignment, bodyForward =
        _hSlotV2ResolvePhysicalFirePose(craft, targetCenter, config)
    local minimumAlignment = server.hSlotV2Clamp(
        _hSlotV2FireSetting(config, "fireAlignmentDot", 0.90), -1.0, 1.0
    )
    if origin == nil or direction == nil or distance == nil
        or alignment == nil or alignment < minimumAlignment
        or distance > math.max(1.0, tonumber(config.maxRange) or 160.0)
        or craft.fireRemain > 0.0 then
        return
    end
    if not _hSlotV2MuzzlePathClear(
        shipBody, craft, origin, direction, config
    ) then
        return
    end

    local previousForward = craft.forward
    local previousPosition = craft.pos
    craft.forward = bodyForward
    craft.pos = GetBodyTransform(craft.bodyId).pos
    _hSlotV2LegacyFireBeam(shipBody, craft, targetCenter, config)
    craft.forward = previousForward
    craft.pos = previousPosition
    craft.fireRemain = math.max(
        0.02, tonumber(config.fireInterval) or 0.22
    )
end
