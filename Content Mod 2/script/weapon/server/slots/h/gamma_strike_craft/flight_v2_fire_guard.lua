---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

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

local function _hSlotV2ShapeIsStrikeCraft(shape)
    if shape == nil or shape == 0 or HasTag == nil then return false end
    return HasTag(shape, "strikeCraft")
        or HasTag(shape, "strikeCraftWing")
        or HasTag(shape, "strikeCraftEngine")
        or HasTag(shape, "stellarisStrikeCraft")
end

local function _hSlotV2IsFriendlyCraftBody(craftBody, hitBody)
    local body = math.floor(hitBody or 0)
    if body == 0 then return false end
    if body == math.floor(craftBody or 0) then return true end

    local state = server.hSlotState or {}
    for _, otherCraft in pairs(state.activeCrafts or {}) do
        if otherCraft ~= nil and body == math.floor(otherCraft.bodyId or 0) then
            return true
        end
    end
    return false
end

local function _hSlotV2BlockOwnShot(shipBody, craft, reason, hitBody, hitShape)
    craft.lastFireBlockedReason = tostring(reason or "unknown")
    craft.lastFireBlockedBody = math.floor(hitBody or 0)
    craft.lastFireBlockedShape = math.floor(hitShape or 0)
    if server.hSlotV2SetDebugReason ~= nil then
        server.hSlotV2SetDebugReason(craft.slotIndex or 0, reason, craft)
    end
    if server.hSlotV2BumpCounter ~= nil then
        server.hSlotV2BumpCounter(shipBody, reason)
    end
end

local function _hSlotV2FullPathAllowsFire(
    shipBody, craft, origin, direction, maximumDistance
)
    if math.floor(craft.targetBodyId or 0) == math.floor(craft.bodyId or 0) then
        _hSlotV2BlockOwnShot(
            shipBody, craft, "beam_block_self_target", craft.bodyId, 0
        )
        return false
    end

    QueryRequire("physical")
    QueryRejectBody(shipBody)
    QueryRejectBody(craft.bodyId)
    local hit, _, _, shape = QueryRaycast(
        origin,
        direction,
        math.max(0.1, tonumber(maximumDistance) or 0.1),
        0.05
    )
    if not hit then return true end

    local hitBody = shape ~= nil and shape ~= 0 and GetShapeBody(shape) or 0
    if _hSlotV2IsFriendlyCraftBody(craft.bodyId, hitBody) then
        _hSlotV2BlockOwnShot(
            shipBody, craft, "beam_block_friendly_craft_body", hitBody, shape
        )
        return false
    end
    if _hSlotV2ShapeIsStrikeCraft(shape) then
        _hSlotV2BlockOwnShot(
            shipBody, craft, "beam_block_strike_craft_vox", hitBody, shape
        )
        return false
    end
    return true
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
    local maximumRange = math.max(1.0, tonumber(config.maxRange) or 160.0)
    if origin == nil or direction == nil or distance == nil
        or alignment == nil or alignment < minimumAlignment
        or distance > maximumRange
        or craft.fireRemain > 0.0 then
        return
    end
    if not _hSlotV2FullPathAllowsFire(
        shipBody, craft, origin, direction, maximumRange
    ) then
        return
    end

    local previousForward = craft.forward
    local previousPosition = craft.pos
    craft.forward = bodyForward
    craft.pos = GetBodyTransform(craft.bodyId).pos
    server.hSlotV2FireBeam(shipBody, craft, targetCenter, config)
    craft.forward = previousForward
    craft.pos = previousPosition
    craft.fireRemain = math.max(
        0.02, tonumber(config.fireInterval) or 0.22
    )
end
