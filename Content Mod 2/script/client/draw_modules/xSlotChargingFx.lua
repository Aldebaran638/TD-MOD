-- x-slot charging fx module
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.xSlotChargingFxState = client.xSlotChargingFxState or {
    activeEffects = {},
    lastRenderSeqByShip = {},
    lastShotIdByShip = {},
}

local function _tableToVec(t)
    if t == nil then return Vec(0, 0, 0) end
    return Vec(t.x or 0, t.y or 0, t.z or 0)
end

local function _clearEffectsByShip(shipBodyId)
    local effects = client.xSlotChargingFxState.activeEffects
    local i = #effects
    while i >= 1 do
        if effects[i].shipBodyId == shipBodyId then
            table.remove(effects, i)
        end
        i = i - 1
    end
end

local function _spawnChargingEntry(shipBodyId, shipT, targetLocalPos, radiusScale)
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

    table.insert(client.xSlotChargingFxState.activeEffects, {
        shipBodyId = shipBodyId,
        spawnLocalPos = spawnLocalPos,
        targetLocalPos = targetLocalPos,
        age = 0,
        life = 0.52 + 0.22 * math.random(),
        radius = 0.056 + 0.035 * math.random(),
        speed = 7.0 + 4.5 * math.random(),
    })
end

local function _startChargingBurst(shipBodyId, firePointWorld)
    local shipT = GetBodyTransform(shipBodyId)
    local targetLocalPos = TransformToLocalPoint(shipT, firePointWorld)

    -- simplified: one medium burst, no continuous emitter, less stutter
    for _ = 1, 30 do
        _spawnChargingEntry(shipBodyId, shipT, targetLocalPos, 1.25)
    end
end

function client.xSlotChargingFxTick(dt)
    local state = client.xSlotChargingFxState
    local frameDt = dt or 0

    local shipIds = client.registryShipGetRegisteredBodyIds()
    for i = 1, #shipIds do
        local shipBodyId = shipIds[i]
        if client.registryShipExists(shipBodyId) then
            local snapshot = client.registryShipGetSnapshot(shipBodyId)
            if snapshot ~= nil then
                local render = snapshot.xSlotsRender or {}
                local seq = render.seq or -1
                local shotId = render.shotId or -1
                local lastSeq = state.lastRenderSeqByShip[shipBodyId] or -1

                if seq ~= lastSeq then
                    if render.eventType == "charging_start" then
                        _clearEffectsByShip(shipBodyId)
                        _startChargingBurst(shipBodyId, _tableToVec(render.firePoint))
                    else
                        _clearEffectsByShip(shipBodyId)
                    end

                    state.lastRenderSeqByShip[shipBodyId] = seq
                    state.lastShotIdByShip[shipBodyId] = shotId
                end
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
            ParticleColor(0.96, 1.0, 1.0, 0.16, 0.45, 1.0)
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
