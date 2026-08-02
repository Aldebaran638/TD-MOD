---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}
server = server or {}

local SpaceBoundary = {
    center = Vec(0, 60, 0),
    softRadius = 3600.0,
    hardRadius = 4200.0,
    refreshInterval = 1.0,
}

local Nebulae = {
    { Vec(7600, 3700, -8400), 7800, 5700, Vec(0.18, 0.28, 0.52), 0.23 },
    { Vec(-9000, -2300, 6900), 7000, 5000, Vec(0.40, 0.17, 0.34), 0.16 },
    { Vec(5300, -6600, 8500), 6000, 4400, Vec(0.12, 0.34, 0.38), 0.12 },
}

local _spaceState = {
    shipBodies = {},
    refreshAge = 0.0,
    starSprite = 0,
    nebulaSprite = 0,
    stars = {},
    celestialBodies = {},
    celestialSprites = {},
    celestialRefreshAge = 0.0,
}

local CelestialProfiles = {
    star_g_yellow = {
        radius = 220.0,
        sprite = "MOD/gfx/space/celestial/star_g_yellow.png",
        star = true,
    },
    planet_continental = {
        radius = 63.0,
        sprite = "MOD/gfx/space/celestial/planet_continental.png",
    },
    planet_desert = {
        radius = 69.0,
        sprite = "MOD/gfx/space/celestial/planet_desert.png",
    },
    planet_gas_giant_ringed = {
        radius = 96.0,
        sprite = "MOD/gfx/space/celestial/planet_gas_giant_ringed.png",
    },
    planet_frozen = {
        radius = 74.0,
        sprite = "MOD/gfx/space/celestial/planet_frozen.png",
    },
    planet_volcanic = {
        radius = 79.0,
        sprite = "MOD/gfx/space/celestial/planet_volcanic.png",
    },
    planet_ocean = {
        radius = 84.0,
        sprite = "MOD/gfx/space/celestial/planet_ocean.png",
    },
}

local CelestialLod = {
    -- Keep impostors inside Teardown's practical scene draw distance. Their
    -- world size is scaled below so the original celestial angular size is
    -- preserved even though the proxy is much closer to the camera.
    fadeStart = 280.0,
    fadeEnd = 420.0,
    proxyDistance = 180.0,
}

local BackgroundLod = {
    referenceDistance = 940.0,
    nebulaDistance = 185.0,
    starDistance = 175.0,
}

local function _spaceClamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function _spaceSmoothStep(value)
    local t = _spaceClamp(value, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)
end

local function _spaceValue(index, salt)
    local value = math.sin(index * 12.9898 + salt * 78.233) * 43758.5453
    return value - math.floor(value)
end

local function _configureSpaceEnvironment()
    SetEnvironmentDefault()
    SetEnvironmentProperty("skybox", "cloudy.dds")
    SetEnvironmentProperty("skyboxtint", 0.12, 0.16, 0.28)
    SetEnvironmentProperty("skyboxbrightness", 0.05)
    SetEnvironmentProperty("ambient", 1.0)
    SetEnvironmentProperty("sunBrightness", 0.0)
    SetEnvironmentProperty("fogColor", 0.004, 0.007, 0.016)
    SetEnvironmentProperty("fogParams", 5000, 15000, 0.08, 0.12)
    SetEnvironmentProperty("exposure", 1.0, 5)
    SetEnvironmentProperty("nightlight", true)
    SetEnvironmentProperty("ambience", "outdoor/night.ogg")
    SetPostProcessingDefault()
    SetPostProcessingProperty("gamma", 0.92)
    SetPostProcessingProperty("bloom", 1.15)
end

local function _isMajorShipBody(body)
    return body ~= nil
        and body ~= 0
        and IsHandleValid(body)
        and IsBodyDynamic(body)
        and not HasTag(body, "stellarisStrikeCraft")
end

