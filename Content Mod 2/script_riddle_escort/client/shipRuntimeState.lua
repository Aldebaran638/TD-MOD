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
            currentMainWeapon = "sSlot",
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
    if mode == "sSlot" then
        state.currentMainWeapon = "sSlot"
    elseif mode == "pSlot" then
        state.currentMainWeapon = "pSlot"
    elseif mode == "gSlot" then
        state.currentMainWeapon = "gSlot"
    else
        state.currentMainWeapon = "sSlot"
    end
end

function client.getShipMainWeaponMode(shipBodyId)
    local state = _clientGetOrCreateShipRuntimeState(shipBodyId)
    if state == nil then
        return "sSlot"
    end
    if state.currentMainWeapon == "sSlot" or state.currentMainWeapon == "pSlot" or state.currentMainWeapon == "gSlot" then
        return state.currentMainWeapon
    end
    return "sSlot"
end
