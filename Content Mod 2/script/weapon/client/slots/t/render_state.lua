---@diagnostic disable: undefined-global

client = client or {}
client.tSlotRenderStateByShip = client.tSlotRenderStateByShip or {}
client.tSlotRenderEventQueueByShip = client.tSlotRenderEventQueueByShip or {}
local _maxTSlotRenderEvents = 24

function client.receiveTSlotRenderEvent(shipBodyId, seq, shotId, eventType, slotIndex, weaponType, serverTime,
    fireX, fireY, fireZ, hitX, hitY, hitZ, didHit, didHitStellarisBody, didHitShield, hitTargetBodyId,
    normalX, normalY, normalZ, impactLayer)
    local body = math.floor(shipBodyId or 0)
    if body <= 0 then return end
    local event = {
        seq = math.floor(seq or 0), shotId = math.floor(shotId or 0), eventType = tostring(eventType or "idle"),
        slotIndex = math.floor(slotIndex or 1), weaponType = tostring(weaponType or ""),
        serverTime = tonumber(serverTime) or 0, firePoint = { x = fireX or 0, y = fireY or 0, z = fireZ or 0 },
        hitPoint = { x = hitX or 0, y = hitY or 0, z = hitZ or 0 }, didHit = math.floor(didHit or 0),
        didHitStellarisBody = math.floor(didHitStellarisBody or 0), didHitShield = math.floor(didHitShield or 0),
        hitTargetBodyId = math.floor(hitTargetBodyId or 0), normal = { x = normalX or 0, y = normalY or 1, z = normalZ or 0 },
        impactLayer = tostring(impactLayer or "none"),
    }
    client.tSlotRenderStateByShip[body] = event
    local queue = client.tSlotRenderEventQueueByShip[body] or {}
    queue[#queue + 1] = event
    while #queue > _maxTSlotRenderEvents do table.remove(queue, 1) end
    client.tSlotRenderEventQueueByShip[body] = queue
end

function client.tSlotRenderGetEvent(shipBodyId)
    return client.tSlotRenderStateByShip[math.floor(shipBodyId or 0)]
end

function client.tSlotRenderGetEvents(shipBodyId, afterSeq)
    local body = math.floor(shipBodyId or 0)
    local minimum = math.floor(afterSeq or -1)
    local result = {}
    for _, event in ipairs(client.tSlotRenderEventQueueByShip[body] or {}) do
        if math.floor(event.seq or 0) > minimum then result[#result + 1] = event end
    end
    return result
end
