---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.projectileVisualState = client.projectileVisualState or {
    byId = {},
    impacts = {},
    assets = { plasmaCore = 0, plasmaGlow = 0, neutronNeedle = 0, impactGlow = 0 },
}

local IMPACT_LIMIT = 64

local function _safeNormalize(value, fallback)
    local length = VecLength(value)
    if length < 0.0001 then
        return fallback or Vec(0.0, 0.0, -1.0)
    end
    return VecScale(value, 1.0 / length)
end

local function _buildProjectileBasis(direction)
    local reference = math.abs(direction[2]) < 0.90 and Vec(0, 1, 0) or Vec(1, 0, 0)
    local right = _safeNormalize(VecCross(direction, reference), Vec(1, 0, 0))
    return right, _safeNormalize(VecCross(right, direction), Vec(0, 1, 0))
end

local function _nextRandom(projectile)
    local state = tonumber(projectile.randomState) or 1
    state = (state * 1664525 + 1013904223) % 4294967296
    projectile.randomState = state
    return state / 4294967296
end

local function _randomRange(projectile, low, high)
    return low + (high - low) * _nextRandom(projectile)
end

local function _cameraDistance(position)
    return VecLength(VecSub(position, GetCameraTransform().pos))
end

local function _takeParticleBudget(kind, amount)
    local priority = kind == "trailParticles" and "ambient" or "normal"
    return client.weaponFxTakeParticles(amount, priority)
end

local function _drawBillboard(sprite, position, width, height, r, g, b, alpha)
    if sprite == nil or sprite == 0 then return end
    if not client.weaponFxTakeSprite(1) then return end
    DrawSprite(sprite, Transform(position, QuatLookAt(position, GetCameraTransform().pos)), width, height, r, g, b, alpha, true, true, false)
end

local function _drawDirectionalSprite(sprite, startPos, endPos, thickness, r, g, b, alpha)
    if sprite == nil or sprite == 0 then return end
    local vector = VecSub(endPos, startPos)
    local length = VecLength(vector)
    if length < 0.001 then return end
    if not client.weaponFxTakeSprite(1) then return end
    local center = VecLerp(startPos, endPos, 0.5)
    local direction = VecScale(vector, 1.0 / length)
    local toCamera = _safeNormalize(VecSub(GetCameraTransform().pos, center), Vec(0, 1, 0))
    DrawSprite(sprite, Transform(center, QuatAlignXZ(direction, toCamera)), length, thickness, r, g, b, alpha, true, true, false)
end

local function _drawLine(startPos, endPos, r, g, b, alpha)
    if not client.weaponFxTakeLine(1) then return end
    DrawLine(startPos, endPos, r, g, b, alpha)
end

local function _emitDistanceEvents(projectile, previousPosition, currentPosition, nextField, spacing, maxPerTick, callback)
    local movement = VecSub(currentPosition, previousPosition)
    local movementLength = VecLength(movement)
    if movementLength < 0.0001 then return end
    local previousDistance = projectile.distanceTravelled or 0.0
    local nextDistance = projectile[nextField] or previousDistance
    local newDistance = previousDistance + movementLength
    local emitted = 0
    while nextDistance <= newDistance and emitted < maxPerTick do
        local t = math.max(0.0, math.min(1.0, (nextDistance - previousDistance) / movementLength))
        callback(projectile, VecLerp(previousPosition, currentPosition, t))
        nextDistance = nextDistance + spacing
        emitted = emitted + 1
    end
    projectile[nextField] = nextDistance
end

local function _pointLight(pos, r, g, b, intensity)
    client.weaponFxPointLight(pos, r, g, b, intensity)
end

function client.projectileVisualInit()
    local state = client.projectileVisualState
    state.byId = {}
    state.impacts = {}
    state.assets = state.assets or {}
    state.assets.plasmaCore = LoadSprite("MOD/gfx/weapons/projectiles/plasma_core.png")
    state.assets.plasmaGlow = LoadSprite("MOD/gfx/weapons/projectiles/plasma_glow.png")
    state.assets.impactGlow = LoadSprite("MOD/gfx/weapons/projectiles/impact_glow.png")
    state.assets.neutronNeedle = LoadSprite("MOD/gfx/weapons/tachyon_lance/beam_soft.png")