local function _refreshBoundaryShips()
    local ships = {}
    for _, body in ipairs(FindBodies("stellarisShip", true) or {}) do
        if _isMajorShipBody(body) then
            ships[#ships + 1] = body
        end
    end
    _spaceState.shipBodies = ships
end

local function _applySoftBoundary(body, dt)
    dt = math.max(0.0, tonumber(dt) or 0.0)
    if dt <= 0.0 then
        return
    end
    local position = GetBodyTransform(body).pos
    local offset = VecSub(position, SpaceBoundary.center)
    local distance = VecLength(offset)
    if distance <= SpaceBoundary.softRadius or distance <= 0.001 then
        return
    end

    local outward = VecScale(offset, 1.0 / distance)
    local velocity = GetBodyVelocity(body)
    local outwardSpeed = VecDot(velocity, outward)
    local band = SpaceBoundary.hardRadius - SpaceBoundary.softRadius
    local ratio = _spaceClamp((distance - SpaceBoundary.softRadius) / band, 0.0, 1.0)
    local nextVelocity = velocity

    if outwardSpeed > 0.0 then
        local removedSpeed
        if distance >= SpaceBoundary.hardRadius then
            removedSpeed = outwardSpeed
        else
            local dampingRate = 0.35 + ratio * ratio * 5.65
            removedSpeed = outwardSpeed * (1.0 - math.exp(-dampingRate * dt))
        end
        nextVelocity = VecSub(nextVelocity, VecScale(outward, removedSpeed))
    end

    local inwardAcceleration = ratio * ratio * 34.0
    if distance >= SpaceBoundary.hardRadius then
        local overshoot = distance - SpaceBoundary.hardRadius
        inwardAcceleration = 72.0 + math.min(overshoot * 0.18, 180.0)
    end
    nextVelocity = VecSub(nextVelocity, VecScale(outward, inwardAcceleration * dt))
    SetBodyVelocity(body, nextVelocity)
end

local function _buildBackgroundStars()
    _spaceState.stars = {}
    for index = 1, 72 do
        local azimuth = _spaceValue(index, 1) * math.pi * 2.0
        local vertical = _spaceValue(index, 2) * 2.0 - 1.0
        local elevation = math.asin(vertical * 0.92)
        local horizontal = math.cos(elevation)
        local temperature = _spaceValue(index, 4)
        local red, green, blue = 0.82, 0.90, 1.0
        if temperature > 0.72 then
            red, green, blue = 1.0, 0.84, 0.64
        elseif temperature > 0.42 then
            red, green, blue = 0.92, 0.95, 1.0
        end
        _spaceState.stars[index] = {
            direction = Vec(
                math.cos(azimuth) * horizontal,
                math.sin(elevation),
                math.sin(azimuth) * horizontal
            ),
            distance = BackgroundLod.starDistance,
            size = (0.45 + _spaceValue(index, 5) * 1.35) *
                BackgroundLod.starDistance / BackgroundLod.referenceDistance,
            alpha = 0.42 + _spaceValue(index, 6) * 0.48,
            color = Vec(red, green, blue),
        }
    end
end

local function _loadCelestialSprites()
    _spaceState.celestialSprites = {}
    for id, profile in pairs(CelestialProfiles) do
        _spaceState.celestialSprites[id] = LoadSprite(profile.sprite)
    end
end

local function _findCelestialBodies()
    local bodies = {}
    for _, body in ipairs(FindBodies("celestial", true) or {}) do
        local id = GetTagValue(body, "celestialId")
        if CelestialProfiles[id] ~= nil then
            bodies[#bodies + 1] = {
                body = body,
                id = id,
            }
        end
    end
    _spaceState.celestialBodies = bodies
end

local function _drawBackground(camera)
    if _spaceState.nebulaSprite ~= 0 then
        for _, nebula in ipairs(Nebulae) do
            local direction = VecNormalize(nebula[1])
            local position = VecAdd(
                camera.pos,
                VecScale(direction, BackgroundLod.nebulaDistance)
            )
            local distanceScale = BackgroundLod.nebulaDistance /
                BackgroundLod.referenceDistance
            DrawSprite(
                _spaceState.nebulaSprite,
                Transform(position, QuatLookAt(position, camera.pos)),
                nebula[2] * 0.12 * distanceScale,
                nebula[3] * 0.12 * distanceScale,
                nebula[4][1],
                nebula[4][2],
                nebula[4][3],
                nebula[5],
                true,
                true,
                false
            )
        end
    end

    if _spaceState.starSprite == 0 then
        return
    end
    for _, star in ipairs(_spaceState.stars) do
        local position = VecAdd(
            camera.pos,
            VecScale(star.direction, star.distance)
        )
        DrawSprite(
            _spaceState.starSprite,
            Transform(position, QuatLookAt(position, camera.pos)),
            star.size,
            star.size,
            star.color[1],
            star.color[2],
            star.color[3],
            star.alpha,
            true,
            true,
            false
        )
    end
end

local function _drawCelestialImpostor(camera, entry)
    if not IsHandleValid(entry.body) then
        return
    end
    local profile = CelestialProfiles[entry.id]
    local sprite = _spaceState.celestialSprites[entry.id] or 0
    if profile == nil or sprite == 0 then
        return
    end

    local realPosition = GetBodyTransform(entry.body).pos
    local offset = VecSub(realPosition, camera.pos)
    local distance = VecLength(offset)
    if distance <= 0.001 then
        return
    end
    local fade = _spaceSmoothStep(
        (distance - CelestialLod.fadeStart) /
        (CelestialLod.fadeEnd - CelestialLod.fadeStart)
    )
    if fade <= 0.001 then
        return
    end

    local direction = VecScale(offset, 1.0 / distance)
    local proxyPosition = VecAdd(
        camera.pos,
        VecScale(direction, CelestialLod.proxyDistance)
    )
    local size = profile.radius * 2.0 *
        CelestialLod.proxyDistance / distance
    local transform = Transform(
        proxyPosition,
        QuatLookAt(proxyPosition, camera.pos)
    )

    DrawSprite(
        sprite,
        transform,
        size,
        size,
        1.0,
        1.0,
        1.0,
        fade,
        true,
        false,
        false
    )

    if profile.star and _spaceState.starSprite ~= 0 then
        DrawSprite(
            _spaceState.starSprite,
            transform,
            size * 2.4,
            size * 2.4,
            1.0,
            0.42,
            0.08,
            fade * 0.18,
            true,
            true,
            false
        )
        DrawSprite(
            _spaceState.starSprite,
            transform,
            size * 1.45,
            size * 1.45,
            1.0,
            0.78,
            0.30,
            fade * 0.34,
            true,
            true,
            false
        )
    end
end

local function _drawCelestialImpostors(camera)
    for _, entry in ipairs(_spaceState.celestialBodies) do
        _drawCelestialImpostor(camera, entry)
    end
end

function server.spaceBattlefieldInit()
    _configureSpaceEnvironment()
    _refreshBoundaryShips()
    _spaceState.refreshAge = 0.0
    local celestialBodies = FindBodies("celestial", true) or {}
    local celestialShapes = FindShapes("celestial", true) or {}
    DebugPrint(
        "[spaceBattlefield] loaded celestial bodies=" .. #celestialBodies ..
        " shapes=" .. #celestialShapes
    )
end

function server.spaceBattlefieldTick(dt)
    _spaceState.refreshAge = _spaceState.refreshAge + (tonumber(dt) or 0.0)
    if _spaceState.refreshAge >= SpaceBoundary.refreshInterval then
        _spaceState.refreshAge = 0.0
        _refreshBoundaryShips()
    end
    for _, body in ipairs(_spaceState.shipBodies) do
        if _isMajorShipBody(body) then
            _applySoftBoundary(body, dt)
        end
    end
end

function client.spaceBattlefieldInit()
    _spaceState.starSprite = LoadSprite("MOD/gfx/weapons/projectiles/impact_glow.png")
    _spaceState.nebulaSprite = LoadSprite("MOD/gfx/space/nebula_backdrop.png")
    _buildBackgroundStars()
    _loadCelestialSprites()
    _findCelestialBodies()
    _spaceState.celestialRefreshAge = 0.0
end

function client.spaceBattlefieldTick(dt)
    if #_spaceState.celestialBodies < 7 then
        _spaceState.celestialRefreshAge = _spaceState.celestialRefreshAge +
            math.max(0.0, tonumber(dt) or 0.0)
        if _spaceState.celestialRefreshAge >= 1.0 then
            _spaceState.celestialRefreshAge = 0.0
            _findCelestialBodies()
        end
    end
    local camera = GetCameraTransform()
    _drawBackground(camera)
    _drawCelestialImpostors(camera)
end
