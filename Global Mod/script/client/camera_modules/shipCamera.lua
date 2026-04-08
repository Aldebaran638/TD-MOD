---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.shipCamera = client.shipCamera or {
    r = 14,
    b = 8,
    c = 0,

    rMin = 10,
    rMax = 20,

    angleLimitPitch = 85,
    angleLimitYaw1 = -90,
    angleLimitYaw2 = 90,

    -- tuning knobs
    mouseSensitivity = 0.05,
    glideStrength = 0.55, -- 0.0=almost no glide, 1.0=very floaty
    zoomSpeed = 0.5,
    switchDuration = 0.30,
    frontOffset = { x = 0, y = 0, z = -3 },
    viewMode = "rear",
    viewBlend = 0.0,
    viewBlendTarget = 0.0,
    frontAimPitchLimit = 90,
    frontAimYaw1 = -90,
    frontAimYaw2 = 90,
    frontAimYaw = 0.0,
    frontAimPitch = 0.0,
    rearDefaultPitch = 8.0,
    freelookTurnYawError = 16.0,
    weaponAimSyncKeepAlive = 0.2,

    rearFreelookActive = false,
    frontFreelookActive = false,
    rmbLongPressSeconds = 0.22,
    rmbPressTime = 0.0,
    rmbLongTriggered = false,
    fov = 70,
}

local function clamp(v, minValue, maxValue)
    if v < minValue then return minValue end
    if v > maxValue then return maxValue end
    return v
end

local function sphericalToCartesian(r, pitch, yaw)
    local pr = math.rad(pitch)
    local yr = math.rad(yaw)

    local x = r * math.cos(pr) * math.sin(yr)
    local y = r * math.sin(pr)
    local z = r * math.cos(pr) * math.cos(yr)

    return Vec(x, y, z)
end

local function vectorToRelativeYawPitch(v)
    -- Yaw=0 at ship local forward (0,0,-1)
    local yaw = math.deg(math.atan2(v[1], -v[3]))
    local horiz = math.sqrt(v[1] * v[1] + v[3] * v[3])
    local pitch = math.deg(math.atan2(v[2], horiz))
    return yaw, pitch
end

local function wrapAngle180(v)
    local a = v or 0.0
    while a > 180 do
        a = a - 360
    end
    while a < -180 do
        a = a + 360
    end
    return a
end

local function unwrapNear(reference, wrappedAngle)
    local ref = reference or 0.0
    local a = wrapAngle180(wrappedAngle)
    local diff = a - ref
    while diff > 180 do
        a = a - 360
        diff = a - ref
    end
    while diff < -180 do
        a = a + 360
        diff = a - ref
    end
    return a
end

local function vectorToWorldYaw(v)
    return math.deg(math.atan2(v[1], v[3]))
end

local function vectorToWorldYawPitch(v)
    local yaw = vectorToWorldYaw(v)
    local horiz = math.sqrt(v[1] * v[1] + v[3] * v[3])
    local pitch = math.deg(math.atan2(v[2], horiz))
    return yaw, pitch
end

local function worldYawPitchToVector(yaw, pitch)
    local yr = math.rad(yaw)
    local pr = math.rad(pitch)
    return Vec(
        math.cos(pr) * math.sin(yr),
        math.sin(pr),
        math.cos(pr) * math.cos(yr)
    )
end

local function relativeYawPitchToVector(yaw, pitch)
    local yr = math.rad(yaw)
    local pr = math.rad(pitch)
    return Vec(
        math.cos(pr) * math.sin(yr),
        math.sin(pr),
        -math.cos(pr) * math.cos(yr)
    )
end

local function _safeNormalize(v, fallback)
    local len = VecLength(v)
    if len < 0.0001 then
        return fallback or Vec(0, 0, -1)
    end
    return VecScale(v, 1.0 / len)
end

