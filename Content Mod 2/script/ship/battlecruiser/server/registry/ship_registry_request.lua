---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.shipControlSnapshotStateByPlayer =
    server.shipControlSnapshotStateByPlayer or {}

local function _isPlayerDrivingShip(playerId, shipBodyId)
    if playerId == nil or shipBodyId == nil or shipBodyId == 0 then
        return false
    end
    if IsPlayerValid ~= nil and (not IsPlayerValid(playerId)) then
        return false
    end

    local veh = GetPlayerVehicle(playerId)
    if veh == nil or veh == 0 then
        return false
    end

    local playerVehicleBody = GetVehicleBody(veh)
    if playerVehicleBody == shipBodyId then
        return true
    end

    local shipVeh = GetBodyVehicle(shipBodyId)
    if shipVeh ~= nil and shipVeh ~= 0 and shipVeh == veh then
        return true
    end

    return false
end

local function _canAcceptShipRequest(playerId, shipBodyId)
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end
    if server.registryShipExists ~= nil and (not server.registryShipExists(shipBodyId)) then
        return false
    end
    if not _isPlayerDrivingShip(playerId, shipBodyId) then
        return false
    end
    if server.shipRuntimeGetDriverPlayerId ~= nil
        and server.shipRuntimeSetDriverPlayerId ~= nil then
        local previousDriver = server.shipRuntimeGetDriverPlayerId(shipBodyId)
        if previousDriver ~= math.floor(playerId or 0) then
            server.shipRuntimeSetDriverPlayerId(shipBodyId, playerId)
            if server.guidedSlotGroupMarkAllHudDirty ~= nil then
                server.guidedSlotGroupMarkAllHudDirty()
            end
            if server.hSlotState ~= nil and server.hSlotState.hudSync ~= nil then
                server.hSlotState.hudSync.dirty = true
            end
            if server.xSlotStateMarkHudDirty ~= nil then
                server.xSlotStateMarkHudDirty()
            end
            if server.lSlotStateMarkHudDirty ~= nil then
                server.lSlotStateMarkHudDirty()
            end
        end
    end
    return true
end

function server.shipRequestMainWeaponFire(playerId, shipBodyId, request)
    server.netDebugCountReceive("input.weapon")
    if server.shipBody == nil or server.shipBody == 0 or server.shipBody ~= shipBodyId then
        return
    end
    if not _canAcceptShipRequest(playerId, shipBodyId) then
        return
    end

    local value = (math.floor(request or 0) ~= 0)
    if server.mainWeaponRequestSetFireRequested ~= nil then
        server.mainWeaponRequestSetFireRequested(value)
    end
end

function server.shipRequestWeaponHold(playerId, shipBodyId, groupId, active, targetVehicleId)
    server.netDebugCountReceive("input.weapon")
    if server.shipBody == nil or server.shipBody == 0 or server.shipBody ~= shipBodyId then
        return false
    end

    local id = tostring(groupId or "")
    local held = math.floor(active or 0) ~= 0
    -- Releasing is always safe and must still work on the frame where the player
    -- has already left the vehicle; starting fire still requires ownership.
    if held and not _canAcceptShipRequest(playerId, shipBodyId) then return false end
    if held and server.shipRuntimeGetCurrentMainWeapon ~= nil
        and server.shipRuntimeGetCurrentMainWeapon(shipBodyId) ~= id then
        return false
    end

    local vehicleId = math.floor(targetVehicleId or 0)
    local targetBodyId = 0
    if vehicleId ~= 0 then
        targetBodyId = math.floor(GetVehicleBody(vehicleId) or 0)
    end

    if id == "xSlot" then
        local shipDef = server.shipSlotLoadoutResolveShipDefinition ~= nil
            and server.shipSlotLoadoutResolveShipDefinition(
                server.defaultShipType or "enigmaticCruiser"
            ) or {}
        local xSlot = ((shipDef or {}).xSlots or {})[1] or {}
        local weaponDef = (weaponData or {})[tostring(xSlot.weaponType or "")] or {}
        if tostring(weaponDef.legacyController or "") == "xSlot" then
            if server.xSlotStateSetHoldRequested ~= nil then
                server.xSlotStateSetHoldRequested(held)
            end
            if not held and server.xSlotStateSetReleaseRequested ~= nil then
                server.xSlotStateSetReleaseRequested(true)
            end
            return true
        end
    end

    if server.weaponGroupSetFireHeld == nil then return false end
    return server.weaponGroupSetFireHeld(id, held, {
        shipBodyId = shipBodyId,
        targetVehicleId = vehicleId,
        targetBodyId = targetBodyId,
    })
