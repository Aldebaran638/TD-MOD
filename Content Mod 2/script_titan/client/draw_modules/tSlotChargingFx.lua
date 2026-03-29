-- t-slot charging fx module
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.tSlotChargingFxState = client.tSlotChargingFxState or {
    chargeStateByShip = {},
    lastRenderSeqByShip = {},
    lastShotIdByShip = {},
    activeParticles = {},
}

local function _tableToVec(t)
    if t == nil then return Vec(0, 0, 0) end
    return Vec(t.x or 0, t.y or 0, t.z or 0)
end

local function _safeNormalize(v, fallback)
    local len = VecLength(v)
    if len < 0.0001 then
        return fallback or Vec(0, 0, -1)
    end
    return VecScale(v, 1.0 / len)
end

local function _vecLerp(a, b, t)
    return Vec(
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t
    )
end

local function _clearChargeState(shipBodyId)
    client.tSlotChargingFxState.chargeStateByShip[shipBodyId] = nil
end

local function _beginPerditionBeamChargeState(shipBodyId, render)
    local shipT = GetBodyTransform(shipBodyId)
    local fireWorld = _tableToVec(render.firePoint)
    local fireLocal = TransformToLocalPoint(shipT, fireWorld)
    client.tSlotChargingFxState.chargeStateByShip[shipBodyId] = {
        weaponType = tostring(render.weaponType or ""),
        slotIndex = math.floor(render.slotIndex or 1),
        phase = "charging",
        fireLocal = fireLocal,
        chargeStartedAt = (GetTime ~= nil) and GetTime() or 0.0,
    }
end

local function _createParticle(spawnPos, targetPoint, initialVel, finalVel, life)
    local particles = client.tSlotChargingFxState.activeParticles
    if #particles >= 1000 then
        return
    end
    
    local particle = {
        pos = Vec(spawnPos[1], spawnPos[2], spawnPos[3]),
        vel = Vec(initialVel[1], initialVel[2], initialVel[3]),
        targetPoint = Vec(targetPoint[1], targetPoint[2], targetPoint[3]),
        initialVel = Vec(initialVel[1], initialVel[2], initialVel[3]),
        finalVel = Vec(finalVel[1], finalVel[2], finalVel[3]),
        maxLife = life,
        startTime = (GetTime ~= nil) and GetTime() or 0.0,
        arrived = false,
        arrivedTime = 0.0,
        baseRadius = 0.1,
    }
    table.insert(client.tSlotChargingFxState.activeParticles, particle)
end

