---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local registryShipRoot = "StellarisShips/server/ships/byId/"

local function _shipKeyPrefix(shipBodyId)
    return registryShipRoot .. tostring(shipBodyId)
end

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

-- 客户端请求 -> 服务端写入 xSlots/request
function server.registryShipRequestSetXSlotRequest(playerId, shipBodyId, request)
    if shipBodyId == nil or shipBodyId == 0 then
        return
    end

    local prefix = _shipKeyPrefix(shipBodyId)
    if not GetBool(prefix .. "/exists") then
        return
    end

    if not _isPlayerDrivingShip(playerId, shipBodyId) then
        return
    end

    local value = (math.floor(request or 0) ~= 0) and 1 or 0
    SetInt(prefix .. "/xSlots/request", value, true)
end

-- 客户端请求 -> 服务端写入 move/requestState 与 move/request
function server.registryShipRequestSetMoveRequestState(playerId, shipBodyId, moveState)
    if shipBodyId == nil or shipBodyId == 0 then
        return
    end

    local prefix = _shipKeyPrefix(shipBodyId)
    if not GetBool(prefix .. "/exists") then
        return
    end

    if not _isPlayerDrivingShip(playerId, shipBodyId) then
        return
    end

    local state = math.floor(moveState or 0)
    if state < 0 then state = 0 end
    if state > 2 then state = 2 end

    SetInt(prefix .. "/move/requestState", state, true)
    SetInt(prefix .. "/move/request", (state == 0) and 0 or 1, true)
end

-- 客户端请求 -> 服务端写入 rot/aimActive, rot/aimYaw, rot/aimPitch 等
function server.registryShipRequestSetRotationAim(playerId, shipBodyId, active, yaw, pitch)
    if shipBodyId == nil or shipBodyId == 0 then
        return
    end

    local prefix = _shipKeyPrefix(shipBodyId)
    if not GetBool(prefix .. "/exists") then
        return
    end

    if not _isPlayerDrivingShip(playerId, shipBodyId) then
        return
    end

    if active then
        -- 激活状态，写入目标偏航/俯仰角，并更新时间戳(防卡顿失控)
        SetBool(prefix .. "/rot/aimActive", true, true)
        SetFloat(prefix .. "/rot/aimYaw", yaw or 0.0, true)
        SetFloat(prefix .. "/rot/aimPitch", pitch or 0.0, true)
        SetFloat(prefix .. "/rot/aimTime", serverTime or GetTime(), true)
    else
        -- 自由视角等非激活状态，取消同步
        SetBool(prefix .. "/rot/aimActive", false, true)
    end
end

-- client request -> server write rotation error (pitch/yaw)
function server.registryShipRequestSetRotationError(playerId, shipBodyId, pitchError, yawError)
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end

    local prefix = _shipKeyPrefix(shipBodyId)
    if not GetBool(prefix .. "/exists") then
        return false
    end
    if not _isPlayerDrivingShip(playerId, shipBodyId) then
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
    SetFloat(prefix .. "/pitchError", pe, true)
    SetFloat(prefix .. "/yawError", ye, true)
    return true
end

-- client request -> server write roll error
function server.registryShipRequestSetRollError(playerId, shipBodyId, rollError)
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end

    local prefix = _shipKeyPrefix(shipBodyId)
    if not GetBool(prefix .. "/exists") then
        return false
    end
    if not _isPlayerDrivingShip(playerId, shipBodyId) then
        return false
    end

    local re = tonumber(rollError) or 0.0
    if re ~= re or re == math.huge or re == -math.huge then
        re = 0.0
    end

    SetFloat(prefix .. "/rollError", re, true)
    return true
end
