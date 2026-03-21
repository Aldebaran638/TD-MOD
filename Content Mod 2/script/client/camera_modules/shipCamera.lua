---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.shipCamera = client.shipCamera or {
    r = 14,
    b = 45,
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
    local vehicle = GetPlayerVehicle()
    if vehicle == nil or vehicle == 0 then
        client.camshipBody = 0
        return
    end

    local playerBody = GetVehicleBody(vehicle)
    local scriptBody = client.shipBody or 0
    if scriptBody == 0 or playerBody == nil or playerBody == 0 or playerBody ~= scriptBody then
        client.camshipBody = 0
        return
    end

    local body = scriptBody
    if not HasTag(body, "stellarisShip") then
        client.camshipBody = 0
        return
    end

    if client.registryShipExists ~= nil and (not client.registryShipExists(body)) then
        client.camshipBody = 0
        return
    end

    client.camshipBody = body

    local cam = client.shipCamera
    local shipTransform = GetBodyTransform(body)
    local shipPos = shipTransform.pos
    local shipForwardWorld = TransformToParentVec(shipTransform, Vec(0, 0, -1))
    local shipYawWorld = vectorToWorldYaw(shipForwardWorld)
    local shipBackYawWorld = wrapAngle180(shipYawWorld - 180)

    if cam._lastControlledBody ~= body then
        cam.c = shipBackYawWorld
        cam.targetC = shipBackYawWorld
        cam.cVel = 0
        cam._lastControlledBody = body
    end

    local frameDt = _resolveFrameDt(dt, cam)

    local mouseDX = InputValue("mousedx")
    local mouseDY = InputValue("mousedy")
    local mouseWheel = InputValue("mousewheel")

    if cam.targetC == nil then
        cam.targetC = cam.c
    end
    if cam.targetB == nil then
        cam.targetB = cam.b
    end

    cam.targetC = cam.targetC - mouseDX * cam.mouseSensitivity
    cam.targetB = cam.targetB + mouseDY * cam.mouseSensitivity
    cam.r = cam.r - mouseWheel * cam.zoomSpeed

    cam.targetC = unwrapNear(cam.c, cam.targetC)
    cam.r = clamp(cam.r, cam.rMin, cam.rMax)
    cam.targetB = clamp(cam.targetB, -cam.angleLimitPitch, cam.angleLimitPitch)
    local targetRelYaw = wrapAngle180(cam.targetC - shipBackYawWorld)
    targetRelYaw = clamp(targetRelYaw, cam.angleLimitYaw1, cam.angleLimitYaw2)
    cam.targetC = shipBackYawWorld + targetRelYaw

    -- Convert single glide knob into spring response/damping.
    local glide = clamp(cam.glideStrength or 0.55, 0.0, 1.0)
    local smoothResponse = 32.0 - 22.0 * glide
    local smoothDamping = 0.70 + 0.28 * glide

    cam.b, cam.bVel = _stepAngleSpring(cam.b, cam.targetB, cam.bVel, smoothResponse, smoothDamping, frameDt)
    cam.c, cam.cVel = _stepAngleSpring(cam.c, cam.targetC, cam.cVel, smoothResponse, smoothDamping, frameDt)

    cam.c = unwrapNear(cam.targetC, cam.c)
    cam.b = clamp(cam.b, -cam.angleLimitPitch, cam.angleLimitPitch)
    local currentRelYaw = wrapAngle180(cam.c - shipBackYawWorld)
    currentRelYaw = clamp(currentRelYaw, cam.angleLimitYaw1, cam.angleLimitYaw2)
    cam.c = shipBackYawWorld + currentRelYaw

    -- World-space orbit offset (camera does not rigidly rotate with ship).
    local offsetWorld = sphericalToCartesian(cam.r, cam.b, cam.c)
    local cameraPos = VecAdd(shipPos, offsetWorld)

    local cameraRot = QuatLookAt(cameraPos, shipPos)
    local cameraWorldT = Transform(cameraPos, cameraRot)
    local cameraLocalT = TransformToLocalTransform(shipTransform, cameraWorldT)

    AttachCameraTo(body, false)
    SetCameraOffsetTransform(cameraLocalT)

    if client.registryShipSetRotationError == nil then
        return
    end

    local camForwardWorld = VecNormalize(VecSub(shipPos, cameraPos))
    local camForwardLocal = TransformToLocalVec(shipTransform, camForwardWorld)
    local camAzimuth, camZenith = vectorToRelativeYawPitch(camForwardLocal)

    local yawError = wrapAngle180(camAzimuth)
    local pitchError = camZenith

    client.registryShipSetRotationError(body, pitchError, yawError)
end
