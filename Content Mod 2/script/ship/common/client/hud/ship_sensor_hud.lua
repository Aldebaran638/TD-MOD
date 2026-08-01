---@diagnostic disable: undefined-global

client = client or {}

client.shipSensorHudState = client.shipSensorHudState or {
    scanRemain = 0.0,
    range = 0.0,
    pings = {},
}

local _sensorScanInterval = 3.0
local _sensorPingLifetime = 1.0
local _sensorColor = { 0.96, 0.18, 0.20 }

local function _setSensorColor(alpha)
    UiColor(_sensorColor[1], _sensorColor[2], _sensorColor[3], alpha or 1.0)
end

local function _sensorShipSize(shipType)
    local id = string.lower(tostring(shipType or ""))
    if string.find(id, "externalboss", 1, true)
        or string.find(id, "dragon", 1, true) then return 16 end
    if string.find(id, "paradox", 1, true)
        or string.find(id, "titan", 1, true) then return 16 end
    if string.find(id, "battlecruiser", 1, true)
        or string.find(id, "enigmaticcruiser", 1, true)
        or string.find(id, "battleship", 1, true) then return 8 end
    if string.find(id, "cruiser", 1, true) then return 4 end
    if string.find(id, "frigate", 1, true) then return 1 end
    if string.find(id, "strike", 1, true)
        or string.find(id, "fighter", 1, true)
        or string.find(id, "bomber", 1, true)
        or string.find(id, "destroyer", 1, true)
        or string.find(id, "escort", 1, true) then return 2 end
    return 1
end

local function _sensorLocalShipBody()
    local vehicle = GetPlayerVehicle(GetLocalPlayer())
    if vehicle == nil or vehicle == 0 then return 0 end
    local body = GetVehicleBody(vehicle)
    if body ~= client.shipContextGetBody() then return 0 end
    return body
end

local function _sensorProfile()
    if client.getShipSensorProfile ~= nil then
        return client.getShipSensorProfile(_sensorLocalShipBody()) or {}
    end
    local binding = client.weaponConfigurationBindingState or {}
    local snapshot = binding.snapshot or {}
    local shipType = tostring(binding.shipType or client.shipContextGetType())
    local definition = (shipTypeRegistryData or {})[shipType]
        or client.shipContextGetDefinition() or {}
    local configuration = shipComponentFindConfiguration(
        definition,
        snapshot.configurationId
    )
    return shipComponentResolveProfile(
        definition,
        snapshot.componentLoadout,
        configuration,
        snapshot.loadout
    ).sensor or {}
end

function client.shipSensorHudInit()
    local state = client.shipSensorHudState
    state.scanRemain = 0.0
    state.range = 0.0
    state.pings = {}
end

function client.shipSensorHudTick(dt)
    local state = client.shipSensorHudState
    local ownBody = _sensorLocalShipBody()
    if ownBody == 0 then
        state.pings = {}
        state.scanRemain = 0.0
        return
    end

    local sensor = _sensorProfile()
    state.range = math.max(0.0, tonumber(sensor.range) or 0.0)
    local frameDt = math.max(0.0, tonumber(dt) or 0.0)
    state.scanRemain = math.max(0.0, state.scanRemain - frameDt)
    for index = #(state.pings or {}), 1, -1 do
        local ping = state.pings[index]
        ping.age = (tonumber(ping.age) or 0.0) + frameDt
        if ping.age >= _sensorPingLifetime then
            table.remove(state.pings, index)
        end
    end
    if state.range <= 0.0 or state.scanRemain > 0.0 then return end
    -- Stellaris sensor contacts are pulses, not a continuously tracked lock.
    state.scanRemain = _sensorScanInterval

    local ownPos = GetBodyTransform(ownBody).pos
    local targets = {}
    for _, body in ipairs(client.registryShipGetRegisteredBodyIds()) do
        if body ~= ownBody and client.registryShipExists(body)
            and (IsHandleValid == nil or IsHandleValid(body)) then
            local interceptorClass = client.registryShipGetInterceptorClass ~= nil
                and client.registryShipGetInterceptorClass(body) or ""
            local playerLockable = client.registryShipIsPlayerLockable == nil
                or client.registryShipIsPlayerLockable(body)
            local minBounds, maxBounds = GetBodyBounds(body)
            local center = VecLerp(minBounds, maxBounds, 0.5)
            local distance = VecLength(VecSub(center, ownPos))
            local _, _, hull = client.registryShipGetHP(body)
            if distance <= state.range
                and interceptorClass == ""
                and playerLockable
                and (tonumber(hull) or 0.0) > 0.0 then
                local shipType = client.registryShipGetShipType(body)
                targets[#targets + 1] = {
                    body = body,
                    position = center,
                    distance = distance,
                    shipType = shipType,
                    size = _sensorShipSize(shipType),
                }
            end
        end
    end
    if client.weaponTargetFindExternalBodies ~= nil then
        for _, body in ipairs(client.weaponTargetFindExternalBodies() or {}) do
            if body ~= ownBody and (IsHandleValid == nil or IsHandleValid(body)) then
                local minBounds, maxBounds = GetBodyBounds(body)
                local center = VecLerp(minBounds, maxBounds, 0.5)
                local distance = VecLength(VecSub(center, ownPos))
                if distance <= state.range then
                    targets[#targets + 1] = {
                        body = body,
                        position = center,
                        distance = distance,
                        shipType = "externalBoss",
                        size = _sensorShipSize("externalBoss"),
                    }
                end
            end
        end
    end
    table.sort(targets, function(a, b) return a.distance < b.distance end)
    state.pings = {}
    for _, target in ipairs(targets) do
        state.pings[#state.pings + 1] = {
            target = target,
            age = 0.0,
        }
    end
