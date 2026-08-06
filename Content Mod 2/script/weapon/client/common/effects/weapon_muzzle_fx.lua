---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local Profiles = {
    disruptor = { life = 0.08, size = 0.56, particles = 7, color = { 0.18, 1.0, 0.32 }, light = 6, distance = 220, lines = 0 },
    gaussLarge = { life = 0.09, size = 0.72, particles = 10, color = { 0.22, 0.65, 1.0 }, light = 7, distance = 260, lines = 2 },
    gaussMedium = { life = 0.07, size = 0.50, particles = 6, color = { 0.22, 0.65, 1.0 }, light = 4, distance = 170, lines = 2 },
    kineticArtillery = { life = 0.11, size = 0.88, particles = 14, color = { 1.0, 0.65, 0.16 }, light = 7, distance = 260, lines = 1 },
    autocannonLarge = { life = 0.04, size = 0.30, particles = 2, color = { 1.0, 0.42, 0.08 }, light = 0, distance = 0, lines = 1 },
    autocannonMedium = { life = 0.03, size = 0.22, particles = 1, color = { 1.0, 0.42, 0.08 }, light = 0, distance = 0, lines = 1 },
    plasmaLarge = { life = 0.16, size = 1.0, particles = 12, color = { 0.18, 1.0, 0.30 }, light = 8, distance = 260, lines = 0 },
    plasmaMedium = { life = 0.12, size = 0.70, particles = 8, color = { 0.18, 1.0, 0.30 }, light = 5, distance = 190, lines = 0 },
    gigaMagneticLaunch = { life = 0.16, size = 1.25, particles = 18, color = { 0.68, 0.16, 1.0 }, light = 16, distance = 500, lines = 0 },
    neutronCompression = { life = 0.13, size = 0.80, particles = 6, color = { 0.18, 0.58, 1.0 }, light = 12, distance = 340, lines = 0 },
    swarmerLaunch = { life = 0.15, size = 0.50, particles = 6, color = { 0.25, 0.72, 1.0 }, light = 5, distance = 220, lines = 0, portalFx = true, portalLife = 0.40 },
    torpedoLaunch = { life = 0.20, size = 0.90, particles = 24, color = { 1.0, 0.28, 0.06 }, light = 14, distance = 360, lines = 0 },
}

client.weaponMuzzleFxState = client.weaponMuzzleFxState or { active = {}, portals = {}, sprite = 0 }

local function _normalize(v)
    local length = VecLength(v)
    return length < 0.001 and Vec(0, 0, -1) or VecScale(v, 1 / length)
end

function client.weaponMuzzleFxInit()
    client.weaponMuzzleFxState = { active = {}, portals = {}, sprite = LoadSprite("MOD/gfx/weapons/projectiles/impact_glow.png") }
end

function client.spawnWeaponMuzzleFx(weaponType, px, py, pz, dx, dy, dz)
    local definition = (weaponData or {})[tostring(weaponType or "")] or {}
    local profile = Profiles[tostring(definition.muzzleFxProfile or "")]
    if profile == nil then return end
    local state = client.weaponMuzzleFxState
    local position = Vec(px or 0, py or 0, pz or 0)
    local direction = _normalize(Vec(dx or 0, dy or 0, dz or -1))
    local key = tostring(weaponType) .. ":" .. math.floor((px or 0) * 2) .. ":" .. math.floor((py or 0) * 2) .. ":" .. math.floor((pz or 0) * 2)
    for _, effect in ipairs(state.active) do
        if effect.key == key then effect.age = 0; effect.intensity = math.min(1.5, effect.intensity + 0.4); return end
    end
    if #state.active >= (client.weaponFxBudgetConfig.maxActiveMuzzles or 128) then table.remove(state.active, 1) end
    table.insert(state.active, { key = key, position = position, direction = direction, profile = profile, color = definition.fxColor or profile.color, age = 0, intensity = 1.0 })
    if profile.portalFx then
        table.insert(state.portals, { pos = position, age = 0, life = profile.portalLife or 0.40 })
    end
    if not client.weaponFxTakeParticles(profile.particles, "normal") then return end
    local tint = definition.fxColor or profile.color
    ParticleReset(); ParticleType("plain"); ParticleColor(tint[1], tint[2], tint[3], tint[1] * 0.25, tint[2] * 0.12, tint[3] * 0.08); ParticleRadius(0.09, 0.01, "easeout"); ParticleAlpha(0.95, 0, "easeout"); ParticleGravity(0); ParticleDrag(0.14); ParticleEmissive(16, 0); ParticleCollide(0)
    for _ = 1, profile.particles do SpawnParticle(position, VecAdd(VecScale(direction, -3 - math.random() * 5), Vec(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)), 0.10 + math.random() * 0.10) end