local function _updateParticles(dt)
    local particles = client.tSlotChargingFxState.activeParticles
    local i = #particles
    
    while i >= 1 do
        local p = particles[i]
        
        local elapsed = ((GetTime ~= nil) and GetTime() or 0.0) - p.startTime
        local t = elapsed / math.max(0.0001, p.maxLife)
        
        local distToTarget = VecLength(VecSub(p.targetPoint, p.pos))
        
        if not p.arrived and distToTarget < 1.0 then
            p.arrived = true
            p.arrivedTime = (GetTime ~= nil) and GetTime() or 0.0
        end
        
        if p.arrived then
            local arrivedElapsed = ((GetTime ~= nil) and GetTime() or 0.0) - p.arrivedTime
            local arrivedT = arrivedElapsed / 0.4
            
            if arrivedT >= 1.0 then
                particles[i] = particles[#particles]
                particles[#particles] = nil
            else
                local alpha = 1.0 - arrivedT
                local radius = p.baseRadius * 8.0
                
                ParticleReset()
                ParticleColor(1.0, 0.9, 0.5, 1.0, 0.6, 0.2)
                ParticleRadius(radius, 0.02, "easeout")
                ParticleAlpha(alpha * 1.0, 0.0)
                ParticleGravity(0.0)
                ParticleDrag(0.0)
                ParticleEmissive(50.0 + alpha * 30.0, 0.0)
                ParticleCollide(0.0)
                
                local randomVel = Vec(
                    (math.random() - 0.5) * 0.1,
                    (math.random() - 0.5) * 0.1,
                    (math.random() - 0.5) * 0.1
                )
                SpawnParticle(p.pos, randomVel, 0.1)
            end
        else
            if t >= 1.0 then
                particles[i] = particles[#particles]
                particles[#particles] = nil
            else
                local distToXZPlane = math.abs(p.pos[2] - p.targetPoint[2])
                
                local toTargetDir = VecSub(p.targetPoint, p.pos)
                toTargetDir = _safeNormalize(toTargetDir, Vec(0, 0, 0))
                
                local maxDist = 7.0
                local distRatio = math.min(1.0, distToXZPlane / maxDist)
                
                local minYSpeed = 3.33
                local maxYSpeed = 13.6
                local ySpeed = minYSpeed + math.pow(distRatio, 0.25) * (maxYSpeed - minYSpeed)
                
                local xzSpeed = (1.0 - distRatio) * 5.6 + 0.93
                
                local xzDir = Vec(toTargetDir[1], 0, toTargetDir[3])
                xzDir = _safeNormalize(xzDir, Vec(0, 0, 0))
                
                p.vel = Vec(
                    xzDir[1] * xzSpeed,
                    toTargetDir[2] * ySpeed,
                    xzDir[3] * xzSpeed
                )
                
                p.pos = VecAdd(p.pos, VecScale(p.vel, dt))
                
                local radius = p.baseRadius + t * 0.2
                
                local alpha = 1.0 - t
                ParticleReset()
                ParticleColor(1.0, 0.8, 0.2, 1.0, 0.4, 0.0)
                ParticleRadius(radius, 0.01, "easeout")
                ParticleAlpha(alpha * 0.9, 0.0)
                ParticleGravity(0.0)
                ParticleDrag(0.0)
                ParticleEmissive(25.0 + alpha * 15.0, 0.0)
                ParticleCollide(0.0)
                
                local randomVel = Vec(
                    (math.random() - 0.5) * 0.1,
                    (math.random() - 0.5) * 0.1,
                    (math.random() - 0.5) * 0.1
                )
                SpawnParticle(p.pos, randomVel, 0.1)
            end
        end
        
        i = i - 1
    end
end

local function _spawnChargingParticles(shipBodyId, chargeState, frameDt)
    local shipT = GetBodyTransform(shipBodyId)
    local fireLocal = chargeState.fireLocal or Vec(0, 0, 0)
    local fireWorld = TransformToParentPoint(shipT, fireLocal)
    local barrelDir = _safeNormalize(TransformToParentVec(shipT, Vec(0, 0, -1)), Vec(0, 0, -1))
    local segmentLength = 11.5
    local segmentEnd = VecAdd(fireWorld, VecScale(barrelDir, segmentLength))
    
    local divisions = 10
    local points = {}
    for i = 0, divisions do
        local t = i / divisions
        points[i] = VecAdd(fireWorld, VecScale(VecSub(segmentEnd, fireWorld), t))
    end
    
    local particleCount = math.max(1, math.floor((1.05) * math.max(0.68, (frameDt or 0.016) * 60.0)))
    
    local shipRight = TransformToParentVec(shipT, Vec(1, 0, 0))
    
    for pointIndex = 0, divisions - 1 do
        local targetPoint = points[pointIndex]
        
        local angleRanges
        if pointIndex <= 7 then
            angleRanges = {
                {math.rad(30), math.rad(150)},
                {math.rad(-150), math.rad(-30)}
            }
        else
            angleRanges = {
                {math.rad(0), math.rad(150)},
                {math.rad(-150), math.rad(0)}
            }
        end
        
        for _ = 1, particleCount do
            local rangeIndex = math.random(1, 2)
            local minAngle = angleRanges[rangeIndex][1]
            local maxAngle = angleRanges[rangeIndex][2]
            
            local angle = minAngle + math.random() * (maxAngle - minAngle)
            
            local radius = 3.0 + math.random() * 3.0
            
            local yOffset
            if math.random() < 0.5 then
                yOffset = -7.0 + math.random() * 5.0
            else
                yOffset = 2.0 + math.random() * 5.0
            end
            
            local cosAngle = math.cos(angle)
            local sinAngle = math.sin(angle)
            
            local dir = VecAdd(VecScale(barrelDir, cosAngle), VecScale(shipRight, sinAngle))
            dir = _safeNormalize(dir, barrelDir)
            
            local spawnPos = VecAdd(targetPoint, VecScale(dir, radius))
            spawnPos[2] = spawnPos[2] + yOffset
            
            local yVel = -yOffset * 0.8
            local initialVel = Vec(0, yVel, 0)
            
            local velDir = VecSub(targetPoint, spawnPos)
            velDir = _safeNormalize(velDir, barrelDir)
            local finalSpeed = 5.0 + math.random() * 5.0
            local finalVel = VecScale(velDir, finalSpeed)
            
            local life = 2.0 + math.random() * 1.0
            
            _createParticle(spawnPos, targetPoint, initialVel, finalVel, life)
        end
        
        PointLight(targetPoint, 1.0, 0.8, 0.2, 4.0)
    end
end

function client.tSlotChargingFxTick(dt)
    local state = client.tSlotChargingFxState
    local frameDt = dt or 0.0
    
    _updateParticles(frameDt)

    local shipIds = client.registryShipGetRegisteredBodyIds()
    for i = 1, #shipIds do
        local shipBodyId = shipIds[i]
        if client.registryShipExists(shipBodyId) then
            local render = client.tSlotRenderGetEvent(shipBodyId)
            if render ~= nil then
                local seq = render.seq or -1
                local shotId = render.shotId or -1
                local lastSeq = state.lastRenderSeqByShip[shipBodyId] or -1

                if seq ~= lastSeq then
                    if render.weaponType == "perditionBeam" then
                        if render.eventType == "charging_start" or render.eventType == "charged_hold" then
                            _beginPerditionBeamChargeState(shipBodyId, render)
                        else
                            _clearChargeState(shipBodyId)
                        end
                    else
                        _clearChargeState(shipBodyId)
                    end

                    state.lastRenderSeqByShip[shipBodyId] = seq
                    state.lastShotIdByShip[shipBodyId] = shotId
                end
            end
        else
            _clearChargeState(shipBodyId)
        end
    end

    for shipBodyId, chargeState in pairs(state.chargeStateByShip) do
        if not client.registryShipExists(shipBodyId) then
            state.chargeStateByShip[shipBodyId] = nil
        else
            _spawnChargingParticles(shipBodyId, chargeState, frameDt)
        end
    end
end
