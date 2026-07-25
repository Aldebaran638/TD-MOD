-- Tachyon lance charging effect.
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.tachyonChargingFxConfig = client.tachyonChargingFxConfig or {
    emissionRate = 72.0,
    maxSpawnPerFrame = 6,
}

client.tachyonChargingFxState = client.tachyonChargingFxState or {
    activeEffects = {},
    emittersByShip = {},
    lastRenderSeqByShip = {},
}

local function _tableToVec(t)
    if t == nil then return Vec(0, 0, 0) end
    return Vec(t.x or 0, t.y or 0, t.z or 0)
end

local function _clearEffectsByShip(shipBodyId)
    local effects = client.tachyonChargingFxState.activeEffects
    local i = #effects
    while i >= 1 do
        if effects[i].shipBodyId == shipBodyId then
            table.remove(effects, i)
        end
        i = i - 1
    end
end

local function _spawnChargingEntry(shipBodyId, shipT, targetLocalPos, radiusScale, weaponType)
    local scale = radiusScale or 1.0
    local fxRadius = 3.0 * scale

    local theta = math.random() * math.pi * 2.0
    local phi = math.acos(2.0 * math.random() - 1.0)
    local r = (0.30 + 0.70 * math.random()) * fxRadius

    local dx = r * math.sin(phi) * math.cos(theta)
    local dy = r * math.sin(phi) * math.sin(theta)
    local dz = r * math.cos(phi)

    local spawnWorld = TransformToParentPoint(shipT, VecAdd(targetLocalPos, Vec(dx, dy, dz)))
    local spawnLocalPos = TransformToLocalPoint(shipT, spawnWorld)

    table.insert(client.tachyonChargingFxState.activeEffects, {
        shipBodyId = shipBodyId,
        spawnLocalPos = spawnLocalPos,
        targetLocalPos = targetLocalPos,
        age = 0,
        life = 0.52 + 0.22 * math.random(),
        radius = 0.056 + 0.035 * math.random(),
        speed = 7.0 + 4.5 * math.random(),
        weaponType = tostring(weaponType or "tachyonLance"),
    })
end

local function _startOrUpdateChargingEmitter(shipBodyId, firePointWorld, weaponType)
    local shipT = GetBodyTransform(shipBodyId)
    local targetLocalPos = TransformToLocalPoint(shipT, firePointWorld)
    local emitters = client.tachyonChargingFxState.emittersByShip
    local emitter = emitters[shipBodyId]
    if emitter == nil then
        emitter = {
            accumulator = 0.0,
            targetLocalPos = targetLocalPos,
            weaponType = tostring(weaponType or "tachyonLance"),
        }
        emitters[shipBodyId] = emitter
    else
        emitter.targetLocalPos = targetLocalPos
        emitter.weaponType = tostring(weaponType or "tachyonLance")
    end
end

function client.tachyonChargingFxTick(dt)
    local state = client.tachyonChargingFxState
    local config = client.tachyonChargingFxConfig
    local frameDt = dt or 0

    local shipIds = client.registryShipGetRegisteredBodyIds()
    for i = 1, #shipIds do
        local shipBodyId = shipIds[i]
        if client.registryShipExists(shipBodyId) then
            local render = client.xSlotRenderGetEvent(shipBodyId)
            if render ~= nil then
                local seq = render.seq or -1
                local lastSeq = state.lastRenderSeqByShip[shipBodyId] or -1

                if seq ~= lastSeq then
                    if render.eventType == "charging_start" then
                        _startOrUpdateChargingEmitter(
                            shipBodyId,
                            _tableToVec(render.firePoint),
                            render.weaponType
                        )
                    else
                        state.emittersByShip[shipBodyId] = nil
                    end

                    state.lastRenderSeqByShip[shipBodyId] = seq
                end
            end
        else
            state.emittersByShip[shipBodyId] = nil
            _clearEffectsByShip(shipBodyId)
        end
    end

    for shipBodyId, emitter in pairs(state.emittersByShip) do
        if not client.registryShipExists(shipBodyId) then
            state.emittersByShip[shipBodyId] = nil
            _clearEffectsByShip(shipBodyId)
        else
            local shipT = GetBodyTransform(shipBodyId)
            emitter.accumulator = (emitter.accumulator or 0.0)
                + math.max(0.0, frameDt) * math.max(0.0, tonumber(config.emissionRate) or 72.0)
            local spawnCount = math.min(
                math.floor(emitter.accumulator),
                math.max(1, math.floor(tonumber(config.maxSpawnPerFrame) or 6))
            )
            emitter.accumulator = emitter.accumulator - spawnCount
            for _ = 1, spawnCount do
                _spawnChargingEntry(
                    shipBodyId,
                    shipT,
                    emitter.targetLocalPos,
                    1.25,
                    emitter.weaponType
                )
            end
        end
    end

    local shipTransformCache = {}
    local effects = state.activeEffects
    local i = #effects
    while i >= 1 do
        local entry = effects[i]
        entry.age = entry.age + frameDt

        if entry.age >= entry.life then
            table.remove(effects, i)
        elseif not client.registryShipExists(entry.shipBodyId) then
            table.remove(effects, i)
        else
            local shipT = shipTransformCache[entry.shipBodyId]
            if shipT == nil then
                shipT = GetBodyTransform(entry.shipBodyId)
                shipTransformCache[entry.shipBodyId] = shipT
            end

            local spawnPos = TransformToParentPoint(shipT, entry.spawnLocalPos)
            local targetPos = TransformToParentPoint(shipT, entry.targetLocalPos)

            local rawT = math.min(1.0, entry.age / entry.life)
            local t = math.pow(rawT, 1.18)

            local dir = VecSub(targetPos, spawnPos)
            local cur = VecAdd(spawnPos, VecScale(dir, t))

            local toTarget = VecSub(targetPos, cur)
            local toTargetLen = VecLength(toTarget)
            local vel = Vec(0, 0, 0)
            if toTargetLen > 0.0001 then
                vel = VecScale(toTarget, entry.speed / toTargetLen)
            end

            local pulse = 0.70 + 0.30 * (1.0 - rawT)

            ParticleReset()
            if entry.weaponType == "focusedArcEmitter" then
                ParticleColor(0.82, 0.24, 1.0, 0.46, 0.08, 0.78)
            else
                ParticleColor(0.96, 1.0, 1.0, 0.16, 0.45, 1.0)
            end
            ParticleRadius(entry.radius, 0.014, "easeout")
            ParticleAlpha(0.86, 0.0)
            ParticleGravity(0.0)
            ParticleDrag(0.10)
            ParticleEmissive(12.0 * pulse, 0.0)
            ParticleCollide(0.0)
            SpawnParticle(cur, vel, entry.life - entry.age)
        end

        i = i - 1
    end
end
