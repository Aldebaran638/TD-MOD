---@diagnostic disable: undefined-global

-- Port of the original Titan impact: expanding layered explosions plus a shockwave.
client = client or {}
client.perditionLaunchFxState = client.perditionLaunchFxState or { lastSeq = {}, effects = {} }

function client.perditionLaunchFxInit()
    client.perditionLaunchFxState = { lastSeq = {}, effects = {} }
end

function client.perditionLaunchFxTick(dt)
    local state, delta = client.perditionLaunchFxState, math.max(0, tonumber(dt) or 0)
    for _, shipBody in ipairs(client.registryShipGetRegisteredBodyIds()) do
        local event = client.tSlotRenderGetEvent(shipBody)
        if event and state.lastSeq[shipBody] ~= event.seq then
            state.lastSeq[shipBody] = event.seq
            if event.weaponType == "perditionBeam" and event.eventType == "launch_start" then
                state.effects[#state.effects + 1] = { center = Vec(event.hitPoint.x, event.hitPoint.y, event.hitPoint.z), age = 0, wave = 0 }
            end
        end
    end
    for i = #state.effects, 1, -1 do
        local fx = state.effects[i]; fx.age = fx.age + delta
        local expected = math.min(20, math.floor(fx.age / .4) + 1)
        while fx.wave < expected do
            fx.wave = fx.wave + 1
            local radius, count = fx.wave * 10, 12 + (fx.wave - 1) * 8
            for layer = 0, 14 do for n = 1, count do
                local a = n / count * math.pi * 2
                local p = Vec(fx.center[1] + math.cos(a) * radius, fx.center[2] + layer * 3, fx.center[3] + math.sin(a) * radius)
                ParticleReset(); ParticleColor(1, .9, .7, 1, .5, .2); ParticleRadius(.5, 1.5, "easeout"); ParticleAlpha(1, 0); ParticleGravity(0); ParticleDrag(.1); ParticleEmissive(50, 0); ParticleCollide(0)
                SpawnParticle(p, VecScale(Vec(math.cos(a), .5, math.sin(a)), 20 + math.random() * 30), .5 + math.random() * .5)
            end end
        end
        local t, r = math.min(1, fx.age / 1.15), 1 + 8.25 * math.min(1, fx.age / 1.15)
        PointLight(fx.center, 1, 1, 1, 175 * (1 - t) ^ .62)
        -- Original Titan shockwave density: deliberately not subject to generic
        -- weapon-FX budgeting, otherwise this signature effect disappears.
        ParticleReset(); ParticleColor(1, 1, 1, .86, .9, 1); ParticleRadius(.36, .12, "easeout"); ParticleAlpha(.9 * (1 - t), 0); ParticleGravity(0); ParticleDrag(.08); ParticleEmissive(30 * (1 - t), 0); ParticleCollide(0)
        for n = 1, 2400 do local a = n / 2400 * math.pi * 2; SpawnParticle(Vec(fx.center[1] + math.cos(a) * r, fx.center[2], fx.center[3] + math.sin(a) * r), Vec(math.cos(a) * 750, 0, math.sin(a) * 750), .125) end
        if fx.wave >= 20 and fx.age >= 1.15 then table.remove(state.effects, i) end
    end
end
