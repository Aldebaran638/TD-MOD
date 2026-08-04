-- Perdition Beam's original Titan charge effect. This intentionally owns its
-- own particle pool so the Titan muzzle is never throttled by the shared
-- weapon-FX budget.
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.perditionChargingFxState = client.perditionChargingFxState or {
    chargeStateByShip = {},
    lastRenderSeqByShip = {},
    activeParticles = {},
    maxActiveParticles = 1000,
}

local function _tableToVec(value)
    if value == nil then return Vec(0, 0, 0) end
    return Vec(value.x or 0, value.y or 0, value.z or 0)
end

local function _safeNormalize(value, fallback)
    local length = VecLength(value)
    if length < 0.0001 then return fallback or Vec(0, 0, -1) end
    return VecScale(value, 1.0 / length)
end

local function _clearChargeState(shipBodyId)
    client.perditionChargingFxState.chargeStateByShip[shipBodyId] = nil
end

local function _beginChargeState(shipBodyId, render)
    local shipTransform = GetBodyTransform(shipBodyId)
    client.perditionChargingFxState.chargeStateByShip[shipBodyId] = {
        fireLocal = TransformToLocalPoint(shipTransform, _tableToVec(render.firePoint)),
    }
end

local function _createParticle(shipBodyId, shipTransform, spawnPoint, targetPoint, life)
    local state = client.perditionChargingFxState
    if #state.activeParticles >= state.maxActiveParticles then return end
    table.insert(state.activeParticles, {
        shipBodyId = shipBodyId,
        posLocal = TransformToLocalPoint(shipTransform, spawnPoint),
        targetLocal = TransformToLocalPoint(shipTransform, targetPoint),
        life = life,
        startedAt = (GetTime ~= nil) and GetTime() or 0.0,
        arrived = false,
        arrivedAt = 0.0,
    })
end