end

function client.spawnProjectileVisual(projectileId, weaponType, px, py, pz, vx, vy, vz, lifeRemain)
    local definition = (weaponData or {})[tostring(weaponType or "")] or {}
    local velocity = Vec(vx or 0, vy or 0, vz or 0)
    local direction = _safeNormalize(velocity, Vec(0, 0, -1))
    local rightAxis, upAxis = _buildProjectileBasis(direction)
    local numericProjectileId = tonumber(projectileId) or 1
    client.projectileVisualState.byId[projectileId] = {
        id = projectileId, position = Vec(px or 0, py or 0, pz or 0), lastPosition = Vec(px or 0, py or 0, pz or 0),
        velocity = velocity, direction = direction, rightAxis = rightAxis, upAxis = upAxis,
        lifeRemain = tonumber(lifeRemain) or 0.0, age = 0.0, distanceTravelled = 0.0,
        nextTrailDistance = 0.0, nextPulseDistance = 20.0, randomState = numericProjectileId * 977 + 131,
        weaponType = tostring(weaponType or ""), fxProfile = tostring(definition.fxProfile or "kineticProjectile"),
        fxVariant = tostring(definition.projectileFxVariant or definition.fxProfile or "kineticProjectile"),
        impactFxProfile = tostring(definition.impactFxProfile or ""),
        fxColor = definition.fxColor,
    }
    client.spawnWeaponMuzzleFx(weaponType, px, py, pz, vx, vy, vz)
end

local function _spawnKineticImpact(position, projectile, impactNormal, impactLayer)
    local direction, right, up = projectile.direction, projectile.rightAxis, projectile.upAxis
    local impactProfile = projectile.impactFxProfile or ""
    local gauss = impactProfile == "gaussLarge" or impactProfile == "gaussMedium"
    local autocannon = impactProfile == "autocannonLarge" or impactProfile == "autocannonMedium"
    local r0, g0, b0 = gauss and 0.45 or 1.0, gauss and 0.82 or 0.82, gauss and 1.0 or 0.16
    if impactLayer == "shield" then r0, g0, b0 = 0.20, 0.85, 1.0 end
    ParticleReset(); ParticleType("plain")
    ParticleColor(r0, g0, b0, r0, g0 * 0.25, b0 * 0.08)
    ParticleRadius(autocannon and 0.08 or 0.14, 0.01, "easeout"); ParticleAlpha(1.0, 0.0, "easeout")
    ParticleGravity(0); ParticleDrag(0.08); ParticleEmissive(10.0, 0.0); ParticleStretch(2.2, 0.4, "easeout"); ParticleCollide(0)
    for _ = 1, autocannon and 8 or 18 do
        if not _takeParticleBudget("impactParticles", 1) then break end
        local spread = VecAdd(VecScale(right, _randomRange(projectile, -0.65, 0.65)), VecScale(up, _randomRange(projectile, -0.65, 0.65)))
        local out = _safeNormalize(VecAdd(impactNormal or VecScale(direction, -1.0), spread), VecScale(direction, -1.0))
        SpawnParticle(position, VecScale(out, _randomRange(projectile, 8, 22)), _randomRange(projectile, 0.15, 0.35))
    end
end

local function _emitPlasmaLeak(projectile, position)
    if not _takeParticleBudget("trailParticles", 2) then return end
    ParticleReset(); ParticleType("plain")
    ParticleColor(0.45, 1.0, 0.42, 0.01, 0.28, 0.03)
    ParticleRadius(0.32, 0.82, "easeout"); ParticleAlpha(0.82, 0.0, "easeout")
    ParticleGravity(0); ParticleDrag(0.38); ParticleEmissive(18.0, 0.0); ParticleRotation(5.0, -2.0, "easeout"); ParticleStretch(0.20, 0.0); ParticleCollide(0)
    for index = 0, 1 do
        local phase = projectile.age * 9.0 + projectile.id * 0.731 + index * math.pi
        local radial = VecAdd(VecScale(projectile.rightAxis, math.cos(phase)), VecScale(projectile.upAxis, math.sin(phase)))
        local tangent = VecAdd(VecScale(projectile.rightAxis, -math.sin(phase)), VecScale(projectile.upAxis, math.cos(phase)))
        local offset = VecAdd(VecScale(radial, 0.42), VecAdd(VecScale(projectile.rightAxis, _randomRange(projectile, -0.10, 0.10)), VecScale(projectile.upAxis, _randomRange(projectile, -0.10, 0.10))))
        local velocity = VecAdd(VecScale(projectile.direction, -_randomRange(projectile, 2, 5)), VecAdd(VecScale(tangent, _randomRange(projectile, 1.5, 3.5)), VecScale(radial, _randomRange(projectile, 0.5, 2))))
        SpawnParticle(VecAdd(position, offset), velocity, _randomRange(projectile, 0.38, 0.65))
    end
