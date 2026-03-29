---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.mainWeaponInputState = client.mainWeaponInputState or {
    localPlayerId = nil,
    tHoldActive = false,
    tHoldShipBody = 0,
}

local function _resolveMainWeaponLocalPlayerId()
    local state = client.mainWeaponInputState
    if state.localPlayerId ~= nil and state.localPlayerId ~= 0 then
        return state.localPlayerId
    end

    local pid = GetLocalPlayer()
    if pid ~= nil and pid ~= -1 and pid ~= 0 then
        state.localPlayerId = pid
        return pid
    end

    return nil
end

function client.mainWeaponInputTick(dt)
    local _ = dt
    local state = client.mainWeaponInputState
    local localPlayerId = _resolveMainWeaponLocalPlayerId()
    if localPlayerId == nil then
        state.tHoldActive = false
        state.tHoldShipBody = 0
        return
    end

    local veh = GetPlayerVehicle(localPlayerId)
    if veh == nil or veh == 0 then
        if state.tHoldActive and state.tHoldShipBody ~= 0 and client.shipRequestTWeaponHold ~= nil then
            client.shipRequestTWeaponHold(state.tHoldShipBody, false)
        end
        state.tHoldActive = false
        state.tHoldShipBody = 0
        return
    end

    local body = GetVehicleBody(veh)
    local shipBody = client.shipBody
    if body == nil or body == 0 or shipBody == nil or shipBody == 0 or body ~= shipBody then
        if state.tHoldActive and state.tHoldShipBody ~= 0 and client.shipRequestTWeaponHold ~= nil then
            client.shipRequestTWeaponHold(state.tHoldShipBody, false)
        end
        state.tHoldActive = false
        state.tHoldShipBody = 0
        return
    end
    if not client.registryShipExists(shipBody) then
        if state.tHoldActive and state.tHoldShipBody ~= 0 and client.shipRequestTWeaponHold ~= nil then
            client.shipRequestTWeaponHold(state.tHoldShipBody, false)
        end
        state.tHoldActive = false
        state.tHoldShipBody = 0
        return
    end

    if InputPressed("q") then
        client.shipRequestMainWeaponToggle(shipBody, 1)
    end

    local currentMode = (client.getShipMainWeaponMode ~= nil) and client.getShipMainWeaponMode(shipBody) or "tSlot"
    if currentMode == "tSlot" then
        if InputPressed("lmb") and client.shipRequestTWeaponHold ~= nil then
            client.shipRequestTWeaponHold(shipBody, true)
            state.tHoldActive = true
            state.tHoldShipBody = shipBody
        end
        if InputReleased("lmb") then
            if state.tHoldActive and client.shipRequestTWeaponHold ~= nil then
                client.shipRequestTWeaponHold(shipBody, false)
            end
            if client.shipRequestTWeaponRelease ~= nil then
                client.shipRequestTWeaponRelease(shipBody)
            end
            state.tHoldActive = false
            state.tHoldShipBody = shipBody
        end
    else
        if state.tHoldActive and state.tHoldShipBody ~= 0 and client.shipRequestTWeaponHold ~= nil then
            client.shipRequestTWeaponHold(state.tHoldShipBody, false)
        end
        state.tHoldActive = false
        state.tHoldShipBody = shipBody
    end

    if InputPressed("lmb") then
        if currentMode == "mSlot" then
            if client.sSlotTargetingCanFire ~= nil and client.sSlotTargetingCanFire(shipBody) then
                local targetVehicleId = client.sSlotTargetingGetLockedVehicleId ~= nil and client.sSlotTargetingGetLockedVehicleId(shipBody) or 0
                if targetVehicleId ~= 0 and client.shipRequestSWeaponFire ~= nil then
                    client.shipRequestSWeaponFire(shipBody, targetVehicleId)
                end
            end
        elseif currentMode ~= "tSlot" then
            client.shipRequestMainWeaponFire(shipBody, 1)
        end
    end
end
