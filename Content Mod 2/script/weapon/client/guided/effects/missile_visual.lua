---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.missileVisualState = client.missileVisualState or {
    byId = {},
    trailSprite = 0,
}

local _profiles = {
    swarmerMissile = { color = { 0.20, 0.56, 1.00 }, glow = { 0.40, 0.82, 1.00 }, radius = 0.16, spacing = 7.0, light = 4.0 },
    devastatorTorpedo = { color = { 1.00, 0.34, 0.08 }, glow = { 1.00, 0.72, 0.18 }, radius = 0.30, spacing = 3.5, light = 10.0 },
}

local function _normalize(value, fallback)
    local length = VecLength(value)
    if length < 0.0001 then return fallback or Vec(0, 0, -1) end
    return VecScale(value, 1.0 / length)
end

local function _profileFor(weaponType)
    local definition = (weaponData or {})[tostring(weaponType or "")] or {}
    return _profiles[tostring(definition.projectileFxVariant or "")] or _profiles.swarmerMissile
end

function client.missileVisualInit()
    client.missileVisualState.byId = {}
    client.missileVisualState.trailSprite = LoadSprite("MOD/gfx/weapons/tachyon_lance/beam_soft.png")
end

function client.spawnMissileVisual(missileId, weaponType, px, py, pz, vx, vy, vz, lifetime)
    local position = Vec(px or 0, py or 0, pz or 0)
    local velocity = Vec(vx or 0, vy or 0, vz or 0)
    client.missileVisualState.byId[missileId] = {
        id = missileId, weaponType = tostring(weaponType or ""), position = position,
        velocity = velocity, lastPosition = Vec(position[1], position[2], position[3]),
        lifeRemain = math.max(1.0, tonumber(lifetime) or 10.0) + 2.0,
        nextTrailDistance = 0.0, distanceTravelled = 0.0,
        correctionTargetPos = nil, correctionTargetVel = nil,
        correctionRemain = 0.0, correctionDuration = 0.15,
    }
    client.playMissileLoopSound(px or 0, py or 0, pz or 0)
end

function client.finishMissileVisual(missileId)
    client.missileVisualState.byId[missileId] = nil
end

function client.correctMissileVisual(missileId, px, py, pz, vx, vy, vz, serverTime)
    local missile = client.missileVisualState.byId[missileId]
    if missile == nil then return end
    local _ = serverTime
    missile.correctionTargetPos = Vec(px or 0, py or 0, pz or 0)
    missile.correctionTargetVel = Vec(vx or 0, vy or 0, vz or 0)
    missile.correctionRemain = missile.correctionDuration
end

function client.updateMissileVisual(missileId, px, py, pz, vx, vy, vz)
    client.correctMissileVisual(missileId, px, py, pz, vx, vy, vz, 0.0)
end

function client.missileVisualTick(dt)
    for missileId, missile in pairs(client.missileVisualState.byId) do
        local step = math.max(0.0, dt or 0.0)
        missile.lastPosition = Vec(missile.position[1], missile.position[2], missile.position[3])
        missile.lifeRemain = missile.lifeRemain - step
        missile.position = VecAdd(missile.position, VecScale(missile.velocity, step))
        if (missile.correctionRemain or 0.0) > 0.0 and missile.correctionTargetPos ~= nil then
            local alpha = math.min(1.0, step / math.max(0.0001, missile.correctionRemain))
            missile.position = VecLerp(missile.position, missile.correctionTargetPos, alpha)
            missile.velocity = VecLerp(missile.velocity, missile.correctionTargetVel, alpha)
            missile.correctionRemain = math.max(0.0, missile.correctionRemain - step)
        end
        missile.distanceTravelled = (missile.distanceTravelled or 0.0) + VecLength(VecSub(missile.position, missile.lastPosition))
        if missile.lifeRemain <= 0.0 then client.missileVisualState.byId[missileId] = nil end
    end
end

local function _emitTrail(missile, position, profile)
    if not client.weaponFxTakeParticles(1, "ambient") then return end
    local direction = _normalize(missile.velocity, Vec(0, 0, -1))
    ParticleReset(); ParticleType("plain")
    ParticleColor(profile.color[1], profile.color[2], profile.color[3], 0.04, 0.06, 0.12)
    ParticleRadius(profile.radius, 0.01, "easeout"); ParticleAlpha(0.85, 0.0, "easeout")
    ParticleGravity(0); ParticleDrag(0.12); ParticleEmissive(12, 0); ParticleStretch(1.8, 0.2, "easeout"); ParticleCollide(0)
    SpawnParticle(position, VecScale(direction, -3.0), 0.30)
end

function client.missileVisualRender()
    local cameraPos = GetCameraTransform().pos
    for _, missile in pairs(client.missileVisualState.byId) do
        local profile = _profileFor(missile.weaponType)
        local distance = VecLength(VecSub(missile.position, cameraPos))
        local direction = _normalize(missile.velocity, Vec(0, 0, -1))
        if distance < 900 and client.weaponFxTakeSprite(1) then
            local transform = Transform(missile.position, QuatLookAt(missile.position, cameraPos))
            DrawSprite(client.missileVisualState.trailSprite, transform, profile.radius * 5.0, profile.radius * 5.0, profile.glow[1], profile.glow[2], profile.glow[3], 0.85, true, true, false)
        end
        if distance < 320 then client.weaponFxPointLight(missile.position, profile.color[1], profile.color[2], profile.color[3], profile.light) end
        if distance < 420 then
            local nextDistance = missile.nextTrailDistance or 0.0
            while nextDistance <= (missile.distanceTravelled or 0.0) do
                local travelled = missile.distanceTravelled - nextDistance
                local position = VecSub(missile.position, VecScale(direction, travelled))
                _emitTrail(missile, position, profile)
                nextDistance = nextDistance + profile.spacing
            end
            missile.nextTrailDistance = nextDistance
        end
        if distance < 600 then client.playMissileLoopSound(missile.position[1], missile.position[2], missile.position[3]) end
    end
end
