---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.pointDefenseState = server.pointDefenseState or {
    mounts = {},
    pendingShots = {},
    scanRemain = 0.0,
}

local function _pdNormalize(value, fallback)
    local length = VecLength(value)
    if length < 0.0001 then return fallback or Vec(0, 0, -1) end
    return VecScale(value, 1.0 / length)
end

local function _pdBodyCenter(bodyId)
    if bodyId == 0 or not IsHandleValid(bodyId) then return nil end
    local transform = GetBodyTransform(bodyId)
    return TransformToParentPoint(transform, GetBodyCenterOfMass(bodyId))
end

local function _pdTargetPriority(role, interceptorClass)
    local class = tostring(interceptorClass or "")
    if tostring(role or "") == "flak" then
        if class == "strike_craft" then return 0 end
        if class == "missile" then return 2 end
        if class == "torpedo" then return 3 end
    else
        if class == "torpedo" then return 0 end
        if class == "missile" then return 1 end
        if class == "strike_craft" then return 3 end
    end
    return 100
end

local function _pdFindTarget(shipBody, origin, weapon)
    local best, bestScore = nil, math.huge
    local role = tostring((weapon or {}).pointDefenseRole or "missile")
    local maxRange = math.max(1.0, tonumber((weapon or {}).maxRange) or 220.0)
    local count = server.registryShipGetRegisteredCount()
    for index = 1, count do
        local body = server.registryShipGetRegisteredBodyIdAt(index)
        local class = server.registryShipGetInterceptorClass(body)
        local owner = server.registryShipGetOwnerBody(body)
        if body ~= 0 and body ~= shipBody and owner ~= shipBody and class ~= ""
            and IsHandleValid(body)
            and not server.registryShipIsBodyDead(body) then
            local center = _pdBodyCenter(body)
            if center ~= nil then
                local distance = VecLength(VecSub(center, origin))
                if distance <= maxRange then
                    local score = _pdTargetPriority(role, class) * 10000.0
                        + distance
                    if score < bestScore then
                        bestScore = score
                        best = {
                            bodyId = body,
                            class = class,
                            center = center,
                            velocity = GetBodyVelocity(body),
                            distance = distance,
                        }
                    end
                end
            end
        end
    end
    return best
end

local function _pdHasLineOfSight(shipBody, origin, target)
    local delta = VecSub(target.center, origin)
    local distance = VecLength(delta)
    if distance < 0.001 then return true end
    QueryRequire("physical")
    QueryRejectBody(shipBody)
    local hit, _, _, shape = QueryRaycast(
        origin,
        VecScale(delta, 1.0 / distance),
        distance + 1.0,
        0.05
    )
    if not hit then return true end
    return shape ~= nil and shape ~= 0 and GetShapeBody(shape) == target.bodyId
end

local function _pdInterceptTime(relativePosition, targetVelocity, projectileSpeed)
    local speed = math.max(1.0, tonumber(projectileSpeed) or 180.0)
    local a = VecDot(targetVelocity, targetVelocity) - speed * speed
    local b = 2.0 * VecDot(relativePosition, targetVelocity)
    local c = VecDot(relativePosition, relativePosition)
    local time = nil
    if math.abs(a) < 0.0001 then
        if math.abs(b) > 0.0001 then
            local candidate = -c / b
            if candidate > 0.0 then time = candidate end
        end
    else
        local discriminant = b * b - 4.0 * a * c
        if discriminant >= 0.0 then
            local root = math.sqrt(discriminant)
            local first = (-b - root) / (2.0 * a)
            local second = (-b + root) / (2.0 * a)
            if first > 0.0 then time = first end
            if second > 0.0 and (time == nil or second < time) then time = second end
        end
    end
    return math.max(0.02, math.min(2.0, time or VecLength(relativePosition) / speed))
end

local function _pdRollDamage(weapon)
    local minimum = math.max(0.0, tonumber((weapon or {}).damageMin) or 0.0)
    local maximum = math.max(minimum, tonumber((weapon or {}).damageMax) or minimum)
    local officialDamage = minimum + (maximum - minimum) * math.random()
    return officialDamage
end

local function _pdSendFx(role, origin, destination, duration)
    server.netClientCall(
        "weapon.fireFx",
        0,
        "client.spawnPointDefenseFx",
        tostring(role or "missile"),
        origin[1], origin[2], origin[3],
        destination[1], destination[2], destination[3],
        math.max(0.03, tonumber(duration) or 0.08)
    )
end

local function _pdApplyDamage(targetBody, weapon, attackerBody)
    if targetBody == 0 or not IsHandleValid(targetBody)
        or not server.registryShipExists(targetBody)
        or server.registryShipIsBodyDead(targetBody) then return false end
    local result = server.shipDamageApplyWeaponDefinition(
        targetBody,
        weapon,
        _pdRollDamage(weapon),
        attackerBody
    )
    return result.didDamage
