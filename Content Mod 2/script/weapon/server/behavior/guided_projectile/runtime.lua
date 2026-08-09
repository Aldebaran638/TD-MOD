---@diagnostic disable: undefined-global

server = server or {}

local function _fireRocket(context)
    if server.guidedProjectileSpawn == nil then return false end
    local origin, direction = server.weaponBehaviorResolveFireTransform(context)
    local definition = context.weaponDefinition or {}
    local config = {}
    for key, value in pairs(definition) do config[key] = value end
    config.weaponType = context.weaponType
    return server.guidedProjectileSpawn(
        context.shipBodyId,
        context.groupId,
        config,
        origin,
        direction,
        0,
        0
    ) ~= nil
end

server.weaponBehaviorRegister("rocketProjectile", { fire = _fireRocket })
