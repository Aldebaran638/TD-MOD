---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.xSlotRenderState = server.xSlotRenderState or {
    seq = 0,
    shotId = 0,
}

local function _xSlotRenderStateVec3ToArray(v, defaultX, defaultY, defaultZ)
    local t = v or {}
    local x = t.x
    if x == nil then x = t[1] end
    local y = t.y
    if y == nil then y = t[2] end
    local z = t.z
    if z == nil then z = t[3] end

    return {
        x or defaultX or 0.0,
        y or defaultY or 0.0,
        z or defaultZ or 0.0,
    }
end

function server.xSlotRenderStateInit()
    server.xSlotRenderState = {
        seq = 0,
        shotId = 0,
    }
    return server.xSlotRenderState
end

function server.xSlotRenderPushEvent(shipBodyId, payload)
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end

    local state = server.xSlotRenderState
    if state == nil then
        state = server.xSlotRenderStateInit()
    end

    local p = payload or {}
    state.seq = math.floor((state.seq or 0) + 1)

    if math.floor(p.incrementShotId or 0) ~= 0 then
        state.shotId = math.floor((state.shotId or 0) + 1)
    end

    local firePoint = _xSlotRenderStateVec3ToArray(p.firePoint, 0.0, 0.0, 0.0)
    local hitPoint = _xSlotRenderStateVec3ToArray(p.hitPoint, 0.0, 0.0, 0.0)
    local normal = _xSlotRenderStateVec3ToArray(p.normal, 0.0, 1.0, 0.0)
    local impactLayer = tostring(p.impactLayer or "none")
    if impactLayer ~= "none"
        and impactLayer ~= "shield"
        and impactLayer ~= "armor"
        and impactLayer ~= "body"
        and impactLayer ~= "environment" then
        impactLayer = "none"
    end

    ClientCall(
        0,
        "client.receiveXSlotRenderEvent",
        shipBodyId,
        state.seq,
        state.shotId or 0,
        tostring(p.eventType or "idle"),
        math.floor(p.slotIndex or 1),
        tostring(p.weaponType or ""),
        tonumber(p.serverTime) or ((GetTime ~= nil) and GetTime() or 0.0),
        firePoint[1], firePoint[2], firePoint[3],
        hitPoint[1], hitPoint[2], hitPoint[3],
        (p.didHit and 1 or 0),
        (p.didHitStellarisBody and 1 or 0),
        (p.didHitShield and 1 or 0),
        math.floor(p.hitTargetBodyId or 0),
        normal[1], normal[2], normal[3],
        impactLayer
    )

    return true
end
