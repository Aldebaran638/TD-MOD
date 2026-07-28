---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local GammaProfiles = {
    gammaLarge = {
        life = 0.26, outerWidth = 1.15, middleWidth = 0.32, coreWidth = 0.095,
        outerColor = { 1.00, 0.12, 0.005 }, middleColor = { 1.60, 0.52, 0.035 }, coreColor = { 3.20, 2.60, 1.05 },
        muzzleSize = 2.10, muzzleLife = 0.16, impactSize = 2.10, impactLife = 0.30, impactParticles = 14, light = 14.0, lightDistance = 420,
        muzzleColor = { 1.4, 0.72, 0.12 }, muzzleLightColor = { 1.0, 0.38, 0.05 },
        impactColor = { 1.6, 1.2, 0.5 }, impactColor2 = { 1.4, 0.18, 0.01 },
    },
    gammaMedium = {
        life = 0.20, outerWidth = 0.78, middleWidth = 0.23, coreWidth = 0.068,
        outerColor = { 1.00, 0.12, 0.005 }, middleColor = { 1.50, 0.48, 0.030 }, coreColor = { 3.00, 2.35, 0.95 },
        muzzleSize = 1.40, muzzleLife = 0.13, impactSize = 1.35, impactLife = 0.24, impactParticles = 9, light = 8.0, lightDistance = 320,
        muzzleColor = { 1.4, 0.72, 0.12 }, muzzleLightColor = { 1.0, 0.38, 0.05 },
        impactColor = { 1.6, 1.2, 0.5 }, impactColor2 = { 1.4, 0.18, 0.01 },
    },
    -- Tachyon Lance palette (outer glow / inner glow / core), scaled to 75% intensity for a fighter-scale weapon
    strikeGamma = {
        life = 0.22, outerWidth = 1.10, middleWidth = 0.42, coreWidth = 0.14,
        outerColor = { 0.06, 0.26, 0.75 }, middleColor = { 0.23, 0.83, 1.35 }, coreColor = { 1.88, 1.88, 1.88 },
        muzzleSize = 1.20, muzzleLife = 0.12, impactSize = 1.20, impactLife = 0.22, impactParticles = 8, light = 9.0, lightDistance = 280,
        muzzleColor = { 0.85, 1.35, 1.95 }, muzzleLightColor = { 0.30, 0.65, 1.40 },
        impactColor = { 0.55, 1.30, 1.90 }, impactColor2 = { 0.20, 0.55, 1.40 },
    },
}

client.gammaLaserFxState = client.gammaLaserFxState or { muzzles = {}, impacts = {}, beamSprite = 0, glowSprite = 0 }

local function _normalize(v, fallback)
    local length = VecLength(v)
    if length < 0.0001 then return fallback or Vec(0, 0, -1) end
    return VecScale(v, 1.0 / length)
end

local function _profileForWeapon(weaponType)
    return GammaProfiles[tostring(weaponType) == "largeGammaLaser" and "gammaLarge" or "gammaMedium"]
end

function client.gammaLaserFxInit()
    local state = client.gammaLaserFxState
    state.muzzles, state.impacts = {}, {}
    state.beamSprite = LoadSprite("MOD/gfx/weapons/tachyon_lance/beam_soft.png")
    state.glowSprite = LoadSprite("MOD/gfx/weapons/projectiles/impact_glow.png")
end

function client.gammaLaserFxProfile(weaponType)
    if tostring(weaponType) == "gammaStrikeCraft" then return GammaProfiles.strikeGamma end
    return _profileForWeapon(weaponType)
end

function client.spawnGammaLaserMuzzleFx(weaponType, position, direction)
    local profile = client.gammaLaserFxProfile(weaponType)
    local state = client.gammaLaserFxState
    if #state.muzzles >= (client.weaponFxBudgetConfig.maxActiveMuzzles or 128) then table.remove(state.muzzles, 1) end
    table.insert(state.muzzles, { position = position, direction = _normalize(direction), profile = profile, mode = "muzzle", age = 0.0 })
    local count = tostring(weaponType) == "largeGammaLaser" and 8 or (tostring(weaponType) == "mediumGammaLaser" and 5 or 2)
    if not client.weaponFxTakeParticles(count, "normal") then return end
    local right = _normalize(VecCross(direction, Vec(0, 1, 0)), Vec(1, 0, 0))
    local up = _normalize(VecCross(right, direction), Vec(0, 1, 0))
    ParticleReset(); ParticleType("plain")
    ParticleColor(1.0, 0.75, 0.18, 0.9, 0.10, 0.01); ParticleRadius(0.055, 0.01, "easeout"); ParticleAlpha(0.9, 0.0); ParticleGravity(0); ParticleDrag(0.1); ParticleEmissive(16, 0); ParticleCollide(0)
    for index = 1, count do
        local angle = index * math.pi * 2 / count
        local tangent = VecAdd(VecScale(right, math.cos(angle)), VecScale(up, math.sin(angle)))
        SpawnParticle(position, VecAdd(VecScale(direction, -2.0), VecScale(tangent, 4.0)), 0.12)
    end
end

