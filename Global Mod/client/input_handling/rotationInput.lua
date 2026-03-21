---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local rotationRequestInterval = 0.05

client.rotationInputState = client.rotationInputState or {
    localPlayerId = nil,
    lastShipBodyId = 0,
    lastSyncAt = -1000
}

-- 将向量直接换算为角
local function dirToYawPitch(dir)
    dir = VecNormalize(dir)
    local yawRaw = math.deg(math.atan(-dir[3], dir[1]))
    local yaw = (yawRaw - 90.0 + 180) % 360 - 180
    local horiz = math.sqrt(dir[1] * dir[1] + dir[3] * dir[3])
    local pitch = math.deg(math.atan(dir[2], horiz))
    return yaw, pitch
end

-- 获取本地玩家逻辑 (简单防冗余查询)
local function _resolveLocalPlayerId()
    if client.rotationInputState.localPlayerId == nil then
        local pid = GetLocalPlayer()
        if pid ~= nil and pid ~= -1 and pid ~= 0 then
            client.rotationInputState.localPlayerId = pid
        end
    end
    return client.rotationInputState.localPlayerId
end

function client.rotationInputTick(dt)

    local pId = _resolveLocalPlayerId()
    if pId == nil then return end

    local veh = GetPlayerVehicle()
    if veh == 0 then
        client.rotationInputState.lastShipBodyId = 0
        return
    end

    local shipBodyId = GetVehicleBody(veh)
    if shipBodyId == 0 then return end
    client.rotationInputState.lastShipBodyId = shipBodyId

    -- 节流检查
    local now = GetTime()
    if now - client.rotationInputState.lastSyncAt < rotationRequestInterval then
        return
    end
    client.rotationInputState.lastSyncAt = now

    -- 如果用户按住了右键(自由观察视角)，就不发送对准请求
    if InputDown("rmb") then
        ServerCall("server.registryShipRequestSetRotationAim", pId, shipBodyId, false, 0, 0)
        return
    end

    local camT = GetCameraTransform()
    local camForward = TransformToParentVec(camT, Vec(0, 0, -1))
    local yaw, pitch = dirToYawPitch(camForward)

    -- 发送请求
    ServerCall("server.registryShipRequestSetRotationAim", pId, shipBodyId, true, yaw, pitch)
end
