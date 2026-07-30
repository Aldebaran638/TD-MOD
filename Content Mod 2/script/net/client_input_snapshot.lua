---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.shipControlSnapshotConfig = client.shipControlSnapshotConfig or {
    activeInterval = 0.05,
    idleInterval = 0.20,
    pitchYawThreshold = 0.25,
    rollThreshold = 0.5,
    aimThreshold = 0.25,
}

client.shipControlSnapshot = client.shipControlSnapshot or {
    shipBody = 0,
    moveState = 0,
    pitchError = 0.0,
    yawError = 0.0,
    rollError = 0.0,
    weaponAimActive = false,
    weaponAimYaw = 0.0,
    weaponAimPitch = 0.0,
    fireHeld = false,
    weaponGroup = "",
    sequence = 0,
    lastSentAt = -1000.0,
    lastSent = nil,
    dirty = true,
}

local function _shipControlSafeNumber(value, fallback)
    local number = tonumber(value)
    if number == nil or number ~= number
        or number == math.huge or number == -math.huge then
        return fallback or 0.0
    end
    return number
end

local function _shipControlClamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function _shipControlResolveDrivenBody()
    local playerId = GetLocalPlayer()
    if playerId == nil or playerId <= 0 then return 0 end
    local vehicle = GetPlayerVehicle(playerId)
    if vehicle == nil or vehicle == 0 then return 0 end
    local body = math.floor(GetVehicleBody(vehicle) or 0)
    local configuredBody = math.floor(
        (client.shipControlSnapshot or {}).shipBody
            or client.shipContextGetBody()
    )
    if body == 0 or configuredBody == 0 or body ~= configuredBody then return 0 end
    if client.registryShipExists ~= nil and not client.registryShipExists(body) then
        return 0
    end
    return body
end

local function _shipControlDiffers(snapshot, sent)
    if sent == nil then return true end
    local cfg = client.shipControlSnapshotConfig
    return snapshot.shipBody ~= sent.shipBody
        or snapshot.moveState ~= sent.moveState
        or snapshot.weaponAimActive ~= sent.weaponAimActive
        or math.abs(snapshot.pitchError - sent.pitchError)
            >= (cfg.pitchYawThreshold or 0.25)
        or math.abs(snapshot.yawError - sent.yawError)
            >= (cfg.pitchYawThreshold or 0.25)
        or math.abs(snapshot.rollError - sent.rollError)
            >= (cfg.rollThreshold or 0.5)
        or math.abs(snapshot.weaponAimYaw - sent.weaponAimYaw)
            >= (cfg.aimThreshold or 0.25)
        or math.abs(snapshot.weaponAimPitch - sent.weaponAimPitch)
            >= (cfg.aimThreshold or 0.25)
end

local function _shipControlCopySent(snapshot)
    return {
        shipBody = snapshot.shipBody,
        moveState = snapshot.moveState,
        pitchError = snapshot.pitchError,
        yawError = snapshot.yawError,
        rollError = snapshot.rollError,
        weaponAimActive = snapshot.weaponAimActive,
        weaponAimYaw = snapshot.weaponAimYaw,
        weaponAimPitch = snapshot.weaponAimPitch,
    }
end

function client.shipControlSnapshotInit(shipBody)
    local state = client.shipControlSnapshot
    state.shipBody = math.floor(shipBody or 0)
    state.sequence = 0
    state.lastSentAt = -1000.0
    state.lastSent = nil
    state.dirty = true
end

function client.shipControlSetMoveState(moveState)
    local state = client.shipControlSnapshot
    local nextState = math.floor(tonumber(moveState) or 0)
    nextState = _shipControlClamp(nextState, 0, 2)
    if state.moveState ~= nextState then
        state.moveState = nextState
        state.dirty = true
    end
end

function client.shipControlSetRotationError(pitchError, yawError)
    local state = client.shipControlSnapshot
    state.pitchError = _shipControlClamp(
        _shipControlSafeNumber(pitchError, 0.0),
        -90.0,
        90.0
    )
    state.yawError = _shipControlClamp(
        _shipControlSafeNumber(yawError, 0.0),
        -180.0,
        180.0
    )
end

function client.shipControlSetRollError(rollError)
    client.shipControlSnapshot.rollError = _shipControlClamp(
        _shipControlSafeNumber(rollError, 0.0),
        -180.0,
        180.0
    )
end

function client.shipControlSetWeaponAim(active, yaw, pitch)
    local state = client.shipControlSnapshot
    local nextActive = active and true or false
    if state.weaponAimActive ~= nextActive then
        state.weaponAimActive = nextActive
        state.dirty = true
    end
    state.weaponAimYaw = _shipControlClamp(
        _shipControlSafeNumber(yaw, 0.0),
        -180.0,
        180.0
    )
    state.weaponAimPitch = _shipControlClamp(
        _shipControlSafeNumber(pitch, 0.0),
        -90.0,
        90.0
    )
end

function client.shipControlSnapshotTick(dt)
    local _ = dt
    local state = client.shipControlSnapshot
    local drivenBody = _shipControlResolveDrivenBody()
    if drivenBody == 0 then
        if state.shipBody ~= 0 then
            state.shipBody = 0
            state.moveState = 0
            state.weaponAimActive = false
            state.dirty = true
        end
        return
    end
    if state.shipBody ~= drivenBody then
        state.shipBody = drivenBody
        state.dirty = true
    end

    local now = (GetTime ~= nil) and GetTime() or 0.0
    local changed = _shipControlDiffers(state, state.lastSent)
    local active = state.moveState ~= 0
        or math.abs(state.pitchError) >= 0.25
        or math.abs(state.yawError) >= 0.25
        or math.abs(state.rollError) >= 0.5
        or state.weaponAimActive
    local interval = active
        and (client.shipControlSnapshotConfig.activeInterval or 0.05)
        or (client.shipControlSnapshotConfig.idleInterval or 0.20)
    local due = now - (state.lastSentAt or -1000.0) >= interval
    local keepAliveDue = now - (state.lastSentAt or -1000.0)
        >= (client.shipControlSnapshotConfig.idleInterval or 0.20)
    if not state.dirty and not (changed and due) and not keepAliveDue then
        return
    end

    state.sequence = math.floor(state.sequence or 0) + 1
    ServerCall(
        "server.shipReceiveControlSnapshot",
        GetLocalPlayer(),
        state.shipBody,
        state.sequence,
        state.moveState,
        state.pitchError,
        state.yawError,
        state.rollError,
        state.weaponAimActive and 1 or 0,
        state.weaponAimYaw,
        state.weaponAimPitch
    )
    state.lastSent = _shipControlCopySent(state)
    state.lastSentAt = now
    state.dirty = false
end
