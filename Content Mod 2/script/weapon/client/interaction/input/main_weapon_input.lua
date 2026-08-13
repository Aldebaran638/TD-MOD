---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.mainWeaponInputState = client.mainWeaponInputState or {
    localPlayerId = nil,
    holdActive = false,
    holdShipBody = 0,
    holdMode = "",
    holdTargetVehicleId = 0,
    holdTargetBodyId = 0,
    diagnosticLmbDown = false,
}

local function _resolveMainWeaponLocalPlayerId()
    local state = client.mainWeaponInputState
    if state.localPlayerId ~= nil and state.localPlayerId ~= 0 then
        return state.localPlayerId
    end
    local playerId = GetLocalPlayer()
    if playerId ~= nil and playerId ~= -1 and playerId ~= 0 then
        state.localPlayerId = playerId
        return playerId
    end
    return nil
end

local function _releaseHeldWeapon(state)
    if state.holdActive and state.holdShipBody ~= 0
        and client.shipRequestWeaponHold ~= nil then
        client.shipRequestWeaponHold(
            state.holdShipBody,
            state.holdMode,
            false,
            state.holdTargetVehicleId,
            state.holdTargetBodyId
        )
    end
    state.holdActive = false
    state.holdShipBody = 0
    state.holdMode = ""
    state.holdTargetVehicleId = 0
    state.holdTargetBodyId = 0
end

local function _requiresTargetLock(definition)
    return weaponTargetingPolicy.requiresTargetLock(definition)
end

local function _lockedTargetForWeapon(shipBody, definition)
    local weapon = definition or {}
    local hasLockedTarget = client.chargedRayTargetingHasLockedTarget
        or client.xSlotTargetingHasLockedTarget
    local getLockedTargetIds = client.chargedRayTargetingGetLockedTargetIds
        or client.xSlotTargetingGetLockedTargetIds
    if tostring(weapon.controllerType or "") == "chargedRay"
        and hasLockedTarget ~= nil
        and hasLockedTarget(shipBody) then
        local vehicleId, bodyId = 0, 0
        if getLockedTargetIds ~= nil then
            vehicleId, bodyId = getLockedTargetIds(shipBody)
        end
        return math.floor(vehicleId or 0), math.floor(bodyId or 0)
    end
    if not _requiresTargetLock(weapon) then
        return 0, 0
    end
    if client.guidedTargetingCanFire == nil
        or not client.guidedTargetingCanFire(shipBody) then
        return 0, 0
    end
    local vehicleId = client.guidedTargetingGetLockedVehicleId ~= nil
        and client.guidedTargetingGetLockedVehicleId(shipBody) or 0
    local bodyId = client.guidedTargetingGetLockedBodyId ~= nil
        and client.guidedTargetingGetLockedBodyId(shipBody) or 0
    return math.floor(vehicleId or 0), math.floor(bodyId or 0)
end

