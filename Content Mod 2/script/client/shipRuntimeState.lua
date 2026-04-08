---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.shipRuntimeStateByShip = client.shipRuntimeStateByShip or {}

local function _clientGetOrCreateShipRuntimeState(shipBodyId)
    local body = math.floor(shipBodyId or 0)
    if body <= 0 then
        return nil
    end

    local states = client.shipRuntimeStateByShip
    local state = states[body]
    if state == nil then
        state = {
            currentMainWeapon = "xSlot",
            xSlotFireMode = "aim",
        }
        states[body] = state
    end
    return state
end

function client.setShipMainWeaponMode(shipBodyId, mode)
    local state = _clientGetOrCreateShipRuntimeState(shipBodyId)
    if state == nil then
        return
    end
    if mode == "lSlot" then
        state.currentMainWeapon = "lSlot"
    elseif mode == "sSlot" then
        state.currentMainWeapon = "sSlot"
    elseif mode == "hSlot" then
        state.currentMainWeapon = "hSlot"
    else
        state.currentMainWeapon = "xSlot"
    end
end

function client.getShipMainWeaponMode(shipBodyId)
    local state = _clientGetOrCreateShipRuntimeState(shipBodyId)
    if state == nil then
        return "xSlot"
    end
    if state.currentMainWeapon == "lSlot" or state.currentMainWeapon == "sSlot" or state.currentMainWeapon == "hSlot" then
        return state.currentMainWeapon
    end
    return "xSlot"
end

function client.setShipXSlotFireMode(shipBodyId, mode)
    local state = _clientGetOrCreateShipRuntimeState(shipBodyId)
    if state == nil then
        return
    end
    if mode == "lock" then
        state.xSlotFireMode = "lock"
    else
        state.xSlotFireMode = "aim"
    end
end

function client.getShipXSlotFireMode(shipBodyId)
    local state = _clientGetOrCreateShipRuntimeState(shipBodyId)
    if state == nil then
        return "aim"
    end
    if state.xSlotFireMode == "lock" then
        return "lock"
    end
    return "aim"
end

function client.toggleShipXSlotFireMode(shipBodyId)
    local current = client.getShipXSlotFireMode(shipBodyId)
    if current == "lock" then
        client.setShipXSlotFireMode(shipBodyId, "aim")
    else
        client.setShipXSlotFireMode(shipBodyId, "lock")
    end
end
