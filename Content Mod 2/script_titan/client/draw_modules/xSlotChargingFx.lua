-- x-slot charging fx module
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.xSlotChargingFxState = client.xSlotChargingFxState or {
    chargeStateByShip = {},
    lastRenderSeqByShip = {},
    lastShotIdByShip = {},
    debugByShip = {},
}

local function _tableToVec(t)
    if t == nil then return Vec(0, 0, 0) end
    return Vec(t.x or 0, t.y or 0, t.z or 0)
end

local function _clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function _safeNormalize(v, fallback)
    local len = VecLength(v)
    if len < 0.0001 then
        return fallback or Vec(0, 0, -1)
    end
    return VecScale(v, 1.0 / len)
end

local function _resolveWeaponSettings(weaponType)
    local defs = weaponData or {}
    return defs[weaponType or ""] or defs.infernalRay or defs.tachyonLance or {}
end

local function _vecToDebugString(v)
    if v == nil then
        return "nil"
    end
    local x = tonumber(v[1] or v.x) or 0.0
    local y = tonumber(v[2] or v.y) or 0.0
    local z = tonumber(v[3] or v.z) or 0.0
    return string.format("(%.2f, %.2f, %.2f)", x, y, z)
end

local function _debugWatchCharging(shipBodyId, nowTime)
    if DebugWatch == nil then
        return
    end

    local controlledBody = 0
    if client.shipCameraGetControlledBody ~= nil then
        controlledBody = client.shipCameraGetControlledBody() or 0
    end
    if controlledBody == 0 then
        controlledBody = client.shipBody or 0
    end
    if shipBodyId ~= controlledBody or shipBodyId == 0 then
        return
    end

    local render = client.xSlotRenderGetEvent ~= nil and client.xSlotRenderGetEvent(shipBodyId) or nil
    local chargeState = client.xSlotChargingFxState.chargeStateByShip[shipBodyId]
    local debugState = client.xSlotChargingFxState.debugByShip[shipBodyId] or {}

    local renderEvent = render ~= nil and tostring(render.eventType or "nil") or "nil"
    local renderWeapon = render ~= nil and tostring(render.weaponType or "nil") or "nil"
    local renderSeq = render ~= nil and math.floor(render.seq or -1) or -1
    local renderFireWorld = render ~= nil and _tableToVec(render.firePoint) or nil
    local phase = chargeState ~= nil and tostring(chargeState.phase or "nil") or "nil"
    local intensity = chargeState ~= nil and _resolveChargeIntensity(chargeState, nowTime) or 0.0
    local fireLocal = chargeState ~= nil and chargeState.fireLocal or nil
    local muzzleWorld = nil
    if chargeState ~= nil then
        local shipT = GetBodyTransform(shipBodyId)
        muzzleWorld = TransformToParentPoint(shipT, chargeState.fireLocal or Vec(0, 0, 0))
    end

    debugState.lastRenderEvent = renderEvent
    debugState.lastRenderWeapon = renderWeapon
    debugState.lastRenderSeq = renderSeq
    debugState.phase = phase
    debugState.intensity = intensity
    debugState.fireLocal = fireLocal
    debugState.renderFireWorld = renderFireWorld
    debugState.muzzleWorld = muzzleWorld
    client.xSlotChargingFxState.debugByShip[shipBodyId] = debugState

    DebugWatch("TitanCharge.body", tostring(shipBodyId))
    DebugWatch("TitanCharge.renderSeq", tostring(renderSeq))
    DebugWatch("TitanCharge.renderEvent", renderEvent)
    DebugWatch("TitanCharge.renderWeapon", renderWeapon)
    DebugWatch("TitanCharge.hasState", chargeState ~= nil and "yes" or "no")
    DebugWatch("TitanCharge.phase", phase)
    DebugWatch("TitanCharge.intensity", string.format("%.3f", intensity))
    DebugWatch("TitanCharge.fireLocal", _vecToDebugString(fireLocal))
    DebugWatch("TitanCharge.renderFireWorld", _vecToDebugString(renderFireWorld))
    DebugWatch("TitanCharge.muzzleWorld", _vecToDebugString(muzzleWorld))
end

local function _clearChargeState(shipBodyId)
    client.xSlotChargingFxState.chargeStateByShip[shipBodyId] = nil
end