function client.spawnGammaLaserImpactFx(weaponType, position, normal, impactLayer)
    local profile = client.gammaLaserFxProfile(weaponType)
    local state = client.gammaLaserFxState
    if #state.impacts >= (client.weaponFxBudgetConfig.maxActiveImpacts or 128) then table.remove(state.impacts, 1) end
    table.insert(state.impacts, { position = position, normal = _normalize(normal, Vec(0, 1, 0)), profile = profile, mode = "impact", layer = tostring(impactLayer or "body"), age = 0.0 })
    local count = profile.impactParticles
    if impactLayer == "shield" then count = math.max(1, math.floor(count * 0.4)) end
    if not client.weaponFxTakeParticles(count, "normal") then return end
    local right = _normalize(VecCross(normal, Vec(0, 1, 0)), Vec(1, 0, 0)); local up = _normalize(VecCross(right, normal), Vec(0, 1, 0))
    ParticleReset(); ParticleType("plain"); ParticleColor(1, 0.72, 0.18, 0.85, 0.08, 0.01); ParticleRadius(0.09, 0.01, "easeout"); ParticleAlpha(1, 0, "easeout"); ParticleGravity(0); ParticleDrag(0.12); ParticleEmissive(18, 0); ParticleCollide(0)
    for index = 1, count do
        local angle = index * math.pi * 2 / count
        local tangent = VecAdd(VecScale(right, math.cos(angle)), VecScale(up, math.sin(angle)))
        SpawnParticle(position, VecScale(tangent, 4 + math.random() * 5), 0.12 + math.random() * 0.14)
    end
end

function client.gammaLaserFxTick(dt)
    local state = client.gammaLaserFxState
    for _, list in ipairs({ state.muzzles, state.impacts }) do
        for index = #list, 1, -1 do
            local item = list[index]; item.age = item.age + math.max(0, dt or 0)
            local life = item.mode == "impact" and item.profile.impactLife or item.profile.muzzleLife
            if item.age >= life then table.remove(list, index) end
        end
    end
end

function client.gammaLaserDrawBeam(startPos, endPos, profile, age, lifetime)
    local state = client.gammaLaserFxState
    local vector = VecSub(endPos, startPos); local length = VecLength(vector)
    if length < 0.001 then return end
    local direction = VecScale(vector, 1 / length); local center = VecLerp(startPos, endPos, 0.5)
    local toCamera = _normalize(VecSub(GetCameraTransform().pos, center), Vec(0, 1, 0))
    local transform = Transform(center, QuatAlignXZ(direction, toCamera))
    local t = math.min(1, age / math.max(0.001, lifetime)); local alpha = t < 0.015 and 0.85 + t * 10.0 or (1 - (t - 0.015) / 0.985) ^ 1.45
    if client.weaponFxTakeSprite(3) then
        DrawSprite(state.beamSprite, transform, length, profile.outerWidth, profile.outerColor[1], profile.outerColor[2], profile.outerColor[3], alpha * 0.42, true, true, false)
        DrawSprite(state.beamSprite, transform, length, profile.middleWidth, profile.middleColor[1], profile.middleColor[2], profile.middleColor[3], alpha * 0.78, true, true, false)
        DrawSprite(state.beamSprite, transform, length, profile.coreWidth, profile.coreColor[1], profile.coreColor[2], profile.coreColor[3], alpha, true, true, false)
    end
end

function client.gammaLaserFxRender()
    local state = client.gammaLaserFxState
    for _, muzzle in ipairs(state.muzzles) do
        local p, profile = muzzle.position, muzzle.profile; local alpha = (1 - muzzle.age / profile.muzzleLife) ^ 2
        local mc = profile.muzzleColor or { 1.4, 0.72, 0.12 }
        local mlc = profile.muzzleLightColor or { 1, 0.38, 0.05 }
        if client.weaponFxTakeSprite(1) then DrawSprite(state.glowSprite, Transform(p, QuatLookAt(p, GetCameraTransform().pos)), profile.muzzleSize, profile.muzzleSize, mc[1], mc[2], mc[3], alpha, true, true, false) end
        if profile.light > 0 then client.weaponFxPointLight(p, mlc[1], mlc[2], mlc[3], profile.light * alpha, profile.lightDistance) end
    end
    for _, impact in ipairs(state.impacts) do
        local profile = impact.profile; local t = impact.age / profile.impactLife; local alpha = (1 - t) ^ 2
        local ic = profile.impactColor or { 1.6, 1.2, 0.5 }
        local ic2 = profile.impactColor2 or { 1.4, 0.18, 0.01 }
        if client.weaponFxTakeSprite(impact.layer == "shield" and 1 or 2) then
            local transform = Transform(impact.position, QuatLookAt(impact.position, GetCameraTransform().pos))
            DrawSprite(state.glowSprite, transform, profile.impactSize * (0.35 + t * 0.55), profile.impactSize * (0.35 + t * 0.55), ic[1], ic[2], ic[3], alpha, true, true, false)
            if impact.layer ~= "shield" then DrawSprite(state.glowSprite, transform, profile.impactSize * (0.55 + t), profile.impactSize * (0.55 + t), ic2[1], ic2[2], ic2[3], alpha * 0.45, true, true, false) end
        end
    end
end
