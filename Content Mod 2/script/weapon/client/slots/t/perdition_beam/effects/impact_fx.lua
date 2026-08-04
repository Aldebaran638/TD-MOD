---@diagnostic disable: undefined-global

client = client or {}
client.perditionImpactFxState = client.perditionImpactFxState or { lastSeq = {}, impacts = {} }

local function _safeNormalize(value, fallback)
    return client.chargedRaySafeNormalize(value, fallback or Vec(0, 1, 0))
end

local function _surfaceBasis(normal)
    local reference = math.abs(VecDot(normal, Vec(0, 1, 0))) > 0.92 and Vec(1, 0, 0) or Vec(0, 1, 0)
    local tangent = _safeNormalize(VecCross(normal, reference), Vec(1, 0, 0))
    return tangent, _safeNormalize(VecCross(normal, tangent), Vec(0, 0, 1))
end

local function _impactWorldPoint(impact)
    if impact.bodyId ~= 0 and client.registryShipExists(impact.bodyId) and IsHandleValid(impact.bodyId) then
        return TransformToParentPoint(GetBodyTransform(impact.bodyId), impact.localPoint)
    end
    return impact.point
end

local function _impactWorldVector(impact, field)
    local value = impact[field] or impact.normal
    local localField = ({
        back = "localBack", normal = "localNormal",
        tangent = "localTangent", bitangent = "localBitangent",
    })[field] or "localNormal"
    if impact.bodyId ~= 0 and client.registryShipExists(impact.bodyId) and IsHandleValid(impact.bodyId) then
        return _safeNormalize(TransformToParentVec(GetBodyTransform(impact.bodyId), impact[localField] or value), value)
    end
    return value
end

local function _spawnBurst(impact)
    if not client.weaponFxTakeParticles(52, "critical") then return end
    local point = _impactWorldPoint(impact)
    local normal = _impactWorldVector(impact, "normal")
    local tangent = _impactWorldVector(impact, "tangent")
    local bitangent = _impactWorldVector(impact, "bitangent")
    ParticleReset(); ParticleColor(1, 1, 0.78, 1, 0.12, 0.01); ParticleRadius(8.5, 0, "easeout"); ParticleAlpha(1, 0); ParticleGravity(0); ParticleDrag(0); ParticleEmissive(80, 0); ParticleCollide(0)
    SpawnParticle(point, Vec(0, 0, 0), 0.18)
    ParticleReset(); ParticleColor(1, 0.75, 0.22, 0.65, 0.04, 0.005); ParticleRadius(0.40, 0.03, "easeout"); ParticleAlpha(0.95, 0); ParticleGravity(-1); ParticleDrag(0.18); ParticleEmissive(55, 0); ParticleCollide(0)
    for _ = 1, 21 do
        local spread = VecAdd(VecScale(tangent, (math.random() - 0.5) * 0.8), VecScale(bitangent, (math.random() - 0.5) * 0.8))
        SpawnParticle(point, VecScale(_safeNormalize(VecAdd(impact.back, spread), impact.back), 28.0 + math.random() * 36.0), 0.25 + math.random() * 0.28)
    end

end

local function _resolveImpactTangent(normal, incoming)
    local projected = VecSub(incoming, VecScale(normal, VecDot(incoming, normal)))
    local fallbackTangent, fallbackBitangent = _surfaceBasis(normal)
    local tangent = _safeNormalize(projected, fallbackTangent)
    local bitangent = _safeNormalize(VecCross(normal, tangent), fallbackBitangent)
    return tangent, bitangent
end

local function _spawnImpact(event)
    local point, normal, fire = client.chargedRayTableToVec(event.hitPoint), client.chargedRayTableToVec(event.normal), client.chargedRayTableToVec(event.firePoint)
    local bodyId = math.floor(event.hitTargetBodyId or 0)
    local resolvedNormal = _safeNormalize(normal, Vec(0, 1, 0))
    local back = _safeNormalize(VecSub(fire, point), Vec(0, 1, 0))
    local incoming = VecScale(back, -1.0)
    local tangent, bitangent = _resolveImpactTangent(resolvedNormal, incoming)
    local impact = {
        age = 0.0, point = point, bodyId = 0, shipHit = false,
        normal = resolvedNormal, back = back, tangent = tangent, bitangent = bitangent,
        residue = 0.0,
    }
    if event.didHitStellarisBody == 1 and bodyId ~= 0 and client.registryShipExists(bodyId) and IsHandleValid(bodyId) then
        local transform = GetBodyTransform(bodyId)
        impact.bodyId, impact.shipHit, impact.localPoint = bodyId, true, TransformToLocalPoint(transform, point)
        impact.localNormal = TransformToLocalVec(transform, impact.normal)
        impact.localBack = TransformToLocalVec(transform, impact.back)
        impact.localTangent = TransformToLocalVec(transform, impact.tangent)
        impact.localBitangent = TransformToLocalVec(transform, impact.bitangent)
    end
    _spawnBurst(impact)
    local cameraDistance = VecLength(VecSub(GetCameraTransform().pos, point))
    ShakeCamera(math.max(0.0, math.min(1.0, 1.0 - cameraDistance / 110.0)) * 1.1)
    local impacts = client.perditionImpactFxState.impacts
    impacts[#impacts + 1] = impact
    while #impacts > 6 do table.remove(impacts, 1) end
end

function client.perditionImpactFxRender()
end

function client.perditionImpactFxInit()
    client.perditionImpactFxState = { lastSeq = {}, impacts = {} }
end

function client.perditionImpactFxTick(dt)
    local state, delta = client.perditionImpactFxState, math.max(0.0, tonumber(dt) or 0.0)
    for _, shipBodyId in ipairs(client.registryShipGetRegisteredBodyIds() or {}) do
        local event = client.tSlotRenderGetEvent(shipBodyId)
        if event ~= nil and state.lastSeq[shipBodyId] ~= event.seq then
            state.lastSeq[shipBodyId] = event.seq
            if event.weaponType == "perditionBeam" and event.eventType == "launch_start" and event.didHit == 1 then _spawnImpact(event) end
        end
    end
    for index = #state.impacts, 1, -1 do
        local impact = state.impacts[index]
        impact.age, impact.residue = impact.age + delta, impact.residue + delta
        local point = _impactWorldPoint(impact)
        if impact.age < 0.42 then
            local t = impact.age / 0.42
            client.weaponFxPointLight(point, 1.0, 0.18, 0.012, 155.0 * (1.0 - t) * (1.0 - t), 180.0)
        end
        if impact.age < 0.70 and impact.residue >= 0.16 then
            impact.residue = impact.residue - 0.16
            if client.weaponFxTakeParticles(3, "ambient") then
                ParticleReset(); ParticleColor(1, 0.28, 0.02, 0.24, 0.01, 0.001); ParticleRadius(1.2, 0.05, "easeout"); ParticleAlpha(0.55, 0); ParticleGravity(0); ParticleDrag(1.2); ParticleEmissive(18, 0); ParticleCollide(0)
                local normal = _impactWorldVector(impact, "normal")
                for _ = 1, 3 do SpawnParticle(point, VecScale(normal, 2.0 + math.random() * 4.0), 0.35) end
            end
        end
        if impact.age >= 0.70 then table.remove(state.impacts, index) end
    end
end
