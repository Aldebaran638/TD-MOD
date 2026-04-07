---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.mainWeaponInputState = client.mainWeaponInputState or {
    localPlayerId = nil,
    xHoldActive = false,
    xHoldShipBody = 0,
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

-- 主武器输入主逻辑：x槽按住蓄力松开发射，l/s槽保持原有点击开火
function client.mainWeaponInputTick(dt)
    local _ = dt
    local state = client.mainWeaponInputState
    local localPlayerId = _resolveMainWeaponLocalPlayerId()
    if localPlayerId == nil then
        state.xHoldActive = false
        state.xHoldShipBody = 0
        return
    end

    local veh = GetPlayerVehicle(localPlayerId)
    if veh == nil or veh == 0 then
        if state.xHoldActive and state.xHoldShipBody ~= 0 and client.shipRequestXWeaponHold ~= nil then
            client.shipRequestXWeaponHold(state.xHoldShipBody, false)
        end
        state.xHoldActive = false
        state.xHoldShipBody = 0
        return
    end

    local body = GetVehicleBody(veh)
    local shipBody = client.shipBody
    if body == nil or body == 0 or shipBody == nil or shipBody == 0 or body ~= shipBody then
        if state.xHoldActive and state.xHoldShipBody ~= 0 and client.shipRequestXWeaponHold ~= nil then
            client.shipRequestXWeaponHold(state.xHoldShipBody, false)
        end
        state.xHoldActive = false
        state.xHoldShipBody = 0
        return
    end
    if not client.registryShipExists(shipBody) then
        if state.xHoldActive and state.xHoldShipBody ~= 0 and client.shipRequestXWeaponHold ~= nil then
            client.shipRequestXWeaponHold(state.xHoldShipBody, false)
        end
        state.xHoldActive = false
        state.xHoldShipBody = 0
        return
    end

    local currentMode = (client.getShipMainWeaponMode ~= nil) and client.getShipMainWeaponMode(shipBody) or "xSlot"

    if InputPressed("q") then
        client.shipRequestMainWeaponToggle(shipBody, 1)
    end

    -- 步骤1：检测主武器输入状态（按下/松开）
    if currentMode == "xSlot" then
        if InputPressed("lmb") and client.shipRequestXWeaponHold ~= nil then
            client.shipRequestXWeaponHold(shipBody, true)
            state.xHoldActive = true
            state.xHoldShipBody = shipBody
        end

        if InputReleased("lmb") then
            if state.xHoldActive and client.shipRequestXWeaponHold ~= nil then
                client.shipRequestXWeaponHold(shipBody, false)
            end
            if client.shipRequestXWeaponRelease ~= nil then
                client.shipRequestXWeaponRelease(shipBody)
            end
            state.xHoldActive = false
            state.xHoldShipBody = shipBody
        end
        return
    end

    if state.xHoldActive and state.xHoldShipBody ~= 0 and client.shipRequestXWeaponHold ~= nil then
        client.shipRequestXWeaponHold(state.xHoldShipBody, false)
    end
    state.xHoldActive = false
    state.xHoldShipBody = shipBody

    -- 步骤2：客户端修改请求键（l/s槽保持点击开火）
    if InputPressed("lmb") then
        if currentMode == "sSlot" then
            if client.sSlotTargetingCanFire ~= nil and client.sSlotTargetingCanFire(shipBody) then
                local targetVehicleId = client.sSlotTargetingGetLockedVehicleId ~= nil and client.sSlotTargetingGetLockedVehicleId(shipBody) or 0
                if targetVehicleId ~= 0 and client.shipRequestSWeaponFire ~= nil then
                    client.shipRequestSWeaponFire(shipBody, targetVehicleId)
                end
            end
        else
            client.shipRequestMainWeaponFire(shipBody, 1)
        end
    end
end