end

local function _emitNeutronPulse(projectile, position)
    if not _takeParticleBudget("trailParticles", 8) then return end
    ParticleReset(); ParticleType("plain")
    ParticleColor(0.65, 0.92, 1.0, 0.02, 0.16, 0.85)
    ParticleRadius(0.15, 0.02, "easeout"); ParticleAlpha(0.90, 0.0, "easeout")
    ParticleGravity(0); ParticleDrag(0.08); ParticleEmissive(15.0, 0.0); ParticleStretch(0); ParticleCollide(0)
    for index = 0, 7 do
        local angle = 2 * math.pi * index / 8
        local radial = VecAdd(VecScale(projectile.rightAxis, math.cos(angle)), VecScale(projectile.upAxis, math.sin(angle)))
        SpawnParticle(VecAdd(position, VecScale(radial, 0.35)), VecAdd(VecScale(radial, 10), VecScale(projectile.direction, -1)), 0.20)
    end
end

local function _updateKineticProjectile(projectile, previousDistance, moveLength, cameraDistance)
    local gauss = projectile.fxVariant == "gaussLarge" or projectile.fxVariant == "gaussMedium"
    local autocannon = projectile.fxVariant == "autocannonLarge" or projectile.fxVariant == "autocannonMedium"
    local tail = autocannon and 3.5 or (gauss and 9.5 or 7.5)
    local r, g, b = gauss and 0.35 or 1.0, gauss and 0.78 or 0.45, gauss and 1.0 or 0.08
    if cameraDistance <= 700 then
        local startPos = VecSub(projectile.position, VecScale(projectile.direction, tail))
        local endPos = VecAdd(projectile.position, VecScale(projectile.direction, 0.4))
        _drawLine(startPos, endPos, r, g, b, autocannon and 0.55 or 0.80)
        _drawLine(VecLerp(startPos, endPos, 0.10), endPos, 1.0, 1.0, 1.0, 1.0)
    end
    if cameraDistance <= 250 then
        _emitDistanceEvents(projectile, projectile.lastPosition, projectile.position, "nextTrailDistance", autocannon and 28.0 or (gauss and 14.0 or 18.0), 2, function(p, eventPos)
            if not _takeParticleBudget("trailParticles", 1) then return end
            ParticleReset(); ParticleType("plain")
            ParticleColor(r, g, b, r, g * 0.25, b * 0.08)
            ParticleRadius(0.10, 0.01, "easeout"); ParticleAlpha(0.90, 0.0, "easeout")
            ParticleGravity(0); ParticleDrag(0.08); ParticleEmissive(8.0, 0.0); ParticleStretch(2.0, 0.4, "easeout"); ParticleCollide(0)
            local velocity = VecAdd(VecScale(p.direction, -12), VecAdd(VecScale(p.rightAxis, _randomRange(p, -2, 2)), VecScale(p.upAxis, _randomRange(p, -2, 2))))
            SpawnParticle(eventPos, velocity, _randomRange(p, 0.10, 0.18))
        end)
    end
end

