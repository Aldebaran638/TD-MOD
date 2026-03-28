---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.shipCamera = client.shipCamera or {
    r = 30,
    b = 0,
    c = 0,

    rMin = 20,
    rMax = 40,

    angleLimitPitch = 85,
    angleLimitYaw1 = -90,
    angleLimitYaw2 = 90,

    -- tuning knobs
    mouseSensitivity = 0.05,
    glideStrength = 0.55, -- 0.0=almost no glide, 1.0=very floaty
    zoomSpeed = 0.5,
    switchDuration = 0.30,
    frontOffset = { x = 0, y = 3, z = -7 },
    viewMode = "rear",
    viewBlend = 0.0,
    viewBlendTarget = 0.0,
    frontAimPitchLimit = 85,
    frontAimYaw1 = -85,
    frontAimYaw2 = 85,
    frontAimYaw = 0.0,
    frontAimPitch = 0.0,

    rearFreelookActive = false,
    rmbLongPressSeconds = 0.22,
    rmbPressTime = 0.0,
    rmbLongTriggered = false,
    fov = 70,
    hitShakeTime = 0.0,
    hitShakeDuration = 0.0,
    hitShakeAmplitude = 0.0,
    hitShakeSeed = 0.0,
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

local function _resetHitShakeState(cam)
    cam.hitShakeTime = 0.0
    cam.hitShakeDuration = 0.0
    cam.hitShakeAmplitude = 0.0
    cam.hitShakeSeed = 0.0
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

function client.startTitanHitShake(shipBodyId, amplitude, duration)
    local targetBody = math.floor(shipBodyId or 0)
    if targetBody <= 0 then
        return
    end

    local controlledBody = 0
    if client.shipCameraGetControlledBody ~= nil then
        controlledBody = client.shipCameraGetControlledBody()
    end
    if controlledBody == nil or controlledBody == 0 then
        local veh = GetPlayerVehicle()
        if veh ~= nil and veh ~= 0 then
            controlledBody = GetVehicleBody(veh)
        end
    end
    if controlledBody == nil or controlledBody == 0 or controlledBody ~= targetBody then
        return
    end

    local cam = client.shipCamera
    local amp = math.max(0.0, tonumber(amplitude) or 0.0)
    local dur = math.max(0.0, tonumber(duration) or 0.0)
    if amp <= 0.0 or dur <= 0.0 then
        return
    end

    cam.hitShakeTime = math.max(cam.hitShakeTime or 0.0, dur)
    cam.hitShakeDuration = math.max(cam.hitShakeDuration or 0.0, dur)
    cam.hitShakeAmplitude = math.max(cam.hitShakeAmplitude or 0.0, amp)
    cam.hitShakeSeed = ((GetTime ~= nil) and GetTime() or 0.0) * 37.0 + targetBody * 0.17
end

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
    if cam.rmbLongPressSeconds == nil then cam.rmbLongPressSeconds = 0.22 end
    if cam.rmbPressTime == nil then cam.rmbPressTime = 0.0 end
    if cam.rmbLongTriggered == nil then cam.rmbLongTriggered = false end

    local vehicle = GetPlayerVehicle()
    if vehicle == nil or vehicle == 0 then
        client.camshipBody = 0
        cam._lastControlledBody = 0
        _resetRearFreelookState(cam)
        _resetHitShakeState(cam)
        cam.rmbLongTriggered = false
        return
    end

    local playerBody = GetVehicleBody(vehicle)
    local scriptBody = client.shipBody or 0
    if scriptBody == 0 or playerBody == nil or playerBody == 0 or playerBody ~= scriptBody then
        client.camshipBody = 0
        cam._lastControlledBody = 0
        _resetRearFreelookState(cam)
        _resetHitShakeState(cam)
        cam.rmbLongTriggered = false
        return
    end

    local body = scriptBody
    if not HasTag(body, "stellarisShip") then
        client.camshipBody = 0
        cam._lastControlledBody = 0
        _resetRearFreelookState(cam)
        _resetHitShakeState(cam)
        cam.rmbLongTriggered = false
        return
    end

    if client.registryShipExists ~= nil and (not client.registryShipExists(body)) then
        client.camshipBody = 0
        cam._lastControlledBody = 0
        _resetRearFreelookState(cam)
        _resetHitShakeState(cam)
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
        cam.c = shipBackYawWorld
        cam.targetC = shipBackYawWorld
        cam.targetB = cam.b
        cam.cVel = 0
        cam.viewMode = "rear"
        cam.viewBlend = 0.0
        cam.viewBlendTarget = 0.0
        cam.frontAimYaw = 0.0
        cam.frontAimPitch = 0.0
        _resetRearFreelookState(cam)
        _resetHitShakeState(cam)
        cam.rmbLongTriggered = false
        cam._lastControlledBody = body
    end

    local frameDt = _resolveFrameDt(dt, cam)
    if (cam.hitShakeTime or 0.0) > 0.0 then
        cam.hitShakeTime = math.max(0.0, (cam.hitShakeTime or 0.0) - frameDt)
        if cam.hitShakeTime <= 0.0 then
            _resetHitShakeState(cam)
        end
    end

    if InputPressed("rmb") then
        cam.rmbPressTime = (GetTime ~= nil) and GetTime() or 0
        cam.rmbLongTriggered = false
    end

    if cam.viewMode == "rear" and InputDown("rmb") and (not cam.rmbLongTriggered) then
        local now = (GetTime ~= nil) and GetTime() or 0
        local hold = now - (cam.rmbPressTime or now)
        if hold >= (cam.rmbLongPressSeconds or 0.22) then
            cam.rmbLongTriggered = true
            _beginRearFreelook(cam, shipTransform)
        end
    end

    if InputReleased("rmb") then
        if cam.rmbLongTriggered then
            _endRearFreelook(cam)
        else
            if cam.viewMode == "rear" then
                local rearOffsetNow = sphericalToCartesian(cam.r, cam.b, cam.c)
                local rearForwardNow = VecNormalize(VecScale(rearOffsetNow, -1))
                local rearYawWorldNow, rearPitchWorldNow = vectorToWorldYawPitch(rearForwardNow)
                cam.frontAimYaw = wrapAngle180(rearYawWorldNow)
                cam.frontAimPitch = rearPitchWorldNow

                cam.viewMode = "front"
                cam.viewBlendTarget = 1.0
            else
                cam.viewMode = "rear"
                cam.viewBlendTarget = 0.0
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

    if (cam.hitShakeTime or 0.0) > 0.0 and (cam.hitShakeDuration or 0.0) > 0.0 and (cam.hitShakeAmplitude or 0.0) > 0.0 then
        local time = (GetTime ~= nil) and GetTime() or 0.0
        local fade = (cam.hitShakeTime or 0.0) / math.max(0.0001, cam.hitShakeDuration or 0.0)
        local amp = (cam.hitShakeAmplitude or 0.0) * fade
        local seed = cam.hitShakeSeed or 0.0
        local shakeOffset = Vec(
            math.sin(time * 91.0 + seed * 1.7),
            math.sin(time * 123.0 + seed * 2.3 + 1.1),
            math.sin(time * 157.0 + seed * 3.1 + 2.2)
        )
        cameraLocalT.pos = VecAdd(cameraLocalT.pos, VecScale(shakeOffset, amp))
    end

    AttachCameraTo(body, false)
    SetCameraOffsetTransform(cameraLocalT)

    if client.shipRequestRotationError == nil then
        return
    end

    local yawError = 0.0
    local pitchError = 0.0

    if cam.viewMode == "front" then
        yawError = frontErrorYaw
        pitchError = frontErrorPitch
    elseif cam.rearFreelookActive then
        yawError = 0.0
        pitchError = 0.0
    else
        local camForwardWorld = rearForwardWorld
        local camForwardLocal = TransformToLocalVec(shipTransform, camForwardWorld)
        local camAzimuth, camZenith = vectorToRelativeYawPitch(camForwardLocal)
        yawError = wrapAngle180(camAzimuth)
        pitchError = camZenith
    end

    client.shipRequestRotationError(body, pitchError, yawError)
end