end

function client.weaponMuzzleFxTick(dt)
    local state = client.weaponMuzzleFxState
    for index = #state.active, 1, -1 do
        local effect = state.active[index]; effect.age = effect.age + math.max(0, dt or 0)
        if effect.age >= effect.profile.life then table.remove(state.active, index) end
    end
    for index = #state.portals, 1, -1 do
        local p = state.portals[index]; p.age = p.age + math.max(0, dt or 0)
        if p.age >= p.life then table.remove(state.portals, index) end
    end
end

function client.weaponMuzzleFxRender()
    local state = client.weaponMuzzleFxState
    for _, effect in ipairs(state.active) do
        local profile = effect.profile; local tint = effect.color or profile.color; local alpha = (1 - effect.age / profile.life) ^ 2 * effect.intensity
        if client.weaponFxTakeSprite(1) then DrawSprite(state.sprite, Transform(effect.position, QuatLookAt(effect.position, GetCameraTransform().pos)), profile.size * (0.7 + effect.age / profile.life), profile.size * (0.7 + effect.age / profile.life), tint[1], tint[2], tint[3], alpha, true, true, false) end
        if profile.lines > 0 then
            local right = _normalize(VecCross(effect.direction, Vec(0, 1, 0)))
            for index = 1, profile.lines do
                if client.weaponFxTakeLine(1) then
                    local offset = profile.lines == 2 and VecScale(right, index == 1 and 0.18 or -0.18) or Vec(0, 0, 0)
                    DrawLine(VecAdd(effect.position, offset), VecAdd(VecAdd(effect.position, offset), VecScale(effect.direction, 1.2)), tint[1], tint[2], tint[3], alpha)
                end
            end
        end
        if profile.light > 0 then client.weaponFxPointLight(effect.position, tint[1], tint[2], tint[3], profile.light * alpha, profile.distance) end
    end
    local cam = GetCameraTransform()
    for _, portal in ipairs(state.portals) do
        local t = portal.age / portal.life
        local sizeBase
        if t < 0.20 then
            sizeBase = 1 - (1 - t / 0.20) ^ 3
        elseif t < 0.40 then
            sizeBase = 1.0
        else
            sizeBase = math.max(0, 1 - ((t - 0.40) / 0.60) ^ 1.6)
        end
        local env
        if t < 0.08 then env = t / 0.08
        elseif t < 0.45 then env = 1.0
        else env = math.max(0, 1 - ((t - 0.45) / 0.55) ^ 0.7) end
        local shockR = (math.min(t, 0.50) / 0.50) * 5.5
        local shockA = math.max(0, 1 - t / 0.50) * 0.42 * (t < 0.05 and t / 0.05 or 1.0)
        local xf = Transform(portal.pos, QuatLookAt(portal.pos, cam.pos))
        if client.weaponFxTakeSprite(4) then
            if shockA > 0.005 then DrawSprite(state.sprite, xf, shockR, shockR, 0.20, 0.30, 0.90, shockA, true, true, false) end
            DrawSprite(state.sprite, xf, sizeBase * 3.4, sizeBase * 3.4, 0.30, 0.20, 1.00, env * 0.52, true, true, false)
            DrawSprite(state.sprite, xf, sizeBase * 2.2, sizeBase * 2.2, 0.25, 0.55, 1.60, env * 0.82, true, true, false)
            DrawSprite(state.sprite, xf, sizeBase * 0.85, sizeBase * 0.85, 2.00, 2.10, 3.50, env * 0.95, true, true, false)
        end
        client.weaponFxPointLight(portal.pos, 0.30, 0.50, 1.40, env * (t < 0.20 and 28 or 20), 420)
    end
end