end

local function _sensorDrawCorners(x, y, size)
    local half = size * 0.5
    local arm = math.max(7.0, size * 0.23)
    UiPush()
        UiTranslate(x - half, y - half)
        UiRect(arm, 2)
        UiRect(2, arm)
        UiTranslate(size, 0)
        UiTranslate(-arm, 0)
        UiRect(arm, 2)
        UiTranslate(arm - 2, 0)
        UiRect(2, arm)
        UiTranslate(0, size - arm)
        UiRect(2, arm)
        UiTranslate(-(arm - 2), arm - 2)
        UiRect(arm, 2)
        UiTranslate(-(size - arm), 0)
        UiRect(arm, 2)
        UiTranslate(0, -(arm - 2))
        UiRect(2, arm)
    UiPop()
end

local function _sensorDrawEdgeArrow(x, y, angle, target, alpha)
    UiPush()
        UiTranslate(x, y)
        UiRotate(angle)
        UiTranslate(-15, -1)
        UiRect(30, 2)
        UiTranslate(21, -7)
        UiRotate(45)
        UiRect(12, 2)
        UiRotate(-90)
        UiTranslate(-1, -1)
        UiRect(12, 2)
    UiPop()
    UiPush()
        UiTranslate(x, y + 14)
        UiAlign("center top")
        UiFont("regular.ttf", 10)
        _setSensorColor(alpha)
        UiText("S" .. tostring(target.size) .. "  "
            .. string.format("%.0fm", target.distance))
    UiPop()
end

function client.shipSensorHudDraw()
    if _sensorLocalShipBody() == 0 then return end
    local state = client.shipSensorHudState
    if state.range <= 0.0 then return end

    local width, height = UiWidth(), UiHeight()
    local centerX, centerY = width * 0.5, height * 0.5
    local margin = 46.0
    UiPush()
        _setSensorColor(0.92)
        for _, ping in ipairs(state.pings or {}) do
            local target = ping.target or {}
            local alpha = math.max(0.0, 1.0
                - (tonumber(ping.age) or 0.0) / _sensorPingLifetime)
            local x, y, cameraDistance = UiWorldToPixel(target.position)
            local onScreen = cameraDistance > 0.0
                and x >= margin and x <= width - margin
                and y >= margin and y <= height - margin
            if onScreen then
                local apparent = target.size * 150.0
                    / math.max(20.0, target.distance)
                local frameSize = math.max(34.0, math.min(88.0,
                    30.0 + math.sqrt(target.size) * 7.0 + apparent))
                _setSensorColor(alpha)
                _sensorDrawCorners(x, y, frameSize)
                local rippleSize = frameSize + 24.0
                    + 72.0 * math.max(0.0, math.min(1.0,
                        (tonumber(ping.age) or 0.0) / _sensorPingLifetime))
                UiPush()
                    UiTranslate(x, y)
                    UiAlign("center middle")
                    _setSensorColor(alpha * 0.55)
                    UiRectOutline(rippleSize, rippleSize, 1)
                UiPop()
                UiPush()
                    UiTranslate(x, y + frameSize * 0.5 + 7)
                    UiAlign("center top")
                    UiFont("regular.ttf", 11)
                    _setSensorColor(alpha)
                    UiText("S" .. tostring(target.size) .. "  "
                        .. string.format("%.0fm", target.distance))
                UiPop()
            else
                local dx, dy = x - centerX, y - centerY
                if cameraDistance < 0.0 then dx, dy = -dx, -dy end
                if math.abs(dx) + math.abs(dy) < 0.001 then dy = -1.0 end
                local scale = math.min(
                    (centerX - margin) / math.max(0.001, math.abs(dx)),
                    (centerY - margin) / math.max(0.001, math.abs(dy))
                )
                local edgeX = centerX + dx * scale
                local edgeY = centerY + dy * scale
                _setSensorColor(alpha)
                _sensorDrawEdgeArrow(
                    edgeX,
                    edgeY,
                    math.deg(math.atan2(dy, dx)),
                    target,
                    alpha
                )
            end
        end
    UiPop()
end