local function _updatePlasmaProjectile(projectile, cameraDistance)
    local tint = projectile.fxColor or { 0.18, 1.0, 0.30 }
    local flicker = math.max(0.80, math.min(1.10, 0.90 + 0.07 * math.sin(projectile.age * 19 + projectile.id) + 0.03 * math.sin(projectile.age * 41 + projectile.id * 0.37)))
    if cameraDistance <= 900 then
        local a = client.projectileVisualState.assets
        _drawBillboard(a.plasmaGlow, projectile.position, 2.60 * flicker, 2.60 * flicker, tint[1] * 0.12, tint[2] * 0.35, tint[3] * 0.06, 0.42)
        _drawBillboard(a.plasmaGlow, projectile.position, 1.55 * flicker, 1.55 * flicker, tint[1] * 0.55, tint[2] * 0.95, tint[3] * 0.20, 0.72)
        _drawBillboard(a.plasmaCore, projectile.position, 0.95, 0.95, tint[1] * 0.75, tint[2] * 1.50, tint[3] * 0.80, 1.0)
    end
    if cameraDistance <= 240 then _pointLight(projectile.position, tint[1], tint[2], tint[3], 11.0 * flicker) end
    if cameraDistance <= 380 then
        _emitDistanceEvents(projectile, projectile.lastPosition, projectile.position, "nextTrailDistance", 4.0, 8, _emitPlasmaLeak)
    end
end

local function _updateNeutronProjectile(projectile, cameraDistance)
    local tint = projectile.fxColor or { 0.18, 0.58, 1.0 }
    if cameraDistance <= 1000 then
        local startPos = VecSub(projectile.position, VecScale(projectile.direction, 5.0))
        local endPos = VecAdd(projectile.position, VecScale(projectile.direction, 0.5))
        _drawDirectionalSprite(client.projectileVisualState.assets.neutronNeedle, startPos, endPos, 0.20, tint[1] * 0.28, tint[2] * 0.60, tint[3] * 1.40, 0.80)
        _drawLine(VecSub(projectile.position, VecScale(projectile.direction, 3.5)), VecAdd(projectile.position, VecScale(projectile.direction, 0.3)), math.min(1.0, tint[1] * 1.4), math.min(1.0, tint[2] * 1.4), math.min(1.0, tint[3] * 1.2), 1.0)
    end
    if cameraDistance <= 260 then _pointLight(projectile.position, tint[1], tint[2], tint[3], 9.0) end
    if cameraDistance <= 500 then
        _emitDistanceEvents(projectile, projectile.lastPosition, projectile.position, "nextPulseDistance", 38.0, 4, _emitNeutronPulse)
    end
end

-- Giga Cannon deliberately keeps a separate purple energy identity. It does not
-- share either the kinetic tracer or the three target weapon profiles.
local function _updateGigaCannonProjectile(projectile, cameraDistance)
    if cameraDistance > 800 then return end
    if cameraDistance <= 360 then
        _pointLight(projectile.position, 0.50, 0.08, 1.0, 10.0)
        _emitDistanceEvents(projectile, projectile.lastPosition, projectile.position, "nextTrailDistance", 2.0, 6, function(p, eventPos)
            if not _takeParticleBudget("trailParticles", 1) then return end
            ParticleReset(); ParticleType("plain")
            ParticleColor(0.90, 0.44, 1.0, 0.34, 0.04, 0.78)
            ParticleRadius(0.62, 0.02, "easeout"); ParticleAlpha(0.96, 0.0, "easeout")
            ParticleGravity(0); ParticleDrag(0.24); ParticleEmissive(38.0, 0.0); ParticleCollide(0)
            SpawnParticle(eventPos, VecScale(p.direction, 5.0), 0.38)
        end)
    end
    local assets = client.projectileVisualState.assets
    _drawBillboard(assets.impactGlow, projectile.position, 3.6, 3.6, 0.58, 0.10, 1.0, 0.55)
    _drawBillboard(assets.plasmaCore, projectile.position, 0.72, 0.72, 1.0, 1.0, 1.0, 1.0)
end

local function _spawnGigaImpact(position, projectile)
    ParticleReset(); ParticleType("plain")
    ParticleColor(0.92, 0.48, 1.0, 0.26, 0.03, 0.72)
    ParticleRadius(0.68, 0.04, "easeout"); ParticleAlpha(0.96, 0.0, "easeout")
    ParticleGravity(0); ParticleDrag(0.12); ParticleEmissive(36, 0); ParticleCollide(0)
    for _ = 1, 26 do
        if not _takeParticleBudget("impactParticles", 1) then break end
        local direction = _safeNormalize(Vec(_randomRange(projectile, -1, 1), _randomRange(projectile, -1, 1), _randomRange(projectile, -1, 1)), projectile.direction)
        SpawnParticle(position, VecScale(direction, _randomRange(projectile, 3, 8)), _randomRange(projectile, 0.35, 0.70))
    end
    _pointLight(position, 0.70, 0.14, 1.0, 16)