end

function server.shipRequestWeaponConfiguration(playerId, shipBodyId)
    server.netDebugCountReceive("input.configuration")
    if server.shipBody == nil or server.shipBody == 0 or server.shipBody ~= shipBodyId then
        return false
    end
    if not _canAcceptShipRequest(playerId, shipBodyId) then return false end
    if server.shipWeaponSyncConfiguration == nil then return false end
    server.shipWeaponSyncConfiguration(server.defaultShipType or "enigmaticCruiser", playerId)
    return true
end

function server.shipRequestMainWeaponToggle(playerId, shipBodyId, request)
    server.netDebugCountReceive("input.weapon")
    if server.shipBody == nil or server.shipBody == 0 or server.shipBody ~= shipBodyId then
        return
    end
    if not _canAcceptShipRequest(playerId, shipBodyId) then
        return
    end

    local value = (math.floor(request or 0) ~= 0)
    if server.mainWeaponRequestSetToggleRequested ~= nil then
        server.mainWeaponRequestSetToggleRequested(value)
    end
end

function server.shipRequestXWeaponHold(playerId, shipBodyId, request)
    server.netDebugCountReceive("input.weapon")
    if server.shipBody == nil or server.shipBody == 0 or server.shipBody ~= shipBodyId then
        return false
    end
    if not _canAcceptShipRequest(playerId, shipBodyId) then
        return false
    end
    if server.shipRuntimeGetCurrentMainWeapon ~= nil and server.shipRuntimeGetCurrentMainWeapon(shipBodyId) ~= "xSlot" then
        return false
    end

    local shipDef = server.shipSlotLoadoutResolveShipDefinition ~= nil
        and server.shipSlotLoadoutResolveShipDefinition(server.defaultShipType or "enigmaticCruiser") or {}
    local xSlot = ((shipDef or {}).xSlots or {})[1] or {}
    local weaponDef = (weaponData or {})[tostring(xSlot.weaponType or "")] or {}
    if tostring(weaponDef.legacyController or "") == "xSlot" and server.xSlotStateSetHoldRequested ~= nil then
        server.xSlotStateSetHoldRequested(math.floor(request or 0) ~= 0)
    end
    return true
end

function server.shipRequestXWeaponRelease(playerId, shipBodyId)
    server.netDebugCountReceive("input.weapon")
    if server.shipBody == nil or server.shipBody == 0 or server.shipBody ~= shipBodyId then
        return false
    end
    if not _canAcceptShipRequest(playerId, shipBodyId) then
        return false
    end
    if server.shipRuntimeGetCurrentMainWeapon ~= nil and server.shipRuntimeGetCurrentMainWeapon(shipBodyId) ~= "xSlot" then
        return false
    end

    local shipDef = server.shipSlotLoadoutResolveShipDefinition ~= nil
        and server.shipSlotLoadoutResolveShipDefinition(server.defaultShipType or "enigmaticCruiser") or {}
    local xSlot = ((shipDef or {}).xSlots or {})[1] or {}
    local weaponDef = (weaponData or {})[tostring(xSlot.weaponType or "")] or {}
    if tostring(weaponDef.legacyController or "") ~= "xSlot" then
        if server.weaponGroupRequestFire == nil then return false end
        return server.weaponGroupRequestFire("xSlot", { shipBodyId = shipBodyId })
    end
    if server.xSlotStateSetHoldRequested ~= nil then
        server.xSlotStateSetHoldRequested(false)
    end
    if server.xSlotStateSetReleaseRequested ~= nil then
        server.xSlotStateSetReleaseRequested(true)
    end
    return true
