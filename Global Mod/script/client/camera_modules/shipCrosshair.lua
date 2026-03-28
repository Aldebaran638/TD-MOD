---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.shipCrosshairConfig = client.shipCrosshairConfig or {
    size = 8,
    thickness = 1,
    originForwardOffset = 2,
    color = {1, 1, 1, 1},
    fallbackRange = 2000,
}

local function _resolveCrosshairRange()
    local defs = weaponData or {}
    local tachyon = defs.tachyonLance or {}
    local maxRange = tonumber(tachyon.maxRange) or 0
    if maxRange <= 0 then
        maxRange = tonumber(tachyon.range) or 0
    end
    if maxRange <= 0 then
        maxRange = client.shipCrosshairConfig.fallbackRange or 2000
    end
    return maxRange
end

local function _resolveAimPointForBody(body, maxRange)
    if body == nil or body == 0 then
        return nil
    end

    local cfg = client.shipCrosshairConfig
    local t = GetBodyTransform(body)
    local forwardLocal = Vec(0, 0, -1)
    local rayOrigin = TransformToParentPoint(t, VecScale(forwardLocal, cfg.originForwardOffset))
    local forwardWorldDir = VecNormalize(TransformToParentVec(t, forwardLocal))

    QueryRequire("physical")
    QueryRejectBody(body)

    local hit, hitDist = QueryRaycast(rayOrigin, forwardWorldDir, maxRange)
    if hit then
        return VecAdd(rayOrigin, VecScale(forwardWorldDir, hitDist))
    end
    return VecAdd(rayOrigin, VecScale(forwardWorldDir, maxRange))
end

local function _resolveControlledShipBody()
    if client.shipCameraGetControlledBody ~= nil then
        local body = client.shipCameraGetControlledBody()
        if body ~= nil and body ~= 0 then
            return body
        end
    end

    local veh = GetPlayerVehicle()
    if veh == nil or veh == 0 then
        local localPlayerId = GetLocalPlayer()
        if localPlayerId ~= nil and localPlayerId ~= 0 then
            veh = GetPlayerVehicle(localPlayerId)
        end
    end

    if veh == nil or veh == 0 then
        return 0
    end

    local body = GetVehicleBody(veh)
    if body == nil or body == 0 then
        return 0
    end

    if client.registryShipExists ~= nil and (not client.registryShipExists(body)) then
        return 0
    end

    return body
end

function client.shipCrosshairDraw()
    local cfg = client.shipCrosshairConfig

    local body = _resolveControlledShipBody()
    if body == 0 then
        return
    end
    if client.getShipMainWeaponMode ~= nil and client.getShipMainWeaponMode(body) == "sSlot" then
        return
    end

    local maxRange = _resolveCrosshairRange()
    local aimPoint = _resolveAimPointForBody(body, maxRange)
    if aimPoint == nil then
        return
    end

    local camT = GetCameraTransform()
    local camForward = VecNormalize(TransformToParentVec(camT, Vec(0, 0, -1)))
    local dirToPoint = VecNormalize(VecSub(aimPoint, camT.pos))
    if VecDot(camForward, dirToPoint) <= 0 then
        return
    end

    local sx, sy = UiWorldToPixel(aimPoint)
    if not sx or not sy then
        return
    end

    UiPush()
        UiAlign("center middle")
        UiTranslate(sx, sy)
        UiColor(cfg.color[1], cfg.color[2], cfg.color[3], cfg.color[4])

        local s = cfg.size
        local th = cfg.thickness
        UiRect(s * 2, th)
        UiRect(th, s * 2)
    UiPop()
end

function client.shipCrosshairGetAimWorldPoint(shipBodyId)
    local body = math.floor(shipBodyId or 0)
    if body <= 0 then
        return nil
    end
    return _resolveAimPointForBody(body, _resolveCrosshairRange())
end