local function _clampDirectionToConeLocal(localDir, maxAngleDeg)
    local forward = Vec(0, 0, -1)
    local desired = _safeNormalize(localDir, forward)
    local maxDeg = math.max(0.0, tonumber(maxAngleDeg) or 0.0)
    if maxDeg <= 0.0001 then
        return forward
    end

    local dot = VecDot(desired, forward)
    if dot > 1.0 then dot = 1.0 end
    if dot < -1.0 then dot = -1.0 end
    local angle = math.deg(math.acos(dot))
    if angle <= maxDeg then
        return desired
    end

    local lateral = VecSub(desired, VecScale(forward, dot))
    lateral = _safeNormalize(lateral, Vec(1, 0, 0))
    local maxRad = math.rad(maxDeg)
    return _safeNormalize(
        VecAdd(VecScale(forward, math.cos(maxRad)), VecScale(lateral, math.sin(maxRad))),
        forward
    )
end

local function _resolveRelativeAimVector(localDir, pitchOffsetDeg, limitDeg)
    local yaw, pitch = vectorToRelativeYawPitch(localDir)
    pitch = pitch + (tonumber(pitchOffsetDeg) or 0.0)
    local offsetDir = relativeYawPitchToVector(yaw, pitch)
    local limitedDir = _clampDirectionToConeLocal(offsetDir, limitDeg)
    local limitedYaw, limitedPitch = vectorToRelativeYawPitch(limitedDir)
    return limitedDir, limitedYaw, limitedPitch
end

local function _rearFreelookOffsetToAimLocal(shipTransform, cameraPos, shipPos)
    local orbitLocal = TransformToLocalVec(shipTransform, VecSub(cameraPos, shipPos))
    local aimLocal = Vec(
        -(orbitLocal[1] or 0.0),
        -(orbitLocal[2] or 0.0),
        -(orbitLocal[3] or 0.0)
    )
    return _safeNormalize(aimLocal, Vec(0, 0, -1))
end

local function _shipCameraResolveWeaponConfig(shipBodyId)
    local mode = (client.getShipMainWeaponMode ~= nil and shipBodyId ~= 0) and client.getShipMainWeaponMode(shipBodyId) or "xSlot"
    local defs = weaponData or {}
    if mode == "lSlot" then
        return defs.kineticArtillery or {}, mode
    end
    if mode == "sSlot" then
        return defs.swarmerMissile or {}, mode
    end
    return defs.tachyonLance or {}, "xSlot"
end

local function _shipCameraResolveXSlotFireOriginLocal(shipBodyId)
    local shipType = "enigmaticCruiser"
    if client.registryShipGetShipType ~= nil then
        local resolvedType = tostring(client.registryShipGetShipType(shipBodyId) or "")
        if resolvedType ~= "" then
            shipType = resolvedType
        end
    end

    local defs = shipTypeRegistryData or {}
    local shipDef = defs[shipType] or defs.enigmaticCruiser or {}
    local xSlots = shipDef.xSlots or {}
    local sx, sy, sz = 0.0, 0.0, 0.0
    local count = 0

    for i = 1, #xSlots do
        local slot = xSlots[i] or {}
        if tostring(slot.weaponType or "tachyonLance") == "tachyonLance" then
            local firePos = slot.firePosOffset or {}
            sx = sx + (tonumber(firePos.x) or 0.0)
            sy = sy + (tonumber(firePos.y) or 0.0)
            sz = sz + (tonumber(firePos.z) or -4.0)
            count = count + 1
        end
    end

    if count <= 0 then
        return Vec(0, 0, -4)
    end

    return Vec(sx / count, sy / count, sz / count)
end

local function _shipCameraResolveLockedXTargetLocal(shipBodyId, shipTransform)
    if client.getShipMainWeaponMode == nil or client.getShipMainWeaponMode(shipBodyId) ~= "xSlot" then
        return nil
    end
    if client.getShipXSlotFireMode == nil or client.getShipXSlotFireMode(shipBodyId) ~= "lock" then
        return nil
    end
    if client.xSlotTargetingGetLockedTargetWorld == nil then
        return nil
    end
    local targetWorld = client.xSlotTargetingGetLockedTargetWorld(shipBodyId)
    if targetWorld == nil then
        return nil
    end
    local fireOriginLocal = _shipCameraResolveXSlotFireOriginLocal(shipBodyId)
    local localPoint = TransformToLocalPoint(shipTransform, targetWorld)
    local localDir = VecSub(localPoint, fireOriginLocal)
    return _safeNormalize(localDir, Vec(0, 0, -1))
end

