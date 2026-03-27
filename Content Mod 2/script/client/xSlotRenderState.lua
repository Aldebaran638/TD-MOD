---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.xSlotRenderStateByShip = client.xSlotRenderStateByShip or {}

local function _xSlotRenderEnsureClientState(shipBodyId)
    local body = math.floor(shipBodyId or 0)
    if body <= 0 then
        return nil
    end

    local states = client.xSlotRenderStateByShip
    local state = states[body]
    if state == nil then
        state = {
            seq = -1,
            shotId = 0,
            eventType = "idle",
            slotIndex = 1,
            weaponType = "",
            serverTime = 0.0,
            firePoint = { x = 0.0, y = 0.0, z = 0.0 },
            hitPoint = { x = 0.0, y = 0.0, z = 0.0 },
            didHit = 0,
            didHitStellarisBody = 0,
            didHitShield = 0,
            hitTargetBodyId = 0,
            normal = { x = 0.0, y = 1.0, z = 0.0 },
            impactLayer = "none",
        }
        states[body] = state
    end
    return state
end

function client.receiveXSlotRenderEvent(
    shipBodyId,
    seq,
    shotId,
    eventType,
    slotIndex,
    weaponType,
    serverTime,
    fireX,
    fireY,
    fireZ,
    hitX,
    hitY,
    hitZ,
    didHit,
    didHitStellarisBody,
    didHitShield,
    hitTargetBodyId,
    normalX,
    normalY,
    normalZ,
    impactLayer
)
    local state = _xSlotRenderEnsureClientState(shipBodyId)
    if state == nil then
        return
    end

    state.seq = math.floor(seq or -1)
    state.shotId = math.floor(shotId or 0)
    state.eventType = tostring(eventType or "idle")
    state.slotIndex = math.floor(slotIndex or 1)
    state.weaponType = tostring(weaponType or "")
    state.serverTime = tonumber(serverTime) or 0.0
    state.firePoint = { x = tonumber(fireX) or 0.0, y = tonumber(fireY) or 0.0, z = tonumber(fireZ) or 0.0 }
    state.hitPoint = { x = tonumber(hitX) or 0.0, y = tonumber(hitY) or 0.0, z = tonumber(hitZ) or 0.0 }
    state.didHit = math.floor(didHit or 0)
    state.didHitStellarisBody = math.floor(didHitStellarisBody or 0)
    state.didHitShield = math.floor(didHitShield or 0)
    state.hitTargetBodyId = math.floor(hitTargetBodyId or 0)
    state.normal = { x = tonumber(normalX) or 0.0, y = tonumber(normalY) or 1.0, z = tonumber(normalZ) or 0.0 }
    state.impactLayer = tostring(impactLayer or "none")
end

function client.xSlotRenderGetEvent(shipBodyId)
    local body = math.floor(shipBodyId or 0)
    if body <= 0 then
        return nil
    end
    return client.xSlotRenderStateByShip[body]
end