local function _updateParticles(dt)
    local particles = client.perditionChargingFxState.activeParticles
    local index = #particles
    while index >= 1 do
        local particle = particles[index]
        local remove = false
        local shipBodyId = particle.shipBodyId
        if shipBodyId == nil or shipBodyId == 0
            or (IsHandleValid ~= nil and not IsHandleValid(shipBodyId)) then
            remove = true
        else
            local shipTransform = GetBodyTransform(shipBodyId)
            local position = TransformToParentPoint(shipTransform, particle.posLocal)
            local target = TransformToParentPoint(shipTransform, particle.targetLocal)
            local elapsed = ((GetTime ~= nil) and GetTime() or 0.0) - particle.startedAt
            local lifeProgress = elapsed / math.max(0.0001, particle.life)
            local distance = VecLength(VecSub(target, position))

            if not particle.arrived and distance < 1.0 then
                particle.arrived = true
                particle.arrivedAt = (GetTime ~= nil) and GetTime() or 0.0
            end

            if particle.arrived then
                local fade = (((GetTime ~= nil) and GetTime() or 0.0) - particle.arrivedAt) / 0.4
                if fade >= 1.0 then
                    remove = true
                else
                    local alpha = 1.0 - fade
                    ParticleReset()
                    ParticleColor(1.0, 0.9, 0.5, 1.0, 0.6, 0.2)
                    ParticleRadius(0.8, 0.02, "easeout")
                    ParticleAlpha(alpha, 0.0)
                    ParticleGravity(0.0)
                    ParticleDrag(0.0)
                    ParticleEmissive(50.0 + alpha * 30.0, 0.0)
                    ParticleCollide(0.0)
                    SpawnParticle(position, Vec(
                        (math.random() - 0.5) * 0.1,
                        (math.random() - 0.5) * 0.1,
                        (math.random() - 0.5) * 0.1
                    ), 0.1)
                end
            elseif lifeProgress >= 1.0 then
                remove = true
            else
                local verticalDistance = math.abs(position[2] - target[2])
                local targetDirection = _safeNormalize(VecSub(target, position), Vec(0, 0, 0))
                local distanceRatio = math.min(1.0, verticalDistance / 7.0)
                local verticalSpeed = 3.33 + math.pow(distanceRatio, 0.25) * (13.6 - 3.33)
                local horizontalSpeed = (1.0 - distanceRatio) * 5.6 + 0.93
                local horizontalDirection = _safeNormalize(
                    Vec(targetDirection[1], 0, targetDirection[3]), Vec(0, 0, 0)
                )
                local velocity = Vec(
                    horizontalDirection[1] * horizontalSpeed,
                    targetDirection[2] * verticalSpeed,
                    horizontalDirection[3] * horizontalSpeed
                )
                particle.posLocal = VecAdd(
                    particle.posLocal,
                    VecScale(TransformToLocalVec(shipTransform, velocity), dt)
                )
                position = TransformToParentPoint(shipTransform, particle.posLocal)
                local alpha = 1.0 - lifeProgress
                ParticleReset()
                ParticleColor(1.0, 0.8, 0.2, 1.0, 0.4, 0.0)
                ParticleRadius(0.1 + lifeProgress * 0.2, 0.01, "easeout")
                ParticleAlpha(alpha * 0.9, 0.0)
                ParticleGravity(0.0)
                ParticleDrag(0.0)
                ParticleEmissive(25.0 + alpha * 15.0, 0.0)
                ParticleCollide(0.0)
                SpawnParticle(position, Vec(
                    (math.random() - 0.5) * 0.1,
                    (math.random() - 0.5) * 0.1,
                    (math.random() - 0.5) * 0.1
                ), 0.1)
            end
        end

        if remove then
            particles[index] = particles[#particles]
            particles[#particles] = nil
        end
        index = index - 1
    end
end

local function _spawnOriginalChargeParticles(shipBodyId, chargeState, dt)
    local shipTransform = GetBodyTransform(shipBodyId)
    local firePoint = TransformToParentPoint(shipTransform, chargeState.fireLocal or Vec(0, 0, 0))
    local barrel = _safeNormalize(TransformToParentVec(shipTransform, Vec(0, 0, -1)), Vec(0, 0, -1))
    local endpoint = VecAdd(firePoint, VecScale(barrel, 11.5))
    local points = {}
    for pointIndex = 0, 10 do
        points[pointIndex] = VecAdd(firePoint, VecScale(VecSub(endpoint, firePoint), pointIndex / 10.0))
    end

    local particleCount = math.max(1, math.floor(0.735 * math.max(0.68, (dt or 0.016) * 60.0)))
    local right = TransformToParentVec(shipTransform, Vec(1, 0, 0))
    for pointIndex = 0, 9 do
        local target = points[pointIndex]
        local ranges = pointIndex <= 7 and {
            { math.rad(30), math.rad(150) },
            { math.rad(-150), math.rad(-30) },
        } or {
            { math.rad(0), math.rad(150) },
            { math.rad(-150), math.rad(0) },
        }
        for _ = 1, particleCount do
            local range = ranges[math.random(1, 2)]
            local angle = range[1] + math.random() * (range[2] - range[1])
            local direction = _safeNormalize(VecAdd(
                VecScale(barrel, math.cos(angle)), VecScale(right, math.sin(angle))
            ), barrel)
            local spawn = VecAdd(target, VecScale(direction, 3.0 + math.random() * 3.0))
            local verticalOffset = math.random() < 0.5 and (-7.0 + math.random() * 5.0)
                or (2.0 + math.random() * 5.0)
            spawn[2] = spawn[2] + verticalOffset
            _createParticle(shipBodyId, shipTransform, spawn, target, 2.0 + math.random())
        end
        PointLight(target, 1.0, 0.8, 0.2, 4.0)
    end
end

function client.perditionChargingFxInit()
    client.perditionChargingFxState = {
        chargeStateByShip = {},
        lastRenderSeqByShip = {},
        activeParticles = {},
        maxActiveParticles = 1000,
    }
end

function client.perditionChargingFxTick(dt)
    local state = client.perditionChargingFxState
    local frameDt = dt or 0.016
    _updateParticles(frameDt)

    for _, shipBodyId in ipairs(client.registryShipGetRegisteredBodyIds() or {}) do
        if client.registryShipExists(shipBodyId) then
            local render = client.tSlotRenderGetEvent(shipBodyId)
            if render ~= nil and state.lastRenderSeqByShip[shipBodyId] ~= render.seq then
                if render.weaponType == "perditionBeam"
                    and (render.eventType == "charging_start" or render.eventType == "charged_hold") then
                    _beginChargeState(shipBodyId, render)
                else
                    _clearChargeState(shipBodyId)
                end
                state.lastRenderSeqByShip[shipBodyId] = render.seq
            end
        else
            _clearChargeState(shipBodyId)
            state.lastRenderSeqByShip[shipBodyId] = nil
        end
    end

    for shipBodyId, chargeState in pairs(state.chargeStateByShip) do
        if client.registryShipExists(shipBodyId) then
            _spawnOriginalChargeParticles(shipBodyId, chargeState, frameDt)
        else
            _clearChargeState(shipBodyId)
        end
    end
end

-- The restored implementation is particle-driven; bootstrap still calls a
-- render hook so keep the lifecycle contract explicit.
function client.perditionChargingFxRender()
end