end

local function _acceptGuidedWeaponFireRequest(playerId, shipBodyId, targetVehicleId, expectedMode, setRequest)
    if setRequest == nil then
        return false
    end
    if server.shipBody == nil or server.shipBody == 0 or server.shipBody ~= shipBodyId then
        return false
    end
    if not _canAcceptShipRequest(playerId, shipBodyId) then
        return false
    end

    if server.shipRuntimeGetCurrentMainWeapon ~= nil then
        local current = server.shipRuntimeGetCurrentMainWeapon(shipBodyId)
        if current ~= expectedMode then
            return false
        end
    end

    local vehicleId = math.floor(targetVehicleId or 0)
    if vehicleId <= 0 then
        return false
    end

    local targetBody = GetVehicleBody(vehicleId)

    return setRequest(shipBodyId, vehicleId, targetBody or 0)
end

function server.shipRequestMWeaponFire(playerId, shipBodyId, targetVehicleId)
    server.netDebugCountReceive("input.weapon")
    return _acceptGuidedWeaponFireRequest(
        playerId,
        shipBodyId,
        targetVehicleId,
        "mSlot",
        function(ownerBody, vehicleId, targetBody)
            return server.weaponGroupRequestFire("mSlot", {
                shipBodyId = ownerBody,
                targetVehicleId = vehicleId,
                targetBodyId = targetBody,
            })
        end
    )
end

function server.shipRequestGWeaponFire(playerId, shipBodyId, targetVehicleId)
    server.netDebugCountReceive("input.weapon")
    return _acceptGuidedWeaponFireRequest(
        playerId,
        shipBodyId,
        targetVehicleId,
        "gSlot",
        function(ownerBody, vehicleId, targetBody)
            return server.weaponGroupRequestFire("gSlot", {
                shipBodyId = ownerBody,
                targetVehicleId = vehicleId,
                targetBodyId = targetBody,
            })
        end
    )
end

function server.shipRequestHWeaponFire(playerId, shipBodyId, targetVehicleId)
    server.netDebugCountReceive("input.weapon")
    if server.shipBody == nil or server.shipBody == 0 or server.shipBody ~= shipBodyId then
        return false
    end
    if not _canAcceptShipRequest(playerId, shipBodyId) then
        return false
    end

    if server.shipRuntimeGetCurrentMainWeapon ~= nil then
        local current = server.shipRuntimeGetCurrentMainWeapon(shipBodyId)
        if current ~= "hSlot" then
            return false
        end
    end

    local vehicleId = math.floor(targetVehicleId or 0)
    if vehicleId <= 0 then
        return false
    end

    local targetBody = GetVehicleBody(vehicleId)
    if targetBody == nil or targetBody == 0 then
        return false
    end

    if server.weaponGroupRequestFire == nil then return false end
    return server.weaponGroupRequestFire("hSlot", {
        shipBodyId = shipBodyId,
        targetVehicleId = vehicleId,
        targetBodyId = targetBody,
        requestedAt = (GetTime ~= nil) and GetTime() or 0.0,
    })
end

local function _controlSnapshotFinite(value)
    local number = tonumber(value)
    return number ~= nil
        and number == number
        and number ~= math.huge
        and number ~= -math.huge
end