end

local function _pdFireFlak(state, origin, target, weapon, attackerBody)
    local flightTime = _pdInterceptTime(
        VecSub(target.center, origin),
        target.velocity,
        weapon.projectileSpeed
    )
    local predicted = VecAdd(
        target.center,
        VecScale(target.velocity, flightTime)
    )
    state.pendingShots[#state.pendingShots + 1] = {
        targetBody = target.bodyId,
        aimPosition = predicted,
        remain = flightTime,
        weapon = weapon,
        attackerBody = attackerBody,
        hitRadius = target.class == "strike_craft" and 6.0 or 3.5,
    }
    _pdSendFx("flak", origin, predicted, flightTime)
end

local function _pdFireEnergy(origin, target, weapon, attackerBody)
    _pdApplyDamage(target.bodyId, weapon, attackerBody)
    _pdSendFx(
        tostring((weapon or {}).pointDefenseFxRole or "laser"),
        origin,
        target.center,
        0.10
    )
end

local function _pdUpdatePending(state, dt)
    for index = #state.pendingShots, 1, -1 do
        local shot = state.pendingShots[index]
        shot.remain = (tonumber(shot.remain) or 0.0) - dt
        if shot.remain <= 0.0 then
            local center = _pdBodyCenter(shot.targetBody)
            if center ~= nil
                and VecLength(VecSub(center, shot.aimPosition))
                    <= (tonumber(shot.hitRadius) or 3.5) then
                _pdApplyDamage(shot.targetBody, shot.weapon, shot.attackerBody)
            end
            table.remove(state.pendingShots, index)
        end
    end
end

function server.pointDefenseInit(shipType)
    local definition = server.shipSlotLoadoutResolveShipDefinition ~= nil
        and server.shipSlotLoadoutResolveShipDefinition(shipType)
        or shipDefinitionGet(shipType, server.shipContextGetType())
    local state = { mounts = {}, pendingShots = {}, scanRemain = 0.0 }
    for index, mount in ipairs((definition or {}).pSlots or {}) do
        local weapon = (weaponData or {})[tostring(mount.weaponType or "")] or {}
        if weapon.automaticPointDefense then
            state.mounts[#state.mounts + 1] = {
                localPosition = mount.firePosOffset or { x = 0, y = 0, z = -1 },
                weapon = weapon,
                cooldownRemain = (index - 1) * 0.12,
            }
        end
    end
    server.pointDefenseState = state
end

function server.pointDefenseReset()
    server.pointDefenseState = { mounts = {}, pendingShots = {}, scanRemain = 0.0 }
end

function server.pointDefenseNeedsTick()
    local state = server.pointDefenseState or {}
    return #(state.mounts or {}) > 0 or #(state.pendingShots or {}) > 0
end

function server.pointDefenseTick(dt)
    local frameDt = math.max(0.0, tonumber(dt) or 0.0)
    if frameDt <= 0.0 then return end
    local state = server.pointDefenseState or {}
    _pdUpdatePending(state, frameDt)
    local shipBody = server.shipContextGetBody()
    if shipBody == 0 or not IsHandleValid(shipBody)
        or server.registryShipIsBodyDead(shipBody) then return end
    if server.registryShipIsCloaked ~= nil
        and server.registryShipIsCloaked(shipBody) then return end

    for _, mount in ipairs(state.mounts or {}) do
        mount.cooldownRemain = math.max(
            0.0,
            (tonumber(mount.cooldownRemain) or 0.0) - frameDt
        )
    end
    state.scanRemain = (tonumber(state.scanRemain) or 0.0) - frameDt
    if state.scanRemain > 0.0 then return end
    state.scanRemain = 0.10

    local shipTransform = GetBodyTransform(shipBody)
    for _, mount in ipairs(state.mounts or {}) do
        if mount.cooldownRemain <= 0.0 then
            local offset = mount.localPosition or {}
            local origin = TransformToParentPoint(shipTransform, Vec(
                tonumber(offset.x) or 0.0,
                tonumber(offset.y) or 0.0,
                tonumber(offset.z) or -1.0
            ))
            local target = _pdFindTarget(shipBody, origin, mount.weapon)
            if target ~= nil and _pdHasLineOfSight(shipBody, origin, target) then
                if tostring(mount.weapon.pointDefenseRole or "") == "flak" then
                    _pdFireFlak(state, origin, target, mount.weapon, shipBody)
                else
                    _pdFireEnergy(origin, target, mount.weapon, shipBody)
                end
                mount.cooldownRemain = math.max(
                    0.05,
                    tonumber(mount.weapon.cooldown) or 0.5
                )
            end
        end
    end
end
