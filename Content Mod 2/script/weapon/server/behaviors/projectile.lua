---@diagnostic disable: undefined-global

server = server or {}
local _pendingBursts = {}

local function _fireProjectile(context)
    local origin, direction = server.weaponBehaviorResolveFireTransform(context)
    local profile = (context.weaponDefinition or {}).fireProfile or {}
    local count = math.max(1, math.floor(tonumber(profile.burstCount) or 1))
    server.projectileManagerSpawnProjectile(context.shipBodyId, context.weaponType, origin, direction)
    if count > 1 then
        table.insert(_pendingBursts, {
            shipBodyId = context.shipBodyId,
            weaponType = context.weaponType,
            origin = origin,
            direction = direction,
            remaining = count - 1,
            timer = math.max(0.01, tonumber(profile.burstInterval) or 0.05),
            interval = math.max(0.01, tonumber(profile.burstInterval) or 0.05),
        })
    end
    return true
end

local function _tickProjectile(dt)
    for i = #_pendingBursts, 1, -1 do
        local burst = _pendingBursts[i]
        burst.timer = (burst.timer or 0.0) - dt
        while burst.timer <= 0.0 and burst.remaining > 0 do
            server.projectileManagerSpawnProjectile(
                burst.shipBodyId, burst.weaponType, burst.origin, burst.direction
            )
            burst.remaining = burst.remaining - 1
            burst.timer = burst.timer + burst.interval
        end
        if burst.remaining <= 0 then table.remove(_pendingBursts, i) end
    end
end

local function _resetProjectile()
    _pendingBursts = {}
end

server.weaponBehaviorRegister("projectile", {
    fire = _fireProjectile,
    tick = _tickProjectile,
    reset = _resetProjectile,
})