local function _shipCameraPushWeaponAim(cam, shipBodyId, active, localYaw, localPitch, worldDir)
    cam.weaponAimState = cam.weaponAimState or {
        active = false,
        shipBody = 0,
        localYaw = 0.0,
        localPitch = 0.0,
        worldDir = Vec(0, 0, -1),
        lastSyncAt = -1000.0,
    }

    local state = cam.weaponAimState
    state.active = active and true or false
    state.shipBody = shipBodyId or 0
    state.localYaw = tonumber(localYaw) or 0.0
    state.localPitch = tonumber(localPitch) or 0.0
    local aimDir = worldDir or Vec(0, 0, -1)
    state.worldDir = Vec(aimDir[1] or 0.0, aimDir[2] or 0.0, aimDir[3] or -1.0)

    if client.shipRequestWeaponAim == nil or shipBodyId == nil or shipBodyId == 0 then
        return
    end

    local now = (GetTime ~= nil) and GetTime() or 0.0
    local changed = state.lastSentActive == nil
        or state.lastSentActive ~= state.active
        or math.abs((state.lastSentYaw or 0.0) - state.localYaw) > 0.05
        or math.abs((state.lastSentPitch or 0.0) - state.localPitch) > 0.05
        or state.lastSentBody ~= state.shipBody
    local keepAliveDue = (now - (state.lastSyncAt or -1000.0)) >= (cam.weaponAimSyncKeepAlive or 0.2)
    if (not changed) and (not keepAliveDue) then
        return
    end

    client.shipRequestWeaponAim(shipBodyId, state.active, state.localYaw, state.localPitch)
    state.lastSentActive = state.active
    state.lastSentYaw = state.localYaw
    state.lastSentPitch = state.localPitch
    state.lastSentBody = state.shipBody
    state.lastSyncAt = now
end

local function _shipCameraClearWeaponAim(cam)
    local state = (cam or {}).weaponAimState or nil
    if state == nil then
        return
    end

    local body = math.floor(state.shipBody or 0)
    if body > 0 and client.shipRequestWeaponAim ~= nil then
        client.shipRequestWeaponAim(body, false, 0.0, 0.0)
    end

    state.active = false
    state.shipBody = 0
    state.localYaw = 0.0
    state.localPitch = 0.0
    state.worldDir = Vec(0, 0, -1)
    state.lastSentActive = false
    state.lastSentYaw = 0.0
    state.lastSentPitch = 0.0
    state.lastSentBody = 0
end

function client.shipCameraGetWeaponAimState(shipBodyId)
    local cam = client.shipCamera or {}
    local state = cam.weaponAimState or nil
    local body = math.floor(shipBodyId or 0)
    if state == nil or body <= 0 or (state.shipBody or 0) ~= body then
        return nil
    end
    return state
end

local function _copyVec(v, fallback)
    local source = v or fallback or Vec(0, 0, 0)
    return Vec(source[1] or 0.0, source[2] or 0.0, source[3] or 0.0)
end

local function _resetRearFreelookState(cam)
    cam.rearFreelookActive = false
    cam.rearFreelookSaved = nil
    cam.rearFreelookYaw = 0.0
    cam.rearFreelookPitch = 0.0
end

local function _resetFrontFreelookState(cam)
    cam.frontFreelookActive = false
end

local function _beginRearFreelook(cam, shipTransform)
    local currentCameraWorldT = GetCameraTransform()
    local currentCameraLocalT = TransformToLocalTransform(shipTransform, currentCameraWorldT)
    local orbitOffsetWorld = VecSub(currentCameraWorldT.pos, shipTransform.pos)
    local orbitRadius = VecLength(orbitOffsetWorld)
    if orbitRadius < 0.0001 then
        orbitOffsetWorld = TransformToParentVec(shipTransform, Vec(0, 0, 1))
        orbitRadius = VecLength(orbitOffsetWorld)
    end
    local orbitYawWorld, orbitPitchWorld = vectorToWorldYawPitch(
        _safeNormalize(orbitOffsetWorld, TransformToParentVec(shipTransform, Vec(0, 0, 1)))
    )

    cam.rearFreelookSaved = {
        r = cam.r,
        b = cam.b,
        c = cam.c,
        targetB = cam.targetB ~= nil and cam.targetB or cam.b,
        targetC = cam.targetC ~= nil and cam.targetC or cam.c,
        localPos = _copyVec(currentCameraLocalT.pos),
        localRot = currentCameraLocalT.rot,
        worldPos = _copyVec(currentCameraWorldT.pos),
        worldRot = currentCameraWorldT.rot,
        orbitRadius = orbitRadius,
        orbitYaw = orbitYawWorld,
        orbitPitch = orbitPitchWorld,
    }

    cam.rearFreelookYaw = orbitYawWorld
    cam.rearFreelookPitch = orbitPitchWorld
    cam.rearFreelookActive = true
    cam.bVel = 0.0
    cam.cVel = 0.0
