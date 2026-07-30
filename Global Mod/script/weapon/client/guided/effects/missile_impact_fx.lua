---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local function _normalize(value, fallback)
    local length = VecLength(value)
    if length < 0.0001 then return fallback or Vec(0, 1, 0) end
    return VecScale(value, 1.0 / length)
end

function client.playMissileImpactFx(weaponType, hitX, hitY, hitZ, nx, ny, nz, impactLayer, hitTargetBodyId)
    local definition = (weaponData or {})[tostring(weaponType or "")] or {}
    local torpedo = tostring(definition.projectileFxVariant or "") == "devastatorTorpedo"
    local pos, normal = Vec(hitX or 0, hitY or 0, hitZ or 0), _normalize(Vec(nx or 0, ny or 1, nz or 0))
    local r, g, b = torpedo and 1.0 or 0.25, torpedo and 0.32 or 0.75, torpedo and 0.06 or 1.0
    if impactLayer == "shield" then r, g, b = 0.18, 0.88, 1.0 end
    if impactLayer == "shield" and math.floor(hitTargetBodyId or 0) ~= 0 then
        client.playProjectileShieldImpactFx(
            hitTargetBodyId,
            pos[1], pos[2], pos[3],
            weaponType
        )
    end
    client.weaponFxPointLight(pos, r, g, b, torpedo and 18 or 8)
    local count = torpedo and 28 or 14
    if not client.weaponFxTakeParticles(count, "normal") then return end
    ParticleReset(); ParticleType("plain")
    ParticleColor(r, g, b, r * 0.25, g * 0.12, b * 0.08)
    ParticleRadius(torpedo and 0.48 or 0.22, 0.01, "easeout"); ParticleAlpha(0.95, 0.0, "easeout")
    ParticleGravity(0); ParticleDrag(0.10); ParticleEmissive(torpedo and 28 or 15, 0); ParticleCollide(0)
    for _ = 1, count do
        local scatter = Vec(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
        local out = _normalize(VecAdd(normal, VecScale(scatter, torpedo and 1.5 or 0.8)), normal)
        SpawnParticle(pos, VecScale(out, torpedo and (8 + math.random() * 10) or (4 + math.random() * 6)), torpedo and 0.65 or 0.38)
    end
end