local function _beginInfernalChargeState(shipBodyId, render)
    local shipT = GetBodyTransform(shipBodyId)
    local fireWorld = _tableToVec(render.firePoint)
    local fireLocal = TransformToLocalPoint(shipT, fireWorld)
    client.xSlotChargingFxState.chargeStateByShip[shipBodyId] = {
        weaponType = tostring(render.weaponType or ""),
        slotIndex = math.floor(render.slotIndex or 1),
        phase = "charging",
        fireLocal = fireLocal,
        chargeStartedAt = (GetTime ~= nil) and GetTime() or 0.0,
        phaseStartedAt = (GetTime ~= nil) and GetTime() or 0.0,
        decayStartedAt = 0.0,
        decayStartIntensity = 0.0,
    }
end

local function _resolveChargeIntensity(chargeState, nowTime)
    local state = chargeState or {}
    local weaponSettings = _resolveWeaponSettings(state.weaponType)
    local chargeDuration = math.max(0.0001, tonumber(weaponSettings.chargeDuration) or 1.0)
    local decayDuration = math.max(0.0001, tonumber(weaponSettings.chargeDecayDuration) or chargeDuration)
    local phase = tostring(state.phase or "idle")

    if phase == "charging" then
        return _clamp(((nowTime or 0.0) - (state.chargeStartedAt or nowTime or 0.0)) / chargeDuration, 0.0, 1.0)
    end
    if phase == "charged" then
        return 1.0
    end
    if phase == "decaying" then
        local t = _clamp(((nowTime or 0.0) - (state.decayStartedAt or nowTime or 0.0)) / decayDuration, 0.0, 1.0)
        return _clamp((state.decayStartIntensity or 0.0) * (1.0 - t), 0.0, 1.0)
    end

    return 0.0
end

local function _markInfernalCharged(shipBodyId)
    local chargeState = client.xSlotChargingFxState.chargeStateByShip[shipBodyId]
    if chargeState == nil then
        return
    end
    chargeState.phase = "charged"
    chargeState.phaseStartedAt = (GetTime ~= nil) and GetTime() or 0.0
    chargeState.decayStartedAt = 0.0
    chargeState.decayStartIntensity = 1.0
end

local function _beginInfernalDecay(shipBodyId)
    local chargeState = client.xSlotChargingFxState.chargeStateByShip[shipBodyId]
    if chargeState == nil then
        return
    end
    local nowTime = (GetTime ~= nil) and GetTime() or 0.0
    chargeState.decayStartIntensity = _resolveChargeIntensity(chargeState, nowTime)
    chargeState.phase = "decaying"
    chargeState.decayStartedAt = nowTime
    chargeState.phaseStartedAt = nowTime
end

local function _spawnInfernalChargeParticle(sourceWorld, targetWorld, intensity, hotBias)
    local dir = VecSub(targetWorld, sourceWorld)
    local dist = VecLength(dir)
    if dist < 0.0001 then
        return
    end

    local toTarget = VecScale(dir, 1.0 / dist)
    local speed = (8.0 + 13.0 * hotBias) * (0.82 + 0.62 * intensity)
    local life = 0.22 + 0.18 * (1.0 - intensity * 0.35)

    ParticleReset()
    ParticleColor(
        1.00, 0.98 - 0.12 * hotBias, 0.92 - 0.20 * hotBias,
        1.00, 0.44 + 0.18 * hotBias, 0.04
    )
    ParticleRadius(0.12 + 0.12 * intensity + 0.05 * hotBias, 0.016, "easeout")
    ParticleAlpha(0.96, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.08)
    ParticleEmissive(28.0 + 44.0 * intensity + 18.0 * hotBias, 0.0)
    ParticleCollide(0.0)
    SpawnParticle(sourceWorld, VecScale(toTarget, speed), life)
end

local function _spawnInfernalBarrelGlow(targetWorld, barrelDir, intensity)
    ParticleReset()
    ParticleColor(1.00, 0.94, 0.78, 1.00, 0.56, 0.12)
    ParticleRadius(0.38 + 0.56 * intensity, 0.0, "easeout")
    ParticleAlpha(0.18 + 0.34 * intensity, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.02)
    ParticleEmissive(22.0 + 44.0 * intensity, 0.0)
    ParticleCollide(0.0)
    SpawnParticle(targetWorld, VecScale(barrelDir, 0.3 + 0.7 * intensity), 0.10 + 0.12 * intensity)
end

local function _spawnInfernalOuterCorona(targetWorld, intensity)
    ParticleReset()
    ParticleColor(1.0, 0.92, 0.36, 0.94, 0.12, 0.02)
    ParticleRadius(0.40 + 0.70 * intensity, 0.0, "easeout")
    ParticleAlpha(0.16 + 0.24 * intensity, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.01)
    ParticleEmissive(18.0 + 34.0 * intensity, 0.0)
    ParticleCollide(0.0)
    SpawnParticle(targetWorld, Vec(0, 0, 0), 0.08 + 0.10 * intensity)