end

local function _endRearFreelook(cam)
    local saved = cam.rearFreelookSaved or nil
    cam.rearFreelookActive = false

    if saved ~= nil then
        cam.r = saved.r or cam.r
        cam.b = saved.b or cam.b
        cam.c = saved.c or cam.c
        cam.targetB = saved.targetB or cam.b
        cam.targetC = saved.targetC or cam.c
    end

    cam.bVel = 0.0
    cam.cVel = 0.0
    cam.rearFreelookSaved = nil
    cam.rearFreelookYaw = 0.0
    cam.rearFreelookPitch = 0.0
end



local function vecLerp(a, b, t)
    return Vec(
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t
    )
end

local function _resolveFrameDt(dt, cam)
    local inDt = tonumber(dt) or 0.0
    if inDt > 0 then
        cam.lastFrameTime = (GetTime ~= nil) and GetTime() or 0
        return inDt
    end

    local now = (GetTime ~= nil) and GetTime() or 0
    local last = cam.lastFrameTime or 0
    cam.lastFrameTime = now
    if last <= 0 or now <= last then
        return 1.0 / 60.0
    end

    local measured = now - last
    if measured < (1.0 / 240.0) then
        measured = 1.0 / 240.0
    elseif measured > (1.0 / 20.0) then
        measured = 1.0 / 20.0
    end
    return measured
end

local function _stepAngleSpring(current, target, velocity, response, damping, dt)
    local error = target - current
    local v = (velocity or 0.0) + error * response * dt
    local dampFrame = math.pow(damping, dt * 60.0)
    v = v * dampFrame
    local nextValue = current + v * dt
    return nextValue, v
end

client.camshipBody = client.camshipBody or 0

function client.shipCameraGetControlledBody()
    local body = client.camshipBody or 0
    if body == 0 then
        return 0
    end

    if client.registryShipExists ~= nil and (not client.registryShipExists(body)) then
        return 0
    end

    return body
end