end

local function _queueImpact(impact)
    local impacts = client.projectileVisualState.impacts
    if #impacts >= IMPACT_LIMIT then table.remove(impacts, 1) end
    table.insert(impacts, impact)
end

local function _spawnPlasmaImpactParticles(impact)
    if impact.initialParticlesSpawned then return end
    impact.initialParticlesSpawned = true
    ParticleReset(); ParticleType("plain")
    ParticleColor(0.75, 1.0, 0.65, 0.01, 0.25, 0.02)
    ParticleRadius(0.32, 0.72, "easeout"); ParticleAlpha(1.0, 0.0, "easeout")
    ParticleGravity(0); ParticleDrag(0.30); ParticleEmissive(24.0, 0.0); ParticleRotation(8.0, -3.0, "easeout"); ParticleCollide(0)
    for index = 1, 28 do
        if not _takeParticleBudget("impactParticles", 1) then break end
        local base = index <= 20 and VecScale(impact.direction, -1) or Vec(0, 0, 0)
        local spread = VecAdd(
            VecScale(impact.rightAxis, _randomRange(impact, -1, 1)),
            VecScale(impact.upAxis, _randomRange(impact, -1, 1))
        )
        local out = _safeNormalize(VecAdd(base, spread), impact.direction)
        SpawnParticle(impact.position, VecScale(out, _randomRange(impact, 4, 13)), _randomRange(impact, 0.35, 0.75))
    end
end

local function _spawnNeutronImpactRing(impact, count, radius, speed, life, r0, g0, b0, r1, g1, b1)
    if not _takeParticleBudget("impactParticles", count) then return end
    ParticleReset(); ParticleType("plain")
    ParticleColor(r0, g0, b0, r1, g1, b1); ParticleRadius(0.15, 0.02, "easeout"); ParticleAlpha(0.95, 0.0, "easeout")
    ParticleGravity(0); ParticleDrag(0.08); ParticleEmissive(16, 0); ParticleCollide(0)
    for index = 0, count - 1 do
        local angle = 2 * math.pi * index / count
        local radial = VecAdd(VecScale(impact.rightAxis, math.cos(angle)), VecScale(impact.upAxis, math.sin(angle)))
        SpawnParticle(VecAdd(impact.position, VecScale(radial, radius)), VecScale(radial, speed), life)
    end
end

local function _updateProjectileImpacts(dt)
    local impacts = client.projectileVisualState.impacts
    for index = #impacts, 1, -1 do
        local impact = impacts[index]
        local previousAge = impact.age or 0
        impact.age = previousAge + (dt or 0)
        if impact.impactFxProfile == "plasmaLarge" or impact.impactFxProfile == "plasmaMedium" then
            _spawnPlasmaImpactParticles(impact)
            local t = math.min(1, impact.age / impact.lifetime)
            local ease = 1 - (1 - t) ^ 3
            local size, alpha = 0.8 + ease * 5.2, (1 - t) ^ 2
            local a = client.projectileVisualState.assets
            _drawBillboard(a.impactGlow, impact.position, size, size, 0.02, 0.55, 0.08, alpha * 0.55)
            _drawBillboard(a.plasmaCore, impact.position, size * 0.42, size * 0.42, 0.75, 1.3, 0.70, alpha)
            if _cameraDistance(impact.position) <= 300 then _pointLight(impact.position, 0.10, 1.0, 0.18, 16 * alpha) end
        elseif impact.impactFxProfile == "neutronImpact" then
            if not impact.firstRingSpawned then impact.firstRingSpawned = true; _spawnNeutronImpactRing(impact, 14, 0.25, 14, 0.28, 0.65, 0.92, 1.0, 0.02, 0.16, 0.85) end
            if not impact.secondRingSpawned and previousAge < 0.075 and impact.age >= 0.075 then impact.secondRingSpawned = true; _spawnNeutronImpactRing(impact, 12, 0.15, 9, 0.30, 0.25, 0.70, 1.0, 0.02, 0.08, 0.55) end
            if impact.age <= 0.06 then
                local alpha = 1 - impact.age / 0.06
                _drawBillboard(client.projectileVisualState.assets.impactGlow, impact.position, 1.2 * alpha, 1.2 * alpha, 1.4, 1.4, 1.5, 1.0)
                _pointLight(impact.position, 0.82, 0.96, 1.0, 22 * alpha)
            end
            if impact.age <= 0.18 then
                _drawLine(VecSub(impact.position, VecScale(impact.direction, 12)), VecAdd(impact.position, impact.direction), 0.55, 0.86, 1.0, 1 - impact.age / 0.18)
            end
        end
        if impact.age >= impact.lifetime then table.remove(impacts, index) end
    end