end

local function _spawnInfernalAnchorCore(anchorWorld, barrelDir, intensity)
    PointLight(anchorWorld, 1.0, 0.92, 0.34, 5.2 + 9.5 * intensity)

    for _ = 1, math.max(4, math.floor(5 + intensity * 6)) do
        local jitter = Vec(
            (math.random() - 0.5) * (0.10 + 0.08 * intensity),
            (math.random() - 0.5) * (0.10 + 0.08 * intensity),
            (math.random() - 0.5) * (0.16 + 0.10 * intensity)
        )
        local pos = VecAdd(anchorWorld, jitter)
        ParticleReset()
        ParticleColor(1.0, 0.99, 0.95, 1.0, 0.74, 0.18)
        ParticleRadius(0.34 + 0.28 * intensity, 0.0, "easeout")
        ParticleAlpha(0.44 + 0.26 * intensity, 0.0)
        ParticleGravity(0.0)
        ParticleDrag(0.01)
        ParticleEmissive(42.0 + 36.0 * intensity, 0.0)
        ParticleCollide(0.0)
        SpawnParticle(pos, VecScale(barrelDir, 0.22 + 0.55 * intensity), 0.08 + 0.08 * intensity)
    end
end

local function _sampleInfernalChargeTargetLocal(fireLocal, innerLength, verticalSpread)
    return VecAdd(
        fireLocal,
        Vec(
            (math.random() - 0.5) * 0.05,
            (math.random() - 0.5) * (verticalSpread * 0.35),
            math.random() * innerLength
        )
    )
end

local function _sampleInfernalChargeSourceLocal(fireLocal, sideOffset, frontOffset, outerRadius, verticalSpread)
    local angle = (math.random() - 0.5) * math.rad(220.0)
    local lateralRadius = sideOffset + math.random() * outerRadius
    local forwardDepth = frontOffset + math.random() * (0.40 + outerRadius * 0.40)
    local x = math.sin(angle) * lateralRadius
    local z = -math.cos(angle) * forwardDepth
    local y = (math.random() - 0.5) * (verticalSpread * 0.85 + outerRadius * 0.16)
    return VecAdd(fireLocal, Vec(x, y, z))
end

