---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local Profiles = {
    gaussLarge = { life = 0.09, size = 0.72, particles = 10, color = { 0.22, 0.65, 1.0 }, light = 7, distance = 260, lines = 2 },
    gaussMedium = { life = 0.07, size = 0.50, particles = 6, color = { 0.22, 0.65, 1.0 }, light = 4, distance = 170, lines = 2 },
    kineticArtillery = { life = 0.11, size = 0.88, particles = 14, color = { 1.0, 0.65, 0.16 }, light = 7, distance = 260, lines = 1 },
    autocannonLarge = { life = 0.04, size = 0.30, particles = 2, color = { 1.0, 0.42, 0.08 }, light = 0, distance = 0, lines = 1 },
    autocannonMedium = { life = 0.03, size = 0.22, particles = 1, color = { 1.0, 0.42, 0.08 }, light = 0, distance = 0, lines = 1 },
    plasmaLarge = { life = 0.16, size = 1.0, particles = 12, color = { 0.18, 1.0, 0.30 }, light = 8, distance = 260, lines = 0 },
    plasmaMedium = { life = 0.12, size = 0.70, particles = 8, color = { 0.18, 1.0, 0.30 }, light = 5, distance = 190, lines = 0 },
    gigaMagneticLaunch = { life = 0.16, size = 1.25, particles = 18, color = { 0.68, 0.16, 1.0 }, light = 16, distance = 500, lines = 0 },
    neutronCompression = { life = 0.13, size = 0.80, particles = 6, color = { 0.18, 0.58, 1.0 }, light = 12, distance = 340, lines = 0 },
    swarmerLaunch = { life = 0.15, size = 0.50, particles = 14, color = { 0.25, 0.72, 1.0 }, light = 5, distance = 220, lines = 0 },
    torpedoLaunch = { life = 0.20, size = 0.90, particles = 24, color = { 1.0, 0.28, 0.06 }, light = 14, distance = 360, lines = 0 },
}

client.weaponMuzzleFxState = client.weaponMuzzleFxState or { active = {}, sprite = 0 }

local function _normalize(v)
    local length = VecLength(v)
    return length < 0.001 and Vec(0, 0, -1) or VecScale(v, 1 / length)
end

function client.weaponMuzzleFxInit()
    client.weaponMuzzleFxState = { active = {}, sprite = LoadSprite("MOD/gfx/weapons/projectiles/impact_glow.png") }
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
    table.insert(state.active, { key = key, position = position, direction = direction, profile = profile, age = 0, intensity = 1.0 })
    if not client.weaponFxTakeParticles(profile.particles, "normal") then return end
    ParticleReset(); ParticleType("plain"); ParticleColor(profile.color[1], profile.color[2], profile.color[3], profile.color[1] * 0.25, profile.color[2] * 0.12, profile.color[3] * 0.08); ParticleRadius(0.09, 0.01, "easeout"); ParticleAlpha(0.95, 0, "easeout"); ParticleGravity(0); ParticleDrag(0.14); ParticleEmissive(16, 0); ParticleCollide(0)
    for _ = 1, profile.particles do SpawnParticle(position, VecAdd(VecScale(direction, -3 - math.random() * 5), Vec(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)), 0.10 + math.random() * 0.10) end
end

function client.weaponMuzzleFxTick(dt)
    local active = client.weaponMuzzleFxState.active
    for index = #active, 1, -1 do
        local effect = active[index]; effect.age = effect.age + math.max(0, dt or 0)
        if effect.age >= effect.profile.life then table.remove(active, index) end
    end
end

function client.weaponMuzzleFxRender()
    local state = client.weaponMuzzleFxState
    for _, effect in ipairs(state.active) do
        local profile = effect.profile; local alpha = (1 - effect.age / profile.life) ^ 2 * effect.intensity
        if client.weaponFxTakeSprite(1) then DrawSprite(state.sprite, Transform(effect.position, QuatLookAt(effect.position, GetCameraTransform().pos)), profile.size * (0.7 + effect.age / profile.life), profile.size * (0.7 + effect.age / profile.life), profile.color[1], profile.color[2], profile.color[3], alpha, true, true, false) end
        if profile.lines > 0 then
            local right = _normalize(VecCross(effect.direction, Vec(0, 1, 0)))
            for index = 1, profile.lines do
                if client.weaponFxTakeLine(1) then
                    local offset = profile.lines == 2 and VecScale(right, index == 1 and 0.18 or -0.18) or Vec(0, 0, 0)
                    DrawLine(VecAdd(effect.position, offset), VecAdd(VecAdd(effect.position, offset), VecScale(effect.direction, 1.2)), profile.color[1], profile.color[2], profile.color[3], alpha)
                end
            end
        end
        if profile.light > 0 then client.weaponFxPointLight(effect.position, profile.color[1], profile.color[2], profile.color[3], profile.light * alpha, profile.distance) end
    end
end
