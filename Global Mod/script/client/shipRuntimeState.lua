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
    state.currentMainWeapon = (mode == "lSlot") and "lSlot" or "xSlot"
end

function client.getShipMainWeaponMode(shipBodyId)
    local state = _clientGetOrCreateShipRuntimeState(shipBodyId)
    if state == nil then
        return "xSlot"
    end
    if state.currentMainWeapon ~= "lSlot" then
        return "xSlot"
    end
    return state.currentMainWeapon
end
