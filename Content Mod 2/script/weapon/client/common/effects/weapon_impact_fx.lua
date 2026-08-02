---@diagnostic disable: undefined-global
client = client or {}
client.weaponImpactFxState = client.weaponImpactFxState or { active = {} }

local function _normal(v)
    local length = VecLength(v)
    if length < 0.0001 then return Vec(0, 1, 0) end
    return VecScale(v, 1 / length)
end

function client.weaponImpactFxInit() client.weaponImpactFxState.active = {} end

function client.spawnWeaponImpactFx(weaponType, position, normal, impactLayer)
    local definition = (weaponData or {})[tostring(weaponType or "")] or {}
    local profile = tostring(definition.impactFxProfile or "")
    if profile ~= "focusedArcImpact" and profile ~= "disruptorImplosion"
        and profile ~= "perditionImpact" then return false end
    local active = client.weaponImpactFxState.active
    if #active >= 6 and profile == "focusedArcImpact" then return false end
    if #active >= 128 then table.remove(active, 1) end
    local effect = {
        profile = profile, position = position, normal = _normal(normal), age = 0,
        life = profile == "perditionImpact" and 0.58 or (profile == "focusedArcImpact" and 0.18 or 0.20),
        layer = impactLayer,
    }
    table.insert(active, effect)
    local count = profile == "focusedArcImpact" and 12 or (profile == "perditionImpact" and 0 or 18)
    if client.weaponFxTakeParticles(count, "normal") then
        ParticleReset(); ParticleType("plain")
        local r, g, b = profile == "focusedArcImpact" and 0.85 or 0.25, profile == "focusedArcImpact" and 0.35 or 1.0, profile == "focusedArcImpact" and 1.0 or 0.42
        ParticleColor(r, g, b, 0.02, g * 0.1, b * 0.2); ParticleRadius(0.13, 0.01, "easeout"); ParticleAlpha(0.9, 0, "easeout"); ParticleGravity(0); ParticleDrag(0.15); ParticleEmissive(18, 0); ParticleCollide(0)
        for i = 1, count do
            local radial = _normal(Vec(math.random() - .5, math.random() - .5, math.random() - .5))
            local velocity = profile == "disruptorImplosion" and VecScale(radial, -(5 + math.random() * 7)) or VecScale(radial, 5 + math.random() * 8)
            SpawnParticle(VecAdd(position, profile == "disruptorImplosion" and VecScale(radial, 1.2) or Vec(0, 0, 0)), velocity, 0.16)
        end
    end
    return true
end

function client.weaponImpactFxTick(dt)
    local active = client.weaponImpactFxState.active
    for i = #active, 1, -1 do
        active[i].age = active[i].age + math.max(0, dt or 0)
        if active[i].age >= active[i].life then table.remove(active, i) end
    end
end

function client.weaponImpactFxRender()
    for _, effect in ipairs(client.weaponImpactFxState.active) do
        local t, alpha = effect.age / effect.life, (1 - effect.age / effect.life) ^ 2
        local color = effect.profile == "focusedArcImpact" and { 0.78, 0.25, 1.0 }
            or (effect.profile == "perditionImpact" and { 1.0, 0.16, 0.03 } or { 0.16, 1.0, 0.35 })
        local size = effect.profile == "focusedArcImpact" and (1.4 + t * 2.2)
            or (effect.profile == "perditionImpact" and (1.8 + t * 6.6) or (2.6 * (1 - t) + 0.08))
        if client.weaponFxTakeSprite(1) then
            DrawSprite(client.weaponFxResources.ring, Transform(effect.position, QuatLookAt(effect.position, GetCameraTransform().pos)), size, size, color[1], color[2], color[3], alpha * 0.55, true, true, false)
        end
        if effect.profile == "perditionImpact" and client.weaponFxTakeSprite(1) then
            DrawSprite(client.weaponFxResources.soft, Transform(effect.position, QuatLookAt(effect.position, GetCameraTransform().pos)), size * 1.75, size * 1.75, 2.4, 0.32, 0.05, alpha * 0.28, true, true, false)
        end
        if t < .18 then client.weaponFxPointLight(effect.position, color[1], color[2], color[3], effect.profile == "perditionImpact" and 28 * alpha or 10 * alpha) end
    end
end
