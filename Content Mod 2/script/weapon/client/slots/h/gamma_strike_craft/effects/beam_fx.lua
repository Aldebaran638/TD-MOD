---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.hSlotBeamFxState = client.hSlotBeamFxState or { beams = {}, portals = {} }

local _launchSfx = 0
local _recoverSfx = 0
local _portalGlowSprite = 0

local function _ensureStrikeSounds()
    if _launchSfx == 0 then _launchSfx = LoadSound("MOD/sound/strike_craft_launch_portal.wav") end
    if _recoverSfx == 0 then _recoverSfx = LoadSound("MOD/sound/strike_craft_recover_portal.wav") end
end

local function _ensurePortalSprite()
    if _portalGlowSprite == 0 then _portalGlowSprite = LoadSprite("MOD/gfx/weapons/projectiles/impact_glow.png") end
end

local function _perpAxes(dir)
    local ref = math.abs(dir[2]) < 0.85 and Vec(0, 1, 0) or Vec(1, 0, 0)
    local s = VecNormalize(VecCross(dir, ref))
    local u = VecNormalize(VecCross(s, dir))
    return s, u
end

function client.spawnHSlotLaunchFx(x, y, z, dx, dy, dz)
    local pos = Vec(x or 0, y or 0, z or 0)
    local dir = VecNormalize(Vec(dx or 0, dy or 0, dz or -1))
    _ensureStrikeSounds()
    _ensurePortalSprite()
    if _launchSfx ~= 0 then PlaySound(_launchSfx, pos, 1.3) end

    local side, up = _perpAxes(dir)

    -- Ring 1: radial shockwave perpendicular to launch axis
    if client.weaponFxTakeParticles(8, "normal") then
        ParticleReset(); ParticleType("plain")
        ParticleColor(1.6, 1.4, 2.8, 0.20, 0.30, 1.40)
        ParticleRadius(0.30, 0.01, "easeout"); ParticleAlpha(1.0, 0.0, "easeout")
        ParticleGravity(0); ParticleDrag(0.04); ParticleEmissive(26, 0); ParticleCollide(0)
        for i = 1, 8 do
            local a = (i / 8) * 2 * math.pi
            local radVel = VecAdd(VecScale(side, math.cos(a)), VecScale(up, math.sin(a)))
            SpawnParticle(pos, VecScale(radVel, 10 + math.random() * 8), 0.38)
        end
    end

    -- Ring 2: diagonal debris — radial + forward component
    if client.weaponFxTakeParticles(6, "normal") then
        ParticleReset(); ParticleType("plain")
        ParticleColor(0.50, 0.65, 2.20, 0.04, 0.08, 0.50)
        ParticleRadius(0.18, 0.01, "easeout"); ParticleAlpha(0.90, 0.0, "easeout")
        ParticleGravity(0); ParticleDrag(0.10); ParticleEmissive(18, 0)
        ParticleStretch(2.2, 0.2, "easeout"); ParticleCollide(0)
        for i = 1, 6 do
            local a = (i / 6) * 2 * math.pi
            local radVel = VecAdd(VecScale(side, math.cos(a)), VecScale(up, math.sin(a)))
            local vel = VecAdd(VecScale(radVel, 6 + math.random() * 5), VecScale(dir, 4 + math.random() * 6))
            SpawnParticle(pos, vel, 0.55)
        end
    end

    -- Scatter sparks
    if client.weaponFxTakeParticles(4, "normal") then
        ParticleReset(); ParticleType("plain")
        ParticleColor(2.2, 2.0, 3.0, 0.40, 0.40, 1.60)
        ParticleRadius(0.10, 0.005, "easeout"); ParticleAlpha(1.0, 0.0, "easeout")
        ParticleGravity(0); ParticleDrag(0.18); ParticleEmissive(35, 0); ParticleCollide(0)
        for _ = 1, 4 do
            local r = Vec(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
            SpawnParticle(pos, VecAdd(VecScale(r, 8), VecScale(dir, 3)), 0.28)
        end
    end

    client.weaponFxPointLight(pos, 0.80, 0.70, 2.20, 22)

    local portals = client.hSlotBeamFxState.portals
    if #portals >= 24 then table.remove(portals, 1) end
    table.insert(portals, { pos = pos, dir = dir, age = 0.0, totalLife = 0.55, kind = "launch" })
end

function client.spawnHSlotRecoverFx(x, y, z)
    local pos = Vec(x or 0, y or 0, z or 0)
    _ensureStrikeSounds()
    _ensurePortalSprite()
    if _recoverSfx ~= 0 then PlaySound(_recoverSfx, pos, 1.0) end

    -- Implosion ring: particles spawned around center, rushing inward
    if client.weaponFxTakeParticles(8, "normal") then
        ParticleReset(); ParticleType("plain")
        ParticleColor(1.00, 0.85, 2.50, 0.08, 0.12, 0.80)
        ParticleRadius(0.22, 0.01, "easeout"); ParticleAlpha(0.95, 0.0, "easeout")
        ParticleGravity(0); ParticleDrag(0.0); ParticleEmissive(20, 0); ParticleCollide(0)
        for i = 1, 8 do
            local a = (i / 8) * 2 * math.pi
            local r = 3.5 + math.random() * 1.2
            local off = Vec(math.cos(a) * r, (math.random() - 0.5) * 1.8, math.sin(a) * r)
            local spawnPos = VecAdd(pos, off)
            local toCenter = VecNormalize(VecSub(pos, spawnPos))
            SpawnParticle(spawnPos, VecScale(toCenter, 14 + math.random() * 7), 0.30)
        end
    end

    -- Collapse burst at center
    if client.weaponFxTakeParticles(4, "normal") then
        ParticleReset(); ParticleType("plain")
        ParticleColor(2.50, 2.20, 4.00, 0.50, 0.50, 1.80)
        ParticleRadius(0.16, 0.01, "easeout"); ParticleAlpha(1.0, 0.0, "easeout")
        ParticleGravity(0); ParticleDrag(0.28); ParticleEmissive(40, 0); ParticleCollide(0)
        for _ = 1, 4 do
            local r = Vec(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
            SpawnParticle(pos, VecScale(r, 3), 0.22)
        end
    end

    client.weaponFxPointLight(pos, 0.55, 0.50, 1.90, 16)

    local portals = client.hSlotBeamFxState.portals
    if #portals >= 24 then table.remove(portals, 1) end
    table.insert(portals, { pos = pos, dir = Vec(0, 1, 0), age = 0.0, totalLife = 0.50, kind = "recover" })
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
    local frameDt = math.max(0, dt or 0)

    local beams = client.hSlotBeamFxState.beams
    for index = #beams, 1, -1 do
        beams[index].life = beams[index].life - frameDt
        if beams[index].life <= 0 then table.remove(beams, index) end
    end

    local portals = client.hSlotBeamFxState.portals
    for index = #portals, 1, -1 do
        portals[index].age = portals[index].age + frameDt
        if portals[index].age >= portals[index].totalLife then table.remove(portals, index) end
    end
end

function client.hSlotBeamFxRender()
    local profile = client.gammaLaserFxProfile("gammaStrikeCraft")
    for _, beam in ipairs(client.hSlotBeamFxState.beams) do
        client.gammaLaserDrawBeam(beam.startPos, beam.endPos, profile, beam.maxLife - beam.life, beam.maxLife)
    end

    if _portalGlowSprite == 0 then return end
    local cameraPos = GetCameraTransform().pos
    for _, portal in ipairs(client.hSlotBeamFxState.portals) do
        local t = math.min(1.0, portal.age / portal.totalLife)
        local envelope
        if t < 0.10 then
            envelope = t / 0.10
        else
            envelope = ((1.0 - t) / 0.90) ^ 1.4
        end
        if envelope > 0.001 and client.weaponFxTakeSprite(3) then
            local sizeOuter, sizeMid, sizeCore
            local r1, g1, b1 = 0.30, 0.20, 1.00
            local r2, g2, b2 = 0.25, 0.55, 1.60
            local r3, g3, b3 = 1.80, 1.90, 3.20
            if portal.kind == "launch" then
                -- iris tears open: rift grows outward as the craft crosses through
                local growth = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)
                sizeOuter = 1.1 + growth * 2.3
                sizeMid = 0.7 + growth * 1.5
                sizeCore = 0.35 + growth * 0.75
            else
                -- iris collapses inward: rift starts wide and implodes shut
                local shrink = (1.0 - t) * (1.0 - t)
                sizeOuter = 1.1 + shrink * 2.3
                sizeMid = 0.7 + shrink * 1.5
                sizeCore = 0.35 + shrink * 0.75
                r1, g1, b1 = 0.55, 0.20, 1.30
                r2, g2, b2 = 0.65, 0.30, 1.90
            end
            local transform = Transform(portal.pos, QuatLookAt(portal.pos, cameraPos))
            DrawSprite(_portalGlowSprite, transform, sizeOuter, sizeOuter, r1, g1, b1, envelope * 0.55, true, true, false)
            DrawSprite(_portalGlowSprite, transform, sizeMid, sizeMid, r2, g2, b2, envelope * 0.75, true, true, false)
            DrawSprite(_portalGlowSprite, transform, sizeCore, sizeCore, r3, g3, b3, envelope, true, true, false)
        end
    end
end