local function _spawnInfernalChargeFx(shipBodyId, chargeState, intensity, frameDt)
    if intensity <= 0.001 then
        return
    end

    local shipT = GetBodyTransform(shipBodyId)
    local weaponSettings = _resolveWeaponSettings(chargeState.weaponType)
    local barrelLength = tonumber(weaponSettings.chargeFxBarrelLength) or 7.0
    local innerLength = tonumber(weaponSettings.chargeFxInnerLength) or 2.1
    local sideOffset = tonumber(weaponSettings.chargeFxSideOffset) or 1.15
    local frontOffset = tonumber(weaponSettings.chargeFxFrontOffset) or 2.4
    local verticalSpread = tonumber(weaponSettings.chargeFxVerticalSpread) or 0.45
    local outerRadius = tonumber(weaponSettings.chargeFxOuterRadius) or 2.8
    local particleScale = tonumber(weaponSettings.chargeFxParticleScale) or 1.65
    local glowScale = tonumber(weaponSettings.chargeFxGlowScale) or 2.1

    local fireLocal = chargeState.fireLocal or Vec(0, 0, 0)
    local barrelCount = math.max(14, math.floor((18.0 + 42.0 * intensity) * math.max(0.68, (frameDt or 0.016) * 60.0)))
    local barrelDir = _safeNormalize(TransformToParentVec(shipT, Vec(0, 0, -1)), Vec(0, 0, -1))
    local nowLight = (2.8 + 8.8 * intensity) * glowScale
    local muzzleWorld = TransformToParentPoint(shipT, fireLocal)
    local barrelMidWorld = TransformToParentPoint(shipT, VecAdd(fireLocal, Vec(0, 0, barrelLength * 0.35)))
    local barrelRearWorld = TransformToParentPoint(shipT, VecAdd(fireLocal, Vec(0, 0, barrelLength * 0.75)))

    _spawnInfernalAnchorCore(muzzleWorld, barrelDir, intensity)
    PointLight(muzzleWorld, 1.0, 0.75, 0.16, nowLight)
    PointLight(barrelMidWorld, 1.0, 0.36 + 0.20 * intensity, 0.08, nowLight * 0.85)
    PointLight(barrelRearWorld, 1.0, 0.18 + 0.16 * intensity, 0.05, nowLight * 0.55)

    for _ = 1, barrelCount do
        local targetLocal = _sampleInfernalChargeTargetLocal(fireLocal, innerLength, verticalSpread)
        local sourceLocal = _sampleInfernalChargeSourceLocal(fireLocal, sideOffset, frontOffset, outerRadius, verticalSpread)

        local sourceWorld = TransformToParentPoint(shipT, sourceLocal)
        local targetWorld = TransformToParentPoint(shipT, targetLocal)
        local hotBias = _clamp(intensity * 0.75 + math.random() * 0.35, 0.0, 1.2)
        local burstCount = math.max(1, math.floor(particleScale))
        if math.random() < (particleScale - math.floor(particleScale)) then
            burstCount = burstCount + 1
        end
        for _ = 1, burstCount do
            _spawnInfernalChargeParticle(sourceWorld, targetWorld, intensity, hotBias)
        end

        if math.random() < (0.44 + 0.46 * intensity) then
            _spawnInfernalBarrelGlow(targetWorld, barrelDir, intensity)
        end
        if math.random() < (0.26 + 0.38 * intensity) then
            _spawnInfernalOuterCorona(targetWorld, intensity)
        end
    end

    if intensity > 0.65 then
        local flareCount = math.max(4, math.floor(5 + intensity * 7))
        for _ = 1, flareCount do
            local flareLocal = VecAdd(fireLocal, Vec((math.random() - 0.5) * 0.16, (math.random() - 0.5) * 0.18, math.random() * 0.60))
            local flareWorld = TransformToParentPoint(shipT, flareLocal)
            ParticleReset()
            ParticleColor(1.0, 0.99, 0.95, 1.0, 0.72, 0.20)
            ParticleRadius(0.34 + math.random() * 0.26 + intensity * 0.18, 0.0, "easeout")
            ParticleAlpha(0.40 + intensity * 0.18, 0.0)
            ParticleGravity(0.0)
            ParticleDrag(0.01)
            ParticleEmissive(38.0 + 34.0 * intensity, 0.0)
            ParticleCollide(0.0)
            SpawnParticle(flareWorld, VecScale(barrelDir, 0.3 + math.random() * 0.8), 0.08 + math.random() * 0.08)
        end
    end
end

function client.xSlotChargingFxTick(dt)
    local state = client.xSlotChargingFxState
    local frameDt = dt or 0.0
    local nowTime = (GetTime ~= nil) and GetTime() or 0.0

    local shipIds = client.registryShipGetRegisteredBodyIds()
    for i = 1, #shipIds do
        local shipBodyId = shipIds[i]
        if client.registryShipExists(shipBodyId) then
            local render = client.xSlotRenderGetEvent(shipBodyId)
            if render ~= nil then
                local seq = render.seq or -1
                local shotId = render.shotId or -1
                local lastSeq = state.lastRenderSeqByShip[shipBodyId] or -1

                if seq ~= lastSeq then
                    if render.weaponType == "infernalRay" then
                        if render.eventType == "charging_start" then
                            _beginInfernalChargeState(shipBodyId, render)
                        elseif render.eventType == "charged_hold" then
                            _markInfernalCharged(shipBodyId)
                        elseif render.eventType == "decaying_start" then
                            _beginInfernalDecay(shipBodyId)
                        else
                            _clearChargeState(shipBodyId)
                        end
                    else
                        _clearChargeState(shipBodyId)
                    end

                    state.lastRenderSeqByShip[shipBodyId] = seq
                    state.lastShotIdByShip[shipBodyId] = shotId
                end
            end
        else
            _clearChargeState(shipBodyId)
        end
    end

    for shipBodyId, chargeState in pairs(state.chargeStateByShip) do
        if not client.registryShipExists(shipBodyId) then
            state.chargeStateByShip[shipBodyId] = nil
        else
            local intensity = _resolveChargeIntensity(chargeState, nowTime)
            local phase = tostring((chargeState or {}).phase or "idle")
            if phase == "decaying" and intensity <= 0.001 then
                state.chargeStateByShip[shipBodyId] = nil
            else
                _spawnInfernalChargeFx(shipBodyId, chargeState, intensity, frameDt)
            end
        end
    end

    local debugBody = 0
    if client.shipCameraGetControlledBody ~= nil then
        debugBody = client.shipCameraGetControlledBody() or 0
    end
    if debugBody == 0 then
        debugBody = client.shipBody or 0
    end
    _debugWatchCharging(debugBody, nowTime)
end
