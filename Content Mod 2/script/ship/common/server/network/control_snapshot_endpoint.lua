---@diagnostic disable: undefined-global

server = server or {}
server.shipControlSnapshotStateByPlayer =
    server.shipControlSnapshotStateByPlayer or {}

local function _finite(value)
    local number = tonumber(value)
    return number ~= nil
        and number == number
        and number ~= math.huge
        and number ~= -math.huge
end

local function _clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, tonumber(value) or 0.0))
end

function server.shipReceiveControlSnapshot(
    playerId,
    shipBodyId,
    sequence,
    moveState,
    pitchError,
    yawError,
    rollError,
    weaponAimActive,
    weaponAimYaw,
    weaponAimPitch
)
    server.netDebugCountReceive("input.snapshot")
    local pid = math.floor(tonumber(playerId) or 0)
    local body = math.floor(tonumber(shipBodyId) or 0)
    local seq = math.floor(tonumber(sequence) or 0)
    if not server.shipRequestAuthorize(pid, body) or seq <= 0 then return false end

    local values = {
        moveState, pitchError, yawError, rollError,
        weaponAimActive, weaponAimYaw, weaponAimPitch,
    }
    for i = 1, #values do
        if not _finite(values[i]) then return false end
    end

    local state = server.shipControlSnapshotStateByPlayer[pid] or {
        lastSequence = 0,
        lastAcceptedAt = -1000.0,
        shipBody = body,
    }
    if seq <= math.floor(state.lastSequence or 0) then return false end
    local now = (GetTime ~= nil) and GetTime() or 0.0
    if now - (state.lastAcceptedAt or -1000.0) < 0.02 then return false end

    local move = math.floor(tonumber(moveState) or 0)
    if move < 0 or move > 2 then return false end
    server.shipRuntimeSetMoveRequestState(body, move)
    server.shipRuntimeSetRotationError(
        body,
        _clamp(pitchError, -90.0, 90.0),
        _clamp(yawError, -180.0, 180.0)
    )
    server.shipRuntimeSetRollError(body, _clamp(rollError, -180.0, 180.0))
    server.shipRuntimeSetWeaponAim(
        body,
        math.floor(tonumber(weaponAimActive) or 0) ~= 0,
        _clamp(weaponAimYaw, -180.0, 180.0),
        _clamp(weaponAimPitch, -90.0, 90.0)
    )

    state.lastSequence = seq
    state.lastAcceptedAt = now
    state.shipBody = body
    server.shipControlSnapshotStateByPlayer[pid] = state
    return true
end

function server.shipRequestMoveState(playerId, shipBodyId, moveState)
    server.netDebugCountReceive("input.move")
    if not server.shipRequestAuthorize(playerId, shipBodyId) then return false end
    server.shipRuntimeSetMoveRequestState(
        shipBodyId,
        _clamp(math.floor(moveState or 0), 0, 2)
    )
    return true
end

function server.shipRequestRotationError(playerId, shipBodyId, pitchError, yawError)
    server.netDebugCountReceive("input.rotation")
    if not server.shipRequestAuthorize(playerId, shipBodyId) then return false end
    server.shipRuntimeSetRotationError(
        shipBodyId,
        _finite(pitchError) and pitchError or 0.0,
        _finite(yawError) and yawError or 0.0
    )
    return true
end

function server.shipRequestWeaponAim(playerId, shipBodyId, active, localYaw, localPitch)
    server.netDebugCountReceive("input.aim")
    if not server.shipRequestAuthorize(playerId, shipBodyId) then return false end
    server.shipRuntimeSetWeaponAim(
        shipBodyId,
        math.floor(active or 0) ~= 0,
        _finite(localYaw) and localYaw or 0.0,
        _finite(localPitch) and localPitch or 0.0
    )
    return true
end

function server.shipRequestRollError(playerId, shipBodyId, rollError)
    server.netDebugCountReceive("input.roll")
    if not server.shipRequestAuthorize(playerId, shipBodyId) then return false end
    server.shipRuntimeSetRollError(
        shipBodyId,
        _finite(rollError) and rollError or 0.0
    )
    return true
end
