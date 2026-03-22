---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.shipHpRecoveryState = server.shipHpRecoveryState or {
    accumulatorByBody = {},
}

local registryShipRoot = "StellarisShips/server/ships/byId/"

local function _clamp(v, minValue, maxValue)
    if v < minValue then
        return minValue
    end
    if v > maxValue then
        return maxValue
    end
    return v
end

local function _keyPrefix(shipBodyId)
    return registryShipRoot .. tostring(shipBodyId)
end

function server.shipHpRecoveryTick(dt)
    dt = dt or 0
    if dt <= 0 then
        return
    end

    local body = server.shipBody
    if body == nil or body == 0 then
        return
    end
    if server.registryShipExists ~= nil and (not server.registryShipExists(body)) then
        return
    end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(body) then
        server.shipHpRecoveryState.accumulatorByBody[body] = 0
        return
    end

    local cfg = nil
    if server.registryShipGetRegenConfig ~= nil then
        cfg = server.registryShipGetRegenConfig(body)
    end
    if cfg == nil then
        return
    end

    local tickInterval = tonumber(cfg.tickInterval) or 0.2
    if tickInterval <= 0 then
        tickInterval = 0.2
    end

    local state = server.shipHpRecoveryState
    local acc = (state.accumulatorByBody[body] or 0) + dt
    if acc < tickInterval then
        state.accumulatorByBody[body] = acc
        return
    end

    local nowTime = (GetTime ~= nil) and GetTime() or 0.0
    local regenTimes = nil
    if server.registryShipGetRegenLastDamageTimes ~= nil then
        regenTimes = server.registryShipGetRegenLastDamageTimes(body)
    end
    regenTimes = regenTimes or { shield = nowTime, armor = nowTime, body = nowTime }

    local prefix = _keyPrefix(body)
    local maxShield = GetFloat(prefix .. "/maxShieldHP")
    local maxArmor = GetFloat(prefix .. "/maxArmorHP")
    local maxBody = GetFloat(prefix .. "/maxBodyHP")

    while acc >= tickInterval do
        acc = acc - tickInterval

        local shieldHP, armorHP, bodyHP = server.registryShipGetHP(body)
        if shieldHP == nil or armorHP == nil or bodyHP == nil then
            break
        end

        local newShield = shieldHP
        local newArmor = armorHP
        local newBody = bodyHP

        local shieldDelay = tonumber(cfg.shieldNoDamageDelay) or 0.0
        local armorDelay = tonumber(cfg.armorNoDamageDelay) or 0.0
        local bodyDelay = tonumber(cfg.bodyNoDamageDelay) or 0.0

        local shieldPerSecond = tonumber(cfg.shieldPerSecond) or 0.0
        local armorPerSecond = tonumber(cfg.armorPerSecond) or 0.0
        local bodyPerSecond = tonumber(cfg.bodyPerSecond) or 0.0

        if maxShield > 0 and shieldHP < maxShield and (nowTime - (regenTimes.shield or 0.0)) >= shieldDelay then
            newShield = _clamp(shieldHP + shieldPerSecond * tickInterval, 0.0, maxShield)
        end

        if maxArmor > 0 and armorHP < maxArmor and (nowTime - (regenTimes.armor or 0.0)) >= armorDelay then
            newArmor = _clamp(armorHP + armorPerSecond * tickInterval, 0.0, maxArmor)
        end

        if maxBody > 0 and bodyHP < maxBody and (nowTime - (regenTimes.body or 0.0)) >= bodyDelay then
            newBody = _clamp(bodyHP + bodyPerSecond * tickInterval, 0.0, maxBody)
        end

        if newShield ~= shieldHP or newArmor ~= armorHP or newBody ~= bodyHP then
            server.registryShipSetHP(body, newShield, newArmor, newBody)
        end
    end

    state.accumulatorByBody[body] = acc
end

