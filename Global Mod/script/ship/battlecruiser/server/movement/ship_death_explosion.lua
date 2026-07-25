---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

-- 飞船死亡爆炸参数
server.shipDeathExplosionConfig = server.shipDeathExplosionConfig or {
    explosionSize = 4.0, -- 爆炸强度（常用范围 0.5~4.0）
}

-- 仅用于“首次死亡触发一次爆炸”
server.shipDeathExplosionState = server.shipDeathExplosionState or {
    explodedByBody = {},
}

local function _explodeAtBodyCenter(body, size)
    if body == nil or body == 0 then
        return
    end

    local bodyTransform = GetBodyTransform(body)
    local comLocal = GetBodyCenterOfMass(body)
    local center = TransformToParentPoint(bodyTransform, comLocal)
    Explosion(center, size or 4.0)
end

function server.shipDeathExplosionTick(dt)
    local _ = dt
    local body = server.shipBody
    if body == nil or body == 0 then
        return
    end
    if server.registryShipExists ~= nil and (not server.registryShipExists(body)) then
        return
    end

    local isDead = false
    if server.registryShipIsBodyDead ~= nil then
        isDead = server.registryShipIsBodyDead(body)
    elseif server.registryShipGetHP ~= nil then
        local _, _, bodyHP = server.registryShipGetHP(body)
        isDead = (tonumber(bodyHP) or 1.0) <= 0.0
    end

    local state = server.shipDeathExplosionState
    local exploded = state.explodedByBody[body] and true or false
    if isDead and (not exploded) then
        local cfg = server.shipDeathExplosionConfig
        local explosionSize = tonumber(cfg.explosionSize) or 4.0
        _explodeAtBodyCenter(body, explosionSize)
        state.explodedByBody[body] = true
    end
end

