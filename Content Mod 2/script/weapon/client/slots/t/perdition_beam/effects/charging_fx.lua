---@diagnostic disable: undefined-global

-- Original Titan-style pre-fire energy, driven by authoritative T-slot events.
client = client or {}
client.perditionChargingFxState = client.perditionChargingFxState or { charges = {}, lastSeq = {}, sprite = 0 }

function client.perditionChargingFxInit()
    client.perditionChargingFxState = { charges = {}, lastSeq = {}, sprite = LoadSprite("MOD/gfx/weapons/projectiles/impact_glow.png") }
end

function client.perditionChargingFxTick(dt)
    local state = client.perditionChargingFxState
    local now = GetTime ~= nil and GetTime() or 0
    for _, shipBody in ipairs(client.registryShipGetRegisteredBodyIds()) do
        local event = client.tSlotRenderGetEvent(shipBody)
        if event and state.lastSeq[shipBody] ~= event.seq then
            state.lastSeq[shipBody] = event.seq
            if event.weaponType == "perditionBeam" and event.eventType == "charging_start" then
                state.charges[shipBody] = { startedAt = now, firePoint = Vec(event.firePoint.x, event.firePoint.y, event.firePoint.z) }
            else
                state.charges[shipBody] = nil
            end
        end
    end
end

function client.perditionChargingFxRender()
    local state = client.perditionChargingFxState
    if math.floor(state.sprite or 0) == 0 then return end
    local now = GetTime ~= nil and GetTime() or 0
    for shipBody, charge in pairs(state.charges) do
        if IsHandleValid(shipBody) then
            local elapsed = now - charge.startedAt
            if elapsed >= 1.5 then state.charges[shipBody] = nil else
                local shipT, point = GetBodyTransform(shipBody), charge.firePoint
                local forward = TransformToParentVec(shipT, Vec(0, 0, -1))
                local right = TransformToParentVec(shipT, Vec(1, 0, 0))
                local pulse = 0.70 + 0.30 * math.sin(elapsed * 11)
                for segment = 0, 9 do
                    local target = VecAdd(point, VecScale(forward, segment * 1.15))
                    local angle = now * 6 + segment * 1.7
                    local source = VecAdd(target, VecAdd(VecScale(right, math.cos(angle) * (3.0 + pulse * 2.0)), Vec(0, math.sin(angle * 1.9) * 3.2, 0)))
                    ParticleReset(); ParticleColor(1, .8, .2, 1, .4, 0); ParticleRadius(.13, .02, "easeout"); ParticleAlpha(.9, 0); ParticleGravity(0); ParticleDrag(0); ParticleEmissive(30, 0); ParticleCollide(0)
                    SpawnParticle(source, VecScale(VecSub(target, source), 5.0), .26)
                    PointLight(target, 1, .8, .2, 4.0)
                end
                local transform, size = Transform(point, QuatLookAt(point, GetCameraTransform().pos)), 3.4 + pulse * 2.2
                if client.weaponFxTakeSprite(1) then DrawSprite(state.sprite, transform, size, size, 1, .11, .025, .54, true, true, false) end
            end
        else state.charges[shipBody] = nil end
    end
end
