---@diagnostic disable: undefined-global

-- Shared T-slot visual event protocol. It deliberately contains no weapon logic.
server = server or {}
server.tSlotRenderState = server.tSlotRenderState or { seq = 0, shotId = 0 }

local function _vec(v, x, y, z)
    v = v or {}
    return { v.x or v[1] or x, v.y or v[2] or y, v.z or v[3] or z }
end

function server.tSlotRenderPushEvent(shipBodyId, payload, publishThroughBoundary)
    local body = math.floor(shipBodyId or 0)
    if body <= 0 then return false end
    local state = server.tSlotRenderState
    state.seq = math.floor((state.seq or 0) + 1)
    local p = payload or {}
    if p.incrementShotId then state.shotId = math.floor((state.shotId or 0) + 1) end
    local fire, hit, normal = _vec(p.firePoint, 0, 0, 0), _vec(p.hitPoint, 0, 0, 0), _vec(p.normal, 0, 1, 0)
    local routeArgs = { body, state.seq, state.shotId or 0,
        tostring(p.eventType or "idle"), math.floor(p.slotIndex or 1), tostring(p.weaponType or ""),
        (GetTime ~= nil and GetTime() or 0), fire[1], fire[2], fire[3], hit[1], hit[2], hit[3],
        p.didHit and 1 or 0, p.didHitStellarisBody and 1 or 0, p.didHitShield and 1 or 0,
        math.floor(p.hitTargetBodyId or 0), normal[1], normal[2], normal[3], tostring(p.impactLayer or "none") }
    if publishThroughBoundary and server.presentationPublisherPublish ~= nil then
        local published = server.presentationPublisherPublish("beam", {
            sourceBodyId = body,
            weaponType = p.weaponType,
            effectId = p.weaponType,
            position = fire,
            targetId = p.hitTargetBodyId,
            hit = { position = hit, normal = normal },
            payload = {
                eventType = tostring(p.eventType or "idle"),
                slotIndex = math.floor(p.slotIndex or 1),
                shotId = state.shotId or 0,
                didHit = p.didHit and 1 or 0,
                didHitStellarisBody = p.didHitStellarisBody and 1 or 0,
                didHitShield = p.didHitShield and 1 or 0,
                impactLayer = tostring(p.impactLayer or "none"),
            },
            route = "tSlot.render",
            routeArgs = routeArgs,
        })
        if published then return true end
    end
    local unpackFunction = table.unpack or unpack
    ClientCall(0, "client.receiveTSlotRenderEvent", unpackFunction(routeArgs))
    return true
end