function client.shipCameraTick(dt)
    local cam = client.shipCamera

    if cam.rearFreelookActive == nil then cam.rearFreelookActive = false end
    if cam.frontFreelookActive == nil then cam.frontFreelookActive = false end
    if cam.rmbLongPressSeconds == nil then cam.rmbLongPressSeconds = 0.22 end
    if cam.rmbPressTime == nil then cam.rmbPressTime = 0.0 end
    if cam.rmbLongTriggered == nil then cam.rmbLongTriggered = false end

    local vehicle = GetPlayerVehicle()
    if vehicle == nil or vehicle == 0 then
        _shipCameraClearWeaponAim(cam)
        client.camshipBody = 0
        cam._lastControlledBody = 0
        _resetRearFreelookState(cam)
        _resetFrontFreelookState(cam)
        cam.rmbLongTriggered = false
        return
    end

    local playerBody = GetVehicleBody(vehicle)
    local scriptBody = client.shipBody or 0
    if scriptBody == 0 or playerBody == nil or playerBody == 0 or playerBody ~= scriptBody then
        _shipCameraClearWeaponAim(cam)
        client.camshipBody = 0
        cam._lastControlledBody = 0
        _resetRearFreelookState(cam)
        _resetFrontFreelookState(cam)
        cam.rmbLongTriggered = false
        return
    end

    local body = scriptBody
    if not HasTag(body, "stellarisShip") then
        _shipCameraClearWeaponAim(cam)
        client.camshipBody = 0
        cam._lastControlledBody = 0
        _resetRearFreelookState(cam)
        _resetFrontFreelookState(cam)
        cam.rmbLongTriggered = false
        return
    end

    if client.registryShipExists ~= nil and (not client.registryShipExists(body)) then
        _shipCameraClearWeaponAim(cam)
        client.camshipBody = 0
        cam._lastControlledBody = 0
        _resetRearFreelookState(cam)
        _resetFrontFreelookState(cam)
        cam.rmbLongTriggered = false
        return
    end

    client.camshipBody = body

    local shipTransform = GetBodyTransform(body)
    local shipPos = shipTransform.pos
    local shipForwardWorld = TransformToParentVec(shipTransform, Vec(0, 0, -1))
    local shipYawWorld = vectorToWorldYaw(shipForwardWorld)
    local shipBackYawWorld = wrapAngle180(shipYawWorld - 180)

    if cam._lastControlledBody ~= body then
        local defaultRearPitch = cam.rearDefaultPitch or 8.0
        cam.b = defaultRearPitch
        cam.c = shipBackYawWorld
        cam.targetB = defaultRearPitch
        cam.targetC = shipBackYawWorld
        cam.cVel = 0
        cam.bVel = 0
        cam.viewMode = "rear"
        cam.viewBlend = 0.0
        cam.viewBlendTarget = 0.0
        cam.frontAimYaw = 0.0
        cam.frontAimPitch = 0.0
        _resetRearFreelookState(cam)
        _resetFrontFreelookState(cam)
        cam.rmbLongTriggered = false
        cam._lastControlledBody = body
    end

    local frameDt = _resolveFrameDt(dt, cam)

    if InputPressed("rmb") then
        cam.rmbPressTime = (GetTime ~= nil) and GetTime() or 0
        cam.rmbLongTriggered = false
    end

    if InputDown("rmb") and (not cam.rmbLongTriggered) then
        local now = (GetTime ~= nil) and GetTime() or 0
        local hold = now - (cam.rmbPressTime or now)
        if hold >= (cam.rmbLongPressSeconds or 0.22) then
            cam.rmbLongTriggered = true
            if cam.viewMode == "rear" then
                _beginRearFreelook(cam, shipTransform)
            else
                cam.frontFreelookActive = true
            end
        end
    end

    if InputReleased("rmb") then
        if cam.rmbLongTriggered then
            if cam.viewMode == "rear" then
                _endRearFreelook(cam)
            else
                _resetFrontFreelookState(cam)
            end
        else
            if cam.viewMode == "rear" then
                local rearOffsetNow = sphericalToCartesian(cam.r, cam.b, cam.c)
                local rearForwardNow = VecNormalize(VecScale(rearOffsetNow, -1))
                local rearYawWorldNow, rearPitchWorldNow = vectorToWorldYawPitch(rearForwardNow)
                cam.frontAimYaw = wrapAngle180(rearYawWorldNow)
                cam.frontAimPitch = rearPitchWorldNow

                cam.viewMode = "front"
                cam.viewBlendTarget = 1.0
                _resetFrontFreelookState(cam)
            else
                cam.viewMode = "rear"
                cam.viewBlendTarget = 0.0
                cam.targetB = cam.rearDefaultPitch or 8.0
                cam.targetC = shipBackYawWorld
                _resetFrontFreelookState(cam)
            end
            _resetRearFreelookState(cam)
        end
        cam.rmbLongTriggered = false
    end

    local mouseDX = InputValue("mousedx")
    local mouseDY = InputValue("mousedy")
    local mouseWheel = InputValue("mousewheel")

    if not cam.rearFreelookActive then
        cam.r = cam.r - mouseWheel * cam.zoomSpeed
        cam.r = clamp(cam.r, cam.rMin, cam.rMax)
    end

    if cam.targetC == nil then
        cam.targetC = cam.c
    end
    if cam.targetB == nil then
        cam.targetB = cam.b
    end

    if cam.viewMode == "rear" then
        if cam.rearFreelookActive then
            cam.rearFreelookYaw = (cam.rearFreelookYaw or shipYawWorld) - mouseDX * cam.mouseSensitivity
            cam.rearFreelookPitch = (cam.rearFreelookPitch or 0.0) + mouseDY * cam.mouseSensitivity
        else
            cam.targetC = cam.targetC - mouseDX * cam.mouseSensitivity
            cam.targetB = cam.targetB + mouseDY * cam.mouseSensitivity

            cam.targetC = unwrapNear(cam.c, cam.targetC)
            cam.targetB = clamp(cam.targetB, -cam.angleLimitPitch, cam.angleLimitPitch)
            local targetRelYaw = wrapAngle180(cam.targetC - shipBackYawWorld)
            targetRelYaw = clamp(targetRelYaw, cam.angleLimitYaw1, cam.angleLimitYaw2)
            cam.targetC = shipBackYawWorld + targetRelYaw
        end
    else
        local frontPitchLimit = cam.frontAimPitchLimit or cam.angleLimitPitch

        -- Front mode mouse feel matches rear mode (left drag -> left target).
        cam.frontAimYaw = wrapAngle180((cam.frontAimYaw or shipYawWorld) - mouseDX * cam.mouseSensitivity)
        cam.frontAimPitch = (cam.frontAimPitch or 0.0) - mouseDY * cam.mouseSensitivity

        cam.frontAimPitch = clamp(cam.frontAimPitch, -frontPitchLimit, frontPitchLimit)
    end

    local glide = clamp(cam.glideStrength or 0.55, 0.0, 1.0)
    local smoothResponse = 32.0 - 22.0 * glide
    local smoothDamping = 0.70 + 0.28 * glide

    if not cam.rearFreelookActive then
        cam.b, cam.bVel = _stepAngleSpring(cam.b, cam.targetB, cam.bVel, smoothResponse, smoothDamping, frameDt)
        cam.c, cam.cVel = _stepAngleSpring(cam.c, cam.targetC, cam.cVel, smoothResponse, smoothDamping, frameDt)

        cam.c = unwrapNear(cam.targetC, cam.c)
        cam.b = clamp(cam.b, -cam.angleLimitPitch, cam.angleLimitPitch)
        local currentRelYaw = wrapAngle180(cam.c - shipBackYawWorld)
        currentRelYaw = clamp(currentRelYaw, cam.angleLimitYaw1, cam.angleLimitYaw2)
        cam.c = shipBackYawWorld + currentRelYaw
    else
        cam.bVel = 0.0
        cam.cVel = 0.0
    end

    local offsetWorld = sphericalToCartesian(cam.r, cam.b, cam.c)
    local rearCameraPos = VecAdd(shipPos, offsetWorld)
    local rearForwardWorld = VecNormalize(VecSub(shipPos, rearCameraPos))

    local frontLocal = cam.frontOffset or { x = 0, y = 0, z = -3 }
    local frontCameraPos = TransformToParentPoint(shipTransform, Vec(frontLocal.x or 0, frontLocal.y or 0, frontLocal.z or -3))

    local desiredYaw = cam.frontAimYaw or shipYawWorld
    local desiredPitch = cam.frontAimPitch or 0.0
    local desiredWorldDir = worldYawPitchToVector(desiredYaw, desiredPitch)
    local desiredLocalDir = TransformToLocalVec(shipTransform, desiredWorldDir)
    local frontRelYaw, frontRelPitch = vectorToRelativeYawPitch(desiredLocalDir)

    local frontYaw1 = cam.frontAimYaw1 or -85
    local frontYaw2 = cam.frontAimYaw2 or 85
    local frontPitchLimit = cam.frontAimPitchLimit or 85

    frontRelYaw = clamp(wrapAngle180(frontRelYaw), frontYaw1, frontYaw2)
    frontRelPitch = clamp(frontRelPitch, -frontPitchLimit, frontPitchLimit)

    local frontForwardLocal = relativeYawPitchToVector(frontRelYaw, frontRelPitch)
    local frontForwardWorld = VecNormalize(TransformToParentVec(shipTransform, frontForwardLocal))

    local frontErrorYaw = frontRelYaw
    local frontErrorPitch = frontRelPitch

    local duration = cam.switchDuration or 0.30
    if duration < 0.01 then
        duration = 0.01
    end
    local step = frameDt / duration
    if cam.viewBlendTarget > cam.viewBlend then
        cam.viewBlend = math.min(cam.viewBlendTarget, cam.viewBlend + step)
    elseif cam.viewBlendTarget < cam.viewBlend then
        cam.viewBlend = math.max(cam.viewBlendTarget, cam.viewBlend - step)
    end
    local blend = clamp(cam.viewBlend, 0.0, 1.0)

    local cameraPos = vecLerp(rearCameraPos, frontCameraPos, blend)
    local blendedForward = vecLerp(rearForwardWorld, frontForwardWorld, blend)
    if cam.rearFreelookActive then
        local saved = cam.rearFreelookSaved or {}
        local orbitRadius = saved.orbitRadius or cam.r
        local orbitYaw = cam.rearFreelookYaw
        if orbitYaw == nil then
            orbitYaw = saved.orbitYaw or shipBackYawWorld
        end
        local orbitPitch = cam.rearFreelookPitch
        if orbitPitch == nil then
            orbitPitch = saved.orbitPitch or 0.0
        end
        cameraPos = VecAdd(shipPos, sphericalToCartesian(orbitRadius, orbitPitch, orbitYaw))
        blendedForward = _safeNormalize(VecSub(shipPos, cameraPos), rearForwardWorld)
    elseif VecLength(blendedForward) < 0.0001 then
        blendedForward = rearForwardWorld
    else
        blendedForward = VecNormalize(blendedForward)
    end

    local cameraRot = QuatLookAt(cameraPos, VecAdd(cameraPos, blendedForward))
    local cameraWorldT = Transform(cameraPos, cameraRot)
    local cameraLocalT = TransformToLocalTransform(shipTransform, cameraWorldT)

    AttachCameraTo(body, false)
    SetCameraOffsetTransform(cameraLocalT)

    if client.shipRequestRotationError == nil then
        return
    end

    local yawError = 0.0
    local pitchError = 0.0
    local steerYaw = 0.0
    if InputDown("a") and (not InputDown("d")) then
        steerYaw = -(cam.freelookTurnYawError or 16.0)
    elseif InputDown("d") and (not InputDown("a")) then
        steerYaw = cam.freelookTurnYawError or 16.0
    end

    if cam.viewMode == "front" then
        if cam.frontFreelookActive then
            yawError = steerYaw
            pitchError = 0.0
        else
            yawError = frontErrorYaw + steerYaw
            pitchError = frontErrorPitch
        end
    elseif cam.rearFreelookActive then
        yawError = steerYaw
        pitchError = 0.0
    else
        local camForwardWorld = rearForwardWorld
        local camForwardLocal = TransformToLocalVec(shipTransform, camForwardWorld)
        local camAzimuth, camZenith = vectorToRelativeYawPitch(camForwardLocal)
        yawError = wrapAngle180(camAzimuth)
        pitchError = camZenith
    end

    local weaponConfig, currentMode = _shipCameraResolveWeaponConfig(body)
    local lockedTargetLocalDir = _shipCameraResolveLockedXTargetLocal(body, shipTransform)
    local weaponAimActive = (cam.rearFreelookActive or cam.frontFreelookActive or lockedTargetLocalDir ~= nil)
        and (currentMode == "xSlot" or currentMode == "lSlot")
        and tostring(weaponConfig.aimControlMode or "fixed") == "camera_limited"
    local weaponAimWorldDir = rearForwardWorld
    local weaponAimLocalYaw = 0.0
    local weaponAimLocalPitch = 0.0
    if weaponAimActive then
        local viewLocalDir = TransformToLocalVec(shipTransform, blendedForward)
        if cam.rearFreelookActive then
            viewLocalDir = _rearFreelookOffsetToAimLocal(shipTransform, cameraPos, shipPos)
        end
        if lockedTargetLocalDir ~= nil then
            viewLocalDir = lockedTargetLocalDir
        end
        local limitedDir, limitedYaw, limitedPitch = _resolveRelativeAimVector(
            viewLocalDir,
            (lockedTargetLocalDir ~= nil) and 0.0 or (tonumber(weaponConfig.aimPitchOffsetDeg) or 0.0),
            tonumber(weaponConfig.aimLimitDeg) or 0.0
        )
        weaponAimWorldDir = _safeNormalize(TransformToParentVec(shipTransform, limitedDir), rearForwardWorld)
        weaponAimLocalYaw = limitedYaw
        weaponAimLocalPitch = limitedPitch
    end
    _shipCameraPushWeaponAim(cam, body, weaponAimActive, weaponAimLocalYaw, weaponAimLocalPitch, weaponAimWorldDir)

    client.shipRequestRotationError(body, pitchError, yawError)
end
