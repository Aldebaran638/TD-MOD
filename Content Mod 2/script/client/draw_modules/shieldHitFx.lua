---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.shieldHitFxState = client.shieldHitFxState or {
    activeEffects = {},
    lastRenderSeqByShip = {},
    lastShotIdByShip = {},
}

local function _tableToVec(t)
    if t == nil then return Vec(0, 0, 0) end
    return Vec(t.x or 0, t.y or 0, t.z or 0)
end

local function _safeNormalize(v, fallback)
    local l = VecLength(v)
    if l < 0.0001 then return fallback end
    return VecScale(v, 1.0 / l)
end

local function _buildPerpBasis(n)
    local upWorld = Vec(0, 1, 0)
    local t1 = VecCross(upWorld, n)
    t1 = _safeNormalize(t1, Vec(1, 0, 0))
    local t2 = VecCross(n, t1)
    t2 = _safeNormalize(t2, Vec(0, 1, 0))
    return t1, t2
end

local function _getShieldHitConfig(shipType)
    local defs = shipTypeRegistryData or {}
    local shipDef = defs[shipType or "enigmaticCruiser"] or defs.enigmaticCruiser or {}
    local shieldHit = (shipDef.fx and shipDef.fx.shieldHit) or {}

    return {
        ringParticleRadius = shieldHit.ringParticleRadius or 0.1,
        ringRadiusStep = shieldHit.ringRadiusStep or 1.0,
        ringRoundCount = shieldHit.ringRoundCount or 3,
        roundTime = shieldHit.roundTime or 0.14,
        centerSpawnRadius = shieldHit.centerSpawnRadius or 0.5,
        centerSpawnCount = shieldHit.centerSpawnCount or 20,
        baseParticleCount = shieldHit.baseParticleCount or 18,
    }
end

local function _shieldHitFxStart(shipBodyId, shipType, kind, hitTargetBodyId, hitPointWorld)
    if kind == "shield" then
        local cfg = _getShieldHitConfig(shipType)
        table.insert(client.shieldHitFxState.activeEffects, {
            shipBodyId = shipBodyId,
            shipType = shipType,
            kind = "shield",
            hitTargetBodyId = hitTargetBodyId,
            hitPoint = hitPointWorld,
            age = 0,
            life = math.max(0.0, cfg.ringRoundCount) * math.max(0.001, cfg.roundTime),
        })
    else
        table.insert(client.shieldHitFxState.activeEffects, {
            shipBodyId = shipBodyId,
            shipType = shipType,
            kind = "impact",
            hitPoint = hitPointWorld,
            age = 0,
            life = 0.35,
        })
    end
end

