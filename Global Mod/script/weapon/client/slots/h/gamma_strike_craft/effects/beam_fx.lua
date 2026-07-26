---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.hSlotBeamFxState = client.hSlotBeamFxState or { beams = {} }

function client.spawnHSlotLaunchFx(x, y, z, dx, dy, dz)
    local pos, dir = Vec(x or 0, y or 0, z or 0), VecNormalize(Vec(dx or 0, dy or 0, dz or -1))
    if client.weaponFxTakeParticles(16, "normal") then
        ParticleReset(); ParticleType("plain"); ParticleColor(1.0, 0.55, 0.16, 0.10, 0.02, 0.01); ParticleRadius(0.14, 0.01, "easeout"); ParticleAlpha(0.9, 0, "easeout"); ParticleGravity(0); ParticleDrag(0.15); ParticleEmissive(14, 0); ParticleCollide(0)
        for _ = 1, 16 do SpawnParticle(pos, VecAdd(VecScale(dir, -4 - math.random() * 6), Vec(math.random() - .5, math.random() - .5, math.random() - .5)), .18) end
    end
    client.weaponFxPointLight(pos, 1.0, .45, .12, 9)
end

function client.spawnHSlotBeamFx(sx, sy, sz, ex, ey, ez, didHitShield, life, width, impactLayer)
    local state = client.hSlotBeamFxState
    local profile = client.gammaLaserFxProfile("gammaStrikeCraft")
    local beamLife = math.max(0.01, tonumber(life) or profile.life)
    if #state.beams >= (client.weaponFxBudgetConfig.maxActiveBeams or 96) then table.remove(state.beams, 1) end
    local startPos = Vec(sx or 0, sy or 0, sz or 0)
    local endPos = Vec(ex or 0, ey or 0, ez or 0)
    table.insert(state.beams, { startPos = startPos, endPos = endPos, life = beamLife, maxLife = beamLife })
    client.spawnGammaLaserMuzzleFx("gammaStrikeCraft", startPos, VecSub(endPos, startPos))
    if math.floor(didHitShield or 0) ~= 0 or tostring(impactLayer or "none") ~= "none" then
        client.spawnGammaLaserImpactFx("gammaStrikeCraft", endPos, VecSub(startPos, endPos), impactLayer or (math.floor(didHitShield or 0) ~= 0 and "shield" or "body"))
    end
    local _ = width
end

function client.hSlotBeamFxTick(dt)
    local beams = client.hSlotBeamFxState.beams
    for index = #beams, 1, -1 do
        beams[index].life = beams[index].life - math.max(0, dt or 0)
        if beams[index].life <= 0 then table.remove(beams, index) end
    end
end

function client.hSlotBeamFxRender()
    local profile = client.gammaLaserFxProfile("gammaStrikeCraft")
    for _, beam in ipairs(client.hSlotBeamFxState.beams) do
        client.gammaLaserDrawBeam(beam.startPos, beam.endPos, profile, beam.maxLife - beam.life, beam.maxLife)
    end
end