-- The server owns charge, cooldown and automatic refire. The client only sends
-- hold state transitions and target-lock changes.
function client.mainWeaponInputTick(dt)
    local _ = dt
    local state = client.mainWeaponInputState
    local diagnosticLmbDown = InputDown("lmb")
    local diagnosticPress = diagnosticLmbDown and not state.diagnosticLmbDown
    state.diagnosticLmbDown = diagnosticLmbDown and true or false
    local function trace(stage, fields)
        if not diagnosticPress or client.cm2TelemetryRecord == nil then return end
        local data = type(fields) == "table" and fields or {}
        data.stage = tostring(stage or "unknown")
        data.context_body_id = math.floor((client.shipContextGetBody ~= nil
            and client.shipContextGetBody()) or 0)
        client.cm2TelemetryRecord("weapon_input_evaluated", data)
    end
    if client.weaponConfigUiIsOpen ~= nil and client.weaponConfigUiIsOpen() then
        trace("blocked", { reason = "weapon configuration UI is open" })
        _releaseHeldWeapon(state)
        return
    end

    local playerId = _resolveMainWeaponLocalPlayerId()
    if playerId == nil then
        trace("blocked", { reason = "local player is unavailable" })
        _releaseHeldWeapon(state)
        return
    end

    local vehicle = GetPlayerVehicle(playerId)
    if vehicle == nil or vehicle == 0 then
        trace("blocked", {
            reason = "local player is not in a vehicle",
            player_id = math.floor(playerId or 0),
        })
        _releaseHeldWeapon(state)
        return
    end

    local body = GetVehicleBody(vehicle)
    local shipBody = client.shipContextGetBody()
    if body == nil or body == 0 or shipBody == nil or shipBody == 0
        or body ~= shipBody or not client.registryShipExists(shipBody) then
        trace("blocked", {
            reason = "player vehicle does not match this ship context",
            player_id = math.floor(playerId or 0),
            vehicle_id = math.floor(vehicle or 0),
            vehicle_body_id = math.floor(body or 0),
            ship_body_id = math.floor(shipBody or 0),
            registered = shipBody ~= nil and shipBody ~= 0
                and client.registryShipExists(shipBody) or false,
        })
        _releaseHeldWeapon(state)
        return
    end

    local currentMode = client.getShipMainWeaponMode ~= nil
        and client.getShipMainWeaponMode(shipBody) or "xSlot"

    if InputPressed("q") then
        _releaseHeldWeapon(state)
        client.shipRequestMainWeaponToggle(shipBody, 1)
        return
    end
    local currentDefinition = client.getShipWeaponDefinition ~= nil
        and client.getShipWeaponDefinition(shipBody, currentMode) or {}
    local isChargedRay = tostring(currentDefinition.controllerType or "") == "chargedRay"
    if isChargedRay and InputPressed("b") then
        if client.toggleShipWeaponFireMode ~= nil then
            client.toggleShipWeaponFireMode(shipBody)
        elseif client.toggleShipXSlotFireMode ~= nil then
            client.toggleShipXSlotFireMode(shipBody)
        end
    end

    local definition = currentDefinition
    local targetVehicleId, targetBodyId =
        _lockedTargetForWeapon(shipBody, definition)
    if _requiresTargetLock(definition)
        and targetVehicleId == 0 and targetBodyId == 0 then
        trace("blocked", {
            reason = "selected weapon requires a target lock",
            player_id = math.floor(playerId or 0),
            vehicle_id = math.floor(vehicle or 0),
            ship_body_id = math.floor(shipBody or 0),
            group_id = tostring(currentMode or ""),
            weapon_type = tostring((definition or {}).weaponType or ""),
        })
        _releaseHeldWeapon(state)
        return
    end
    trace("ready", {
        player_id = math.floor(playerId or 0),
        vehicle_id = math.floor(vehicle or 0),
        ship_body_id = math.floor(shipBody or 0),
        group_id = tostring(currentMode or ""),
        weapon_type = tostring((definition or {}).weaponType or ""),
        target_vehicle_id = math.floor(targetVehicleId or 0),
        target_body_id = math.floor(targetBodyId or 0),
    })
    local wantsFire = InputDown("lmb")
    local changed = state.holdShipBody ~= shipBody
        or state.holdMode ~= currentMode
        or state.holdTargetVehicleId ~= targetVehicleId
        or state.holdTargetBodyId ~= targetBodyId

    if state.holdActive and ((not wantsFire) or changed) then
        _releaseHeldWeapon(state)
    end

    if wantsFire and not state.holdActive and client.shipRequestWeaponHold ~= nil then
        client.shipRequestWeaponHold(
            shipBody,
            currentMode,
            true,
            targetVehicleId,
            targetBodyId
        )
        state.holdActive = true
        state.holdShipBody = shipBody
        state.holdMode = currentMode
        state.holdTargetVehicleId = targetVehicleId
        state.holdTargetBodyId = targetBodyId
    end
end