end

function client.finishProjectileVisual(projectileId, mode, hitX, hitY, hitZ, nx, ny, nz, impactLayer)
    local visuals = client.projectileVisualState.byId
    local projectile = visuals[projectileId]
    visuals[projectileId] = nil
    if mode ~= "impact" or projectile == nil then return end
    local position = Vec(hitX or 0, hitY or 0, hitZ or 0)
    local impactNormal = _safeNormalize(Vec(nx or 0, ny or 1, nz or 0), Vec(0, 1, 0))
    local impactProfile = projectile.impactFxProfile
    if impactProfile == "" then
        impactProfile = projectile.fxProfile == "plasmaProjectile" and "plasmaLarge"
            or (projectile.fxProfile == "neutronProjectile" and "neutronImpact" or "kineticArtillery")
    end
    if impactProfile == "plasmaLarge" or impactProfile == "plasmaMedium" then
        _queueImpact({ impactFxProfile = impactProfile, fxColor = projectile.fxColor, position = position, direction = projectile.direction, rightAxis = projectile.rightAxis, upAxis = projectile.upAxis, age = 0, lifetime = 0.65, randomState = projectile.randomState, initialParticlesSpawned = false })
    elseif impactProfile == "neutronImpact" then
        _queueImpact({ impactFxProfile = impactProfile, fxColor = projectile.fxColor, position = position, direction = projectile.direction, rightAxis = projectile.rightAxis, upAxis = projectile.upAxis, age = 0, lifetime = 0.42, randomState = projectile.randomState, firstRingSpawned = false, secondRingSpawned = false })
    elseif impactProfile == "gigaPenetration" then
        _spawnGigaImpact(position, projectile)
    else
        projectile.impactFxProfile = impactProfile
        _spawnKineticImpact(position, projectile, impactNormal, impactLayer)
    end
end

function client.projectileVisualTick(dt)
    local state = client.projectileVisualState
    for projectileId, projectile in pairs(state.byId) do
        local stepDt = math.min(math.max(projectile.lifeRemain or 0, 0), math.max(dt or 0, 0))
        if stepDt <= 0 then
            state.byId[projectileId] = nil
        else
            projectile.lastPosition = Vec(projectile.position[1], projectile.position[2], projectile.position[3])
            projectile.position = VecAdd(projectile.position, VecScale(projectile.velocity, stepDt))
            projectile.lifeRemain = projectile.lifeRemain - (dt or 0); projectile.age = projectile.age + (dt or 0)
            local previousDistance = projectile.distanceTravelled or 0
            local cameraDistance = _cameraDistance(projectile.position)
            if projectile.fxProfile == "plasmaProjectile" then _updatePlasmaProjectile(projectile, cameraDistance)
            elseif projectile.fxProfile == "neutronProjectile" then _updateNeutronProjectile(projectile, cameraDistance)
            elseif projectile.fxProfile == "gigaCannonProjectile" then _updateGigaCannonProjectile(projectile, cameraDistance)
            else _updateKineticProjectile(projectile, previousDistance, VecLength(VecSub(projectile.position, projectile.lastPosition)), cameraDistance) end
            projectile.distanceTravelled = previousDistance + VecLength(VecSub(projectile.position, projectile.lastPosition))
            if projectile.lifeRemain <= 0 then state.byId[projectileId] = nil end
        end
    end
    _updateProjectileImpacts(dt)
end
