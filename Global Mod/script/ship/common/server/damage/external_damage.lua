---@diagnostic disable: undefined-global

server = server or {}

local function _externalDamageConfig()
    local definition = server.shipContextGetDefinition() or {}
    local config = definition.externalDamage or {}
    return {
        bulletDamage = math.max(0.0, tonumber(config.bulletDamage) or 20.0),
        explosionMinStrength = math.max(
            0.0,
            tonumber(config.explosionMinStrength) or 0.5
        ),
        explosionMaxDistance = math.max(
            0.001,
            tonumber(config.explosionMaxDistance) or 10.0
        ),
        explosionDamageScale = math.max(
            0.0,
            tonumber(config.explosionDamageScale) or 30.0
        ),
    }
end

local function _bodyCenterWorld(body)
    local transform = GetBodyTransform(body)
    return TransformToParentPoint(transform, GetBodyCenterOfMass(body))
end

local function _safeDirection(value, fallback)
    local length = VecLength(value)
    if length < 0.0001 then return fallback end
    return VecScale(value, 1.0 / length)
end

local function _projectToShield(body, sourcePoint)
    local center = _bodyCenterWorld(body)
    local bodyTransform = GetBodyTransform(body)
    local fallback = _safeDirection(
        TransformToParentVec(bodyTransform, Vec(0, 0, -1)),
        Vec(0, 1, 0)
    )
    local direction = _safeDirection(VecSub(sourcePoint, center), fallback)
    local radius = math.max(
        0.1,
        tonumber(server.registryShipGetShieldRadius(
            body,
            server.shipContextGetType()
        )) or 0.1
    )
    return VecAdd(center, VecScale(direction, radius))
end

local function _damageToShieldImpactStrength(damage)
    local amount = math.max(0.0, tonumber(damage) or 0.0)
    if amount <= 50.0 then return 1 end
    local doubledSteps = math.ceil(math.log(amount / 50.0) / math.log(2.0))
    return math.max(1, math.min(7, 1 + doubledSteps))
end

local function _playShieldImpact(body, sourcePoint, impactStrength)
    local point = _projectToShield(body, sourcePoint)
    server.netClientCall(
        "weapon.hitFx",
        0,
        "client.playExternalShieldImpactFx",
        body,
        point[1], point[2], point[3],
        math.max(1, math.min(7, math.floor(impactStrength or 1)))
    )
end

local function _processExplosionEvents(body, config)
    local center = _bodyCenterWorld(body)
    local count = GetEventCount("explosion")
    for index = 1, count do
        local point, strength = GetEvent("explosion", index)
        local size = tonumber(strength) or 0.0
        if point ~= nil and size >= config.explosionMinStrength then
            local distance = VecLength(VecSub(point, center))
            if distance < config.explosionMaxDistance then
                local falloff = math.max(
                    0.0,
                    1.0 - distance / config.explosionMaxDistance
                )
                local damage = config.explosionDamageScale
                    * size * size * falloff
                local result = server.shipDamageApplyRaw(body, damage)
                if result.didHitShield then
                    _playShieldImpact(
                        body,
                        point,
                        _damageToShieldImpactStrength(damage)
                    )
                end
            end
        end
    end
end

local function _processProjectileEvents(body, config)
    local count = GetEventCount("projectilehit")
    for index = 1, count do
        local shape, point = GetEvent("projectilehit", index)
        if shape ~= nil and shape ~= 0
            and IsHandleValid(shape)
            and GetShapeBody(shape) == body then
            local result =
                server.shipDamageApplyRaw(body, config.bulletDamage)
            if result.didHitShield and point ~= nil then
                _playShieldImpact(body, point, 1)
            end
        end
    end
end

function server.shipExternalDamageTick(dt)
    local _ = dt
    local body = server.shipContextGetBody()
    if body == nil or body == 0 or not IsHandleValid(body) then return end
    if server.registryShipExists == nil or not server.registryShipExists(body) then
        return
    end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(body) then
        return
    end

    local config = _externalDamageConfig()
    _processExplosionEvents(body, config)
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(body) then
        return
    end
    _processProjectileEvents(body, config)
end

