-- Focused Arc Emitter charging effect.
-- Uses the three XML muzzle lights as energy nodes and draws restrained
-- electrical bridges between the side nodes and the central emitter.
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.focusedArcChargingFxConfig = client.focusedArcChargingFxConfig or {
    chargeDuration = 0.50,
    sideOffset = 2.5,
    sideForwardOffset = 0.60,
    segmentCount = 7,
}

client.focusedArcChargingFxState = client.focusedArcChargingFxState or {
    emittersByShip = {},
    lastRenderSeqByShip = {},
    sprite = 0,
}

local function _focusedArcTableToVec(value)
    if value == nil then return Vec(0, 0, 0) end
    return Vec(value.x or 0, value.y or 0, value.z or 0)
end

local function _focusedArcNormalize(value, fallback)
    local length = VecLength(value)
    if length < 0.0001 then return fallback or Vec(0, 1, 0) end
    return VecScale(value, 1.0 / length)
end

local function _focusedArcCameraAxis(direction, center)
    local toCamera = VecSub(GetCameraTransform().pos, center)
    local projected = VecSub(toCamera, VecScale(direction, VecDot(toCamera, direction)))
    return _focusedArcNormalize(projected, Vec(0, 1, 0))
end

local function _focusedArcStartOrUpdate(shipBodyId, firePointWorld)
    local shipT = GetBodyTransform(shipBodyId)
    local targetLocalPos = TransformToLocalPoint(shipT, firePointWorld)
    local emitter = client.focusedArcChargingFxState.emittersByShip[shipBodyId]
    if emitter == nil then
        emitter = {
            age = 0.0,
            targetLocalPos = targetLocalPos,
        }
        client.focusedArcChargingFxState.emittersByShip[shipBodyId] = emitter
    else
        emitter.targetLocalPos = targetLocalPos
    end
end

local function _focusedArcDrawBridge(sprite, startPos, endPos, age, seed, strength)
    local vector = VecSub(endPos, startPos)
    local length = VecLength(vector)
    if length < 0.001 then return end

    local direction = VecScale(vector, 1.0 / length)
    local center = VecLerp(startPos, endPos, 0.5)
    local axisA = _focusedArcCameraAxis(direction, center)
    local axisB = _focusedArcNormalize(VecCross(direction, axisA), Vec(0, 0, 1))
    local segmentCount = math.max(
        4,
        math.floor(tonumber(client.focusedArcChargingFxConfig.segmentCount) or 7)
    )
    local previous = startPos
    local flicker = 0.88
        + 0.08 * math.sin(age * 33.0 + seed * 1.7)
        + 0.04 * math.sin(age * 71.0 + seed * 3.1)

    for segmentIndex = 1, segmentCount do
        local t = segmentIndex / segmentCount
        local point = VecLerp(startPos, endPos, t)
        if segmentIndex < segmentCount then
            local envelope = math.sin(math.pi * t)
            local jitterA = math.sin(age * 54.0 + seed + segmentIndex * 2.13)
                * 0.085 * envelope
            local jitterB = math.cos(age * 67.0 + seed * 0.7 + segmentIndex * 1.61)
                * 0.055 * envelope
            point = VecAdd(
                point,
                VecAdd(VecScale(axisA, jitterA), VecScale(axisB, jitterB))
            )
        end

        local segment = VecSub(point, previous)
        local segmentLength = VecLength(segment)
        if segmentLength > 0.001 then
            local segmentDirection = VecScale(segment, 1.0 / segmentLength)
            local segmentCenter = VecLerp(previous, point, 0.5)
            local transform = Transform(
                segmentCenter,
                QuatAlignXZ(
                    segmentDirection,
                    _focusedArcCameraAxis(segmentDirection, segmentCenter)
                )
            )
            local alpha = math.max(0.0, strength * flicker)
            DrawSprite(
                sprite,
                transform,
                segmentLength,
                0.48,
                1.15,
                0.32,
                1.8,
                alpha * 0.58,
                true,
                true,
                false
            )
            DrawSprite(
                sprite,
                transform,
                segmentLength,
                0.095,
                4.5,
                2.2,
                6.0,
                math.min(1.0, alpha),
                true,
                true,
                false
            )
        end
        previous = point
    end
end

function client.focusedArcChargingFxInit()
    client.focusedArcChargingFxState = {
        emittersByShip = {},
        lastRenderSeqByShip = {},
        sprite = LoadSprite("MOD/gfx/weapons/tachyon_lance/beam_soft.png"),
    }
end

function client.focusedArcChargingFxTick(dt)
    local state = client.focusedArcChargingFxState
    local frameDt = math.max(0.0, tonumber(dt) or 0.0)
    local shipIds = client.registryShipGetRegisteredBodyIds()

    for i = 1, #shipIds do
        local shipBodyId = shipIds[i]
        if client.registryShipExists(shipBodyId) then
            local render = client.xSlotRenderGetEvent(shipBodyId)
            if render ~= nil then
                local isArcCharging = render.eventType == "charging_start"
                    and tostring(render.weaponType or "") == "focusedArcEmitter"
                if isArcCharging then
                    _focusedArcStartOrUpdate(
                        shipBodyId,
                        _focusedArcTableToVec(render.firePoint)
                    )
                else
                    state.emittersByShip[shipBodyId] = nil
                end
                state.lastRenderSeqByShip[shipBodyId] = render.seq or -1
            end
        else
            state.emittersByShip[shipBodyId] = nil
            state.lastRenderSeqByShip[shipBodyId] = nil
        end
    end

    for shipBodyId, emitter in pairs(state.emittersByShip) do
        if client.registryShipExists(shipBodyId) then
            emitter.age = (emitter.age or 0.0) + frameDt
        else
            state.emittersByShip[shipBodyId] = nil
        end
    end
end

function client.focusedArcChargingFxRender()
    local state = client.focusedArcChargingFxState
    local sprite = math.floor(state.sprite or 0)
    if sprite == 0 then return end

    local config = client.focusedArcChargingFxConfig
    local chargeDuration = math.max(0.001, tonumber(config.chargeDuration) or 0.50)
    local sideOffset = tonumber(config.sideOffset) or 2.5
    local sideForwardOffset = tonumber(config.sideForwardOffset) or 0.60

    for shipBodyId, emitter in pairs(state.emittersByShip) do
        if client.registryShipExists(shipBodyId) then
            local shipT = GetBodyTransform(shipBodyId)
            local centerLocal = emitter.targetLocalPos
            local leftLocal = VecAdd(centerLocal, Vec(-sideOffset, 0, sideForwardOffset))
            local rightLocal = VecAdd(centerLocal, Vec(sideOffset, 0, sideForwardOffset))
            local centerWorld = TransformToParentPoint(shipT, centerLocal)
            local leftWorld = TransformToParentPoint(shipT, leftLocal)
            local rightWorld = TransformToParentPoint(shipT, rightLocal)
            local charge = math.max(0.0, math.min(1.0, (emitter.age or 0.0) / chargeDuration))
            local strength = charge * charge
            if charge >= 1.0 then
                strength = math.min(
                    1.35,
                    1.0
                        + 0.18 * math.max(0.0, math.sin((emitter.age or 0.0) * 47.0))
                        + 0.17 * math.max(0.0, math.sin((emitter.age or 0.0) * 91.0))
                )
            end
            _focusedArcDrawBridge(sprite, leftWorld, centerWorld, emitter.age or 0.0, 1.0, strength)
            _focusedArcDrawBridge(sprite, rightWorld, centerWorld, emitter.age or 0.0, 4.0, strength)
        end
    end
end
