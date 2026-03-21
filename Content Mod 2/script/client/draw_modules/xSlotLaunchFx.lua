-- x-slot launch beam fx module
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.xSlotLaunchFxState = client.xSlotLaunchFxState or {
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

local function _buildPerpBasis(forward)
    local upWorld = Vec(0, 1, 0)
    local right = VecCross(upWorld, forward)
    right = _safeNormalize(right, Vec(1, 0, 0))
    local up = VecCross(forward, right)
    up = _safeNormalize(up, Vec(0, 1, 0))
    return right, up
end

local function _resolveImpactColor(layer)
    local _ = layer
    -- Tachyon lance style: bright cyan-blue core.
    return 0.00, 0.00, 0.20
end

local function _xSlotLaunchFxStart(shipBodyId, firePointWorld, hitPointWorld, impactLayer)
    local beamVec = VecSub(hitPointWorld, firePointWorld)
    local beamLen = VecLength(beamVec)
    if beamLen < 0.001 then return end

    table.insert(client.xSlotLaunchFxState.activeEffects, {
        shipBodyId = shipBodyId,
        fire = firePointWorld,
        hit = hitPointWorld,
        age = 0,
        life = 0.24,
        width = 0.72,
        impactLayer = impactLayer or "none",
    })
end

function client.xSlotLaunchFxTick(dt)
    local state = client.xSlotLaunchFxState
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
                    if render.eventType == "launch_start" then
                        _xSlotLaunchFxStart(shipBodyId, _tableToVec(render.firePoint), _tableToVec(render.hitPoint), render.impactLayer)
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
        fx.age = fx.age + frameDt

        if fx.age >= fx.life then
            table.remove(effects, i)
        else
            local fire = fx.fire
            local hit = fx.hit
            local width = fx.width

            local beamVec = VecSub(hit, fire)
            local beamLen = VecLength(beamVec)
            local beamDir = VecScale(beamVec, 1.0 / math.max(beamLen, 0.001))
            local appearFrac = math.min(1.0, fx.age / 0.045)
            local fadeFrac = 1.0 - math.min(1.0, fx.age / fx.life)
            local pulse = 0.5 + 0.5 * math.sin(now * 55.0)
            local right, up = _buildPerpBasis(beamDir)

            local cr, cg, cb = _resolveImpactColor(fx.impactLayer)
            local glowScale = (0.80 + 0.55 * pulse) * appearFrac * (0.55 + 0.60 * fadeFrac)

            -- Multi-layer beam core: thicker, brighter, and more volumetric.
            DrawLine(fire, hit, width * 2.25 * appearFrac, cr * 0.40 * glowScale, cg * 0.55 * glowScale, cb * 0.70 * glowScale)
            DrawLine(fire, hit, width * 1.65 * appearFrac, cr * 0.80 * glowScale, cg * 1.00 * glowScale, cb * 1.00 * glowScale)
            DrawLine(fire, hit, width * 1.15 * appearFrac, cr * 1.00 * glowScale, cg * 1.00 * glowScale, cb * 1.00 * glowScale)
            DrawLine(fire, hit, width * 0.72 * appearFrac, cr * 0.20 * glowScale, cg * 1.00 * glowScale, cb * 1.00 * glowScale)
            DrawLine(fire, hit, width * 0.34 * appearFrac, cr * 0.35 * glowScale, cg * 1.00 * glowScale, cb * 1.00 * glowScale)

            -- Peripheral electric strands around beam body.
            local strandRadius = (0.20 + 0.10 * pulse) * appearFrac
            for j = 1, 8 do
                local a = (j / 8.0) * math.pi * 2.0 + now * 3.2
                local off = VecAdd(VecScale(right, math.cos(a) * strandRadius), VecScale(up, math.sin(a) * strandRadius))
                DrawLine(
                    VecAdd(fire, off),
                    VecAdd(hit, off),
                    width * 0.20 * appearFrac,
                    cr * 0.95 * glowScale,
                    cg * 1.00 * glowScale,
                    cb * 1.00 * glowScale
                )
            end

            -- High-density forward sparks rushing along the beam.
            ParticleReset()
            ParticleColor(cr, cg, cb, cr, cg, cb)
            ParticleRadius(0.11 * appearFrac, 0.025 * appearFrac, "easeout")
            ParticleAlpha(0.95 * appearFrac, 0.0)
            ParticleGravity(0.0)
            ParticleDrag(0.06)
            ParticleEmissive(28.0 * glowScale, 0.0)
            ParticleCollide(0.0)
            for _ = 1, 20 do
                local frac = math.random()
                local along = VecAdd(fire, VecScale(beamDir, beamLen * frac))
                local angle = now * 2.6 + math.random() * math.pi * 2
                local ringR = strandRadius + width * (0.20 + 0.35 * math.random())
                local offset = VecAdd(
                    VecScale(right, math.cos(angle) * ringR),
                    VecScale(up, math.sin(angle) * ringR)
                )
                local p = VecAdd(along, offset)
                local sideDir = _safeNormalize(offset, right)
                local vel = VecAdd(
                    VecScale(beamDir, (34.0 + 20.0 * math.random()) * appearFrac),
                    VecScale(sideDir, (4.0 + 4.0 * math.random()) * appearFrac)
                )
                SpawnParticle(p, vel, (0.16 + 0.10 * math.random()) * (0.5 + 0.5 * fadeFrac))
            end

            -- Soft glow dust hugging the beam for bloom feeling.
            ParticleReset()
            ParticleColor(cr, cg, cb, cr, cg, cb)
            ParticleRadius(0.18 * appearFrac, 0.03 * appearFrac, "easeout")
            ParticleAlpha(0.6 * appearFrac, 0.0)
            ParticleGravity(0.0)
            ParticleDrag(0.18)
            ParticleEmissive(14.0 * glowScale, 0.0)
            ParticleCollide(0.0)
            for _ = 1, 14 do
                local frac = math.random()
                local along = VecAdd(fire, VecScale(beamDir, beamLen * frac))
                local a = math.random() * math.pi * 2
                local rr = strandRadius * (0.5 + 1.1 * math.random())
                local offset = VecAdd(VecScale(right, math.cos(a) * rr), VecScale(up, math.sin(a) * rr))
                local p = VecAdd(along, offset)
                SpawnParticle(p, VecScale(offset, 0.8 + 1.6 * math.random()), 0.10 + 0.08 * math.random())
            end

            -- Muzzle / beam body / impact lights to sell beam power.
            PointLight(fire, cr, cg, cb, (12.0 + 8.0 * pulse) * appearFrac)
            PointLight(hit, cr, cg, cb, (9.0 + 7.0 * pulse) * appearFrac)
            local mid = VecAdd(fire, VecScale(beamVec, 0.55))
            PointLight(mid, cr * 0.75, cg * 0.92, cb, (6.0 + 4.0 * pulse) * appearFrac)
        end

        i = i - 1
    end
end
