---@diagnostic disable: undefined-global

server = server or {}

local function _count()
    server.netDebugCountReceive("input.weapon")
end

local function _requestContext(shipBodyId, targetVehicleId, targetBodyId)
    local vehicleId = math.floor(tonumber(targetVehicleId) or 0)
    local bodyId = 0
    if vehicleId ~= 0 then
        bodyId = math.floor(GetVehicleBody(vehicleId) or 0)
    else
        local requestedBody = math.floor(tonumber(targetBodyId) or 0)
        if server.weaponTargetIsExternalBody ~= nil
            and server.weaponTargetIsExternalBody(requestedBody) then
            bodyId = requestedBody
        end
    end
    local ownerBody = math.floor(tonumber(shipBodyId) or 0)
    if bodyId == ownerBody then
        vehicleId = 0
        bodyId = 0
    end
    return {
        shipBodyId = ownerBody,
        targetVehicleId = vehicleId,
        targetBodyId = bodyId,
    }
end

function server.shipRequestWeaponHold(
    playerId,
    shipBodyId,
    groupId,
    active,
    targetVehicleId,
    targetBodyId
)
    _count()
    local id = tostring(groupId or "")
    local held = math.floor(tonumber(active) or 0) ~= 0
    if not server.shipRequestMatchesContext(shipBodyId) then return false end
    -- 松开只清理状态，不要求玩家仍在载具中。
    if held and not server.shipRequestAuthorize(playerId, shipBodyId) then return false end
    if held and server.shipRuntimeGetCurrentMainWeapon(shipBodyId) ~= id then
        return false
    end
    return server.weaponGroupSetFireHeld(
        id,
        held,
        _requestContext(shipBodyId, targetVehicleId, targetBodyId)
    )
end

function server.shipRequestMainWeaponFire(playerId, shipBodyId, request)
    _count()
    if not server.shipRequestAuthorize(playerId, shipBodyId) then return end
    server.mainWeaponRequestSetFireRequested(math.floor(request or 0) ~= 0)
end

function server.shipRequestMainWeaponToggle(playerId, shipBodyId, request)
    _count()
    if not server.shipRequestAuthorize(playerId, shipBodyId) then return end
    server.mainWeaponRequestSetToggleRequested(math.floor(request or 0) ~= 0)
end

function server.shipRequestXWeaponHold(playerId, shipBodyId, request)
    return server.shipRequestWeaponHold(playerId, shipBodyId, "xSlot", request, 0)
end

function server.shipRequestXWeaponRelease(playerId, shipBodyId)
    return server.shipRequestWeaponHold(playerId, shipBodyId, "xSlot", 0, 0)
end

local function _requestLockedGroup(
    playerId,
    shipBodyId,
    targetVehicleId,
    targetBodyId,
    groupId
)
    if not server.shipRequestAuthorize(playerId, shipBodyId) then return false end
    if server.shipRuntimeGetCurrentMainWeapon(shipBodyId) ~= groupId then return false end
    local request =
        _requestContext(shipBodyId, targetVehicleId, targetBodyId)
    if request.targetBodyId <= 0 then return false end
    return server.weaponGroupRequestFire(groupId, request)
end

function server.shipRequestMWeaponFire(
    playerId,
    shipBodyId,
    targetVehicleId,
    targetBodyId
)
    _count()
    return _requestLockedGroup(
        playerId, shipBodyId, targetVehicleId, targetBodyId, "mSlot")
end

function server.shipRequestGWeaponFire(
    playerId,
    shipBodyId,
    targetVehicleId,
    targetBodyId
)
    _count()
    return _requestLockedGroup(
        playerId, shipBodyId, targetVehicleId, targetBodyId, "gSlot")
end

function server.shipRequestHWeaponFire(
    playerId,
    shipBodyId,
    targetVehicleId,
    targetBodyId
)
    _count()
    local fired = _requestLockedGroup(
        playerId, shipBodyId, targetVehicleId, targetBodyId, "hSlot")
    if fired and server.hSlotLastFireRequest ~= nil then
        server.hSlotLastFireRequest.requestedAt =
            (GetTime ~= nil) and GetTime() or 0.0
    end
    return fired
end

function server.shipRequestWeaponConfiguration(playerId, shipBodyId)
    server.netDebugCountReceive("input.configuration")
    if not server.shipRequestAuthorize(playerId, shipBodyId) then return false end
    server.shipWeaponSyncConfiguration(server.shipContextGetType(), playerId)
    return true
end
