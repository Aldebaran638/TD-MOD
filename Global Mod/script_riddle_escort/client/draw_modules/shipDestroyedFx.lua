---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.shipDestroyedFxState = client.shipDestroyedFxState or {
    lastBodyHp = nil,
    exploded = false,
    sphereFx = {},
    ringFx = {},
}

local function _randomUnitVec()
    local z = 2.0 * math.random() - 1.0
    local a = math.random() * math.pi * 2.0
    local r = math.sqrt(math.max(0.0, 1.0 - z * z))
    return Vec(r * math.cos(a), z, r * math.sin(a))
end

local function _getBodyCenterWorld(body)
    local t = GetBodyTransform(body)
    local comLocal = GetBodyCenterOfMass(body)
    return TransformToParentPoint(t, comLocal)
end

local function _startDestroyedFx(center)
    local state = client.shipDestroyedFxState

    state.sphereFx[#state.sphereFx + 1] = {
        center = center,
        age = 0.0,
        life = 1.4,
        maxRadius = 7.2,
    }

    state.ringFx[#state.ringFx + 1] = {
        center = center,
        age = 0.0,
        life = 2.3,
        r0 = 2.0,
        r1 = 18.5,
    }
end

local function _tickSphereFx(dt)
    local list = client.shipDestroyedFxState.sphereFx
    local i = #list
    while i >= 1 do
        local fx = list[i]
        fx.age = fx.age + dt
        if fx.age >= fx.life then
            table.remove(list, i)
        else
            local t = fx.age / fx.life
            local radius = fx.maxRadius * t
            local alpha = math.pow(1.0 - t, 0.58)

            PointLight(fx.center, 1.0, 0.95, 0.74, 15.0 * alpha)
            PointLight(fx.center, 1.0, 0.88, 0.52, 11.0 * alpha)

            ParticleReset()
            ParticleColor(1.0, 0.98, 0.78, 1.0, 0.90, 0.55)
            ParticleRadius(0.68, 0.16, "easeout")
            ParticleAlpha(0.98 * alpha, 0.0)
            ParticleGravity(0.0)
            ParticleDrag(0.04)
            ParticleEmissive(42.0 * alpha, 0.0)
            ParticleCollide(0.0)

            for _ = 1, 84 do
                local dir = _randomUnitVec()
                local jitter = 0.25 + 0.35 * math.random()
                local pos = VecAdd(fx.center, VecScale(dir, radius * jitter))
                local speed = 8.0 + 12.0 * (1.0 - t) + 8.0 * math.random()
                local vel = VecScale(dir, speed)
                SpawnParticle(pos, vel, 0.65 + 0.45 * math.random())
            end
        end
        i = i - 1
    end
end

local function _tickRingFx(dt)
    local list = client.shipDestroyedFxState.ringFx
    local i = #list
    while i >= 1 do
        local fx = list[i]
        fx.age = fx.age + dt
        if fx.age >= fx.life then
            table.remove(list, i)
        else
            local t = fx.age / fx.life
            local r = fx.r0 + (fx.r1 - fx.r0) * t
            local alpha = math.pow(1.0 - t, 0.62)

            PointLight(fx.center, 1.0, 1.0, 1.0, 7.0 * alpha)

            ParticleReset()
            ParticleColor(1.0, 1.0, 1.0, 0.86, 0.90, 1.0)
            ParticleRadius(0.36, 0.12, "easeout")
            ParticleAlpha(0.9 * alpha, 0.0)
            ParticleGravity(0.0)
            ParticleDrag(0.08)
            ParticleEmissive(30.0 * alpha, 0.0)
            ParticleCollide(0.0)

            local count = 96
            for k = 1, count do
                local a = (k / count) * math.pi * 2.0 + math.random() * 0.08
                local cs = math.cos(a)
                local sn = math.sin(a)
                local pos = Vec(
                    fx.center[1] + cs * r,
                    fx.center[2] + (math.random() - 0.5) * 0.18,
                    fx.center[3] + sn * r
                )
                local dir = Vec(cs, 0, sn)
                local vel = VecScale(dir, 12.0 + 7.0 * (1.0 - t) + 5.0 * math.random())
                SpawnParticle(pos, vel, 0.5 + 0.35 * math.random())
            end
        end
        i = i - 1
    end
end

function client.shipDestroyedFxTick(dt)
    local state = client.shipDestroyedFxState
    local body = client.shipBody or 0
    local frameDt = dt or 0

    if body ~= 0 and client.registryShipExists ~= nil and client.registryShipExists(body) then
        local _, _, bodyHP = client.registryShipGetHP(body)
        if bodyHP ~= nil then
            local currBodyHp = tonumber(bodyHP) or 0.0
            local prevBodyHp = state.lastBodyHp

            if (not state.exploded) and currBodyHp <= 0.0 and (prevBodyHp == nil or prevBodyHp > 0.0) then
                local center = _getBodyCenterWorld(body)
                _startDestroyedFx(center)
                state.exploded = true
            end

            state.lastBodyHp = currBodyHp
        end
    end

    _tickSphereFx(frameDt)
    _tickRingFx(frameDt)
end
