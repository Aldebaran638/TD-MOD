---@diagnostic disable: undefined-global

client = client or {}

client.shipSensorHudState = client.shipSensorHudState or {
    scanRemain = 0.0,
    range = 0.0,
    targets = {},
}

local function _sensorShipSize(shipType)
    local id = string.lower(tostring(shipType or ""))
    if string.find(id, "paradox", 1, true)
        or string.find(id, "titan", 1, true) then return 16 end
    if string.find(id, "battlecruiser", 1, true)
        or string.find(id, "enigmaticcruiser", 1, true)
        or string.find(id, "battleship", 1, true) then return 8 end
    if string.find(id, "cruiser", 1, true) then return 4 end
    if string.find(id, "frigate", 1, true)
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
    state.targets = {}
end

function client.shipSensorHudTick(dt)
    local state = client.shipSensorHudState
    local ownBody = _sensorLocalShipBody()
    if ownBody == 0 then
        state.targets = {}
        state.scanRemain = 0.0
        return
    end

    local sensor = _sensorProfile()
    state.range = math.max(0.0, tonumber(sensor.range) or 0.0)
    state.scanRemain = math.max(0.0, state.scanRemain - (dt or 0.0))
    if state.range <= 0.0 or state.scanRemain > 0.0 then return end
    state.scanRemain = math.max(0.05, tonumber(sensor.interval) or 1.0)

    local ownPos = GetBodyTransform(ownBody).pos
    local targets = {}
    for _, body in ipairs(client.registryShipGetRegisteredBodyIds()) do
        if body ~= ownBody and client.registryShipExists(body)
            and (IsHandleValid == nil or IsHandleValid(body)) then
            local minBounds, maxBounds = GetBodyBounds(body)
            local center = VecLerp(minBounds, maxBounds, 0.5)
            local distance = VecLength(VecSub(center, ownPos))
            local _, _, hull = client.registryShipGetHP(body)
            if distance <= state.range and (tonumber(hull) or 0.0) > 0.0 then
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
    table.sort(targets, function(a, b) return a.distance < b.distance end)
    state.targets = targets
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

local function _sensorDrawEdgeArrow(x, y, angle, target)
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
        UiColor(0.25, 0.92, 0.72, 0.92)
        for _, target in ipairs(state.targets) do
            local x, y, cameraDistance = UiWorldToPixel(target.position)
            local onScreen = cameraDistance > 0.0
                and x >= margin and x <= width - margin
                and y >= margin and y <= height - margin
            if onScreen then
                local apparent = target.size * 150.0
                    / math.max(20.0, target.distance)
                local frameSize = math.max(34.0, math.min(88.0,
                    30.0 + math.sqrt(target.size) * 7.0 + apparent))
                _sensorDrawCorners(x, y, frameSize)
                UiPush()
                    UiTranslate(x, y + frameSize * 0.5 + 7)
                    UiAlign("center top")
                    UiFont("regular.ttf", 11)
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
                _sensorDrawEdgeArrow(
                    edgeX,
                    edgeY,
                    math.deg(math.atan2(dy, dx)),
                    target
                )
            end
        end
    UiPop()
end