function client.shieldHitFxTick(dt)
    local state = client.shieldHitFxState

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
                    if render.eventType == "launch_start" and render.didHit == 1 then
                        local hitPoint = _tableToVec(render.hitPoint)
                        if render.didHitShield == 1 then
                            _shieldHitFxStart(shipBodyId, snapshot.shipType, "shield", render.hitTargetBodyId or 0, hitPoint)
                        else
                            _shieldHitFxStart(shipBodyId, snapshot.shipType, "impact", 0, hitPoint)
                        end
                    end
                    state.lastRenderSeqByShip[shipBodyId] = seq
                    state.lastShotIdByShip[shipBodyId] = shotId
                end
            end
        end
    end

    local effects = state.activeEffects
    local now = GetTime()
    local i = #effects
    while i >= 1 do
        local fx = effects[i]
        fx.age = fx.age + dt

        if fx.age >= fx.life then
            table.remove(effects, i)
        else
            if fx.kind == "impact" then
                local pulse = 0.5 + 0.5 * math.sin(now * 35.0)

                PointLight(fx.hitPoint, 1.0, 0.6, 0.2, 2.0 + 4.0 * pulse)
                ParticleReset()
                ParticleColor(1.0, 0.75, 0.25, 1.0, 0.3, 0.05)
                ParticleRadius(0.10, 0.02, "easeout")
                ParticleAlpha(0.9, 0.0)
                ParticleGravity(-2.0)
                ParticleDrag(0.2)
                ParticleEmissive(6.0, 0.0)
                ParticleCollide(0.0)
                for _ = 1, 8 do
                    local r = Vec(math.random() - 0.5, math.random() - 0.1, math.random() - 0.5)
                    local dir = _safeNormalize(r, Vec(0, 1, 0))
                    local vel = VecScale(dir, 6.0 + 8.0 * pulse)
                    SpawnParticle(fx.hitPoint, vel, 0.08 + 0.05 * pulse)
                end
            else
                local hitTarget = fx.hitTargetBodyId or 0
                if hitTarget == 0 or (IsHandleValid ~= nil and (not IsHandleValid(hitTarget))) then
                    table.remove(effects, i)
                else
                    local bodyT = GetBodyTransform(hitTarget)
                    local comLocal = GetBodyCenterOfMass(hitTarget)
                    local center = TransformToParentPoint(bodyT, comLocal)

                    local n = _safeNormalize(VecSub(fx.hitPoint, center), Vec(0, 1, 0))
                    local t1, t2 = _buildPerpBasis(n)

                    local cfg = _getShieldHitConfig(fx.shipType)
                    local ringParticleRadius = cfg.ringParticleRadius
                    local ringRadiusStep = cfg.ringRadiusStep
                    local ringRoundCount = cfg.ringRoundCount
                    local roundTime = cfg.roundTime
                    local centerSpawnRadius = cfg.centerSpawnRadius
                    local centerSpawnCount = cfg.centerSpawnCount
                    local baseParticleCount = cfg.baseParticleCount

                    local round = math.floor(fx.age / math.max(0.001, roundTime)) + 1
                    if round > ringRoundCount then
                        table.remove(effects, i)
                    else
                        for _ = 1, centerSpawnCount do
                            local dirRnd = _safeNormalize(Vec(math.random()-0.5, math.random()-0.5, math.random()-0.5), Vec(0, 1, 0))
                            local rr = math.random() * centerSpawnRadius
                            local p = VecAdd(fx.hitPoint, VecScale(dirRnd, rr))
                            local vel = VecScale(dirRnd, 1.5 * (0.5 + math.random()))

                            ParticleReset()
                            ParticleColor(1.0, 1.0, 1.0, 0.6, 1.0, 1.0)
                            ParticleRadius(ringParticleRadius * 0.9, ringParticleRadius * 0.5, "easeout")
                            ParticleAlpha(0.95, 0.0)
                            ParticleGravity(0.0)
                            ParticleDrag(0.1)
                            ParticleEmissive(18.0, 0.0)
                            ParticleCollide(0.0)
                            SpawnParticle(p, vel, roundTime)
                        end

                        local inner = math.max(0.0, (round - 1) * ringRadiusStep)
                        local outer = inner + math.max(0.01, ringRadiusStep * 1.2)
                        local ringCount = math.max(6, math.floor(baseParticleCount + (round - 1) * 4 + 0.5))
                        for _ = 1, ringCount do
                            local a = math.random() * math.pi * 2.0
                            local rr = inner + math.random() * (outer - inner)
                            local lateral = VecAdd(VecScale(t1, math.cos(a)), VecScale(t2, math.sin(a)))
                            local p = VecAdd(fx.hitPoint, VecScale(lateral, rr))
                            local vel = VecAdd(VecScale(lateral, 6.0 + 4.0 * math.random()), VecScale(n, 0.6 * (0.5 + math.random())))

                            ParticleReset()
                            ParticleColor(0.20, 0.95, 1.00, 0.10, 0.35, 1.00)
                            ParticleRadius(ringParticleRadius, ringParticleRadius * 0.5, "easeout")
                            ParticleAlpha(0.95, 0.0)
                            ParticleGravity(0.0)
                            ParticleDrag(0.05)
                            ParticleEmissive(18.0, 0.0)
                            ParticleCollide(0.0)
                            SpawnParticle(p, vel, roundTime)
                        end
                    end
                end
            end
        end
        i = i - 1
    end
end