local function _controlSnapshotClamp(value, minimum, maximum)
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
    if body == 0 or body ~= math.floor(server.shipBody or 0) then return false end
    if not _canAcceptShipRequest(pid, body) then return false end
    if seq <= 0 then return false end

    local numericValues = {
        moveState,
        pitchError,
        yawError,
        rollError,
        weaponAimActive,
        weaponAimYaw,
        weaponAimPitch,
    }
    for i = 1, #numericValues do
        if not _controlSnapshotFinite(numericValues[i]) then return false end
    end

    local playerState = server.shipControlSnapshotStateByPlayer[pid] or {
        lastSequence = 0,
        lastAcceptedAt = -1000.0,
        shipBody = body,
    }
    if seq <= math.floor(playerState.lastSequence or 0) then return false end

    local now = (GetTime ~= nil) and GetTime() or 0.0
    if now - (playerState.lastAcceptedAt or -1000.0) < 0.02 then
        return false
    end

    local move = math.floor(tonumber(moveState) or 0)
    if move < 0 or move > 2 then return false end
    local pitch = _controlSnapshotClamp(pitchError, -90.0, 90.0)
    local yaw = _controlSnapshotClamp(yawError, -180.0, 180.0)
    local roll = _controlSnapshotClamp(rollError, -180.0, 180.0)
    local aimActive = math.floor(tonumber(weaponAimActive) or 0) ~= 0
    local aimYaw = _controlSnapshotClamp(weaponAimYaw, -180.0, 180.0)
    local aimPitch = _controlSnapshotClamp(weaponAimPitch, -90.0, 90.0)

    server.shipRuntimeSetMoveRequestState(body, move)
    server.shipRuntimeSetRotationError(body, pitch, yaw)
    server.shipRuntimeSetRollError(body, roll)
    server.shipRuntimeSetWeaponAim(body, aimActive, aimYaw, aimPitch)

    playerState.lastSequence = seq
    playerState.lastAcceptedAt = now
    playerState.shipBody = body
    server.shipControlSnapshotStateByPlayer[pid] = playerState
    return true
end

function server.shipRequestMoveState(playerId, shipBodyId, moveState)
    server.netDebugCountReceive("input.move")
    if not _canAcceptShipRequest(playerId, shipBodyId) then
        return
    end

    local state = math.floor(moveState or 0)
    if state < 0 then
        state = 0
    end
    if state > 2 then
        state = 2
    end

    if server.shipRuntimeSetMoveRequestState ~= nil then
        server.shipRuntimeSetMoveRequestState(shipBodyId, state)
    end
end

function server.shipRequestRotationError(playerId, shipBodyId, pitchError, yawError)
    server.netDebugCountReceive("input.rotation")
    if not _canAcceptShipRequest(playerId, shipBodyId) then
        return false
    end

    local pe = tonumber(pitchError) or 0.0
    local ye = tonumber(yawError) or 0.0
    if pe ~= pe or pe == math.huge or pe == -math.huge then
        pe = 0.0
    end
    if ye ~= ye or ye == math.huge or ye == -math.huge then
        ye = 0.0
    end

    if server.shipRuntimeSetRotationError ~= nil then
        server.shipRuntimeSetRotationError(shipBodyId, pe, ye)
    end
    return true
end

function server.shipRequestWeaponAim(playerId, shipBodyId, active, localYaw, localPitch)
    server.netDebugCountReceive("input.aim")
    if not _canAcceptShipRequest(playerId, shipBodyId) then
        return false
    end

    local aimActive = math.floor(active or 0) ~= 0
    local yawValue = tonumber(localYaw) or 0.0
    local pitchValue = tonumber(localPitch) or 0.0
    if yawValue ~= yawValue or yawValue == math.huge or yawValue == -math.huge then
        yawValue = 0.0
    end
    if pitchValue ~= pitchValue or pitchValue == math.huge or pitchValue == -math.huge then
        pitchValue = 0.0
    end

    if server.shipRuntimeSetWeaponAim ~= nil then
        server.shipRuntimeSetWeaponAim(shipBodyId, aimActive, yawValue, pitchValue)
    end
    return true
end

function server.shipRequestRollError(playerId, shipBodyId, rollError)
    server.netDebugCountReceive("input.roll")
    if not _canAcceptShipRequest(playerId, shipBodyId) then
        return false
    end

    local re = tonumber(rollError) or 0.0
    if re ~= re or re == math.huge or re == -math.huge then
        re = 0.0
    end

    if server.shipRuntimeSetRollError ~= nil then
        server.shipRuntimeSetRollError(shipBodyId, re)
    end
    return true
end
