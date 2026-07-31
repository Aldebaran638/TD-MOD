---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

function server.bodyCombatSpeedLimitTick(dt)
    local body = server.shipContextGetBody()
    if body == nil or body == 0 or not IsHandleValid(body) then return end
    local velocity = GetBodyVelocity(body)
    if velocity == nil then return end

    local flight = (server.shipContextGetDefinition() or {}).flightProfile or {}
    local baseLimit = tonumber(flight.maxCombatSpeed) or 0.0
    if baseLimit <= 0.0 then return end
    local mobility = 0.0
    if server.shipRuntimeGetMobilityModifiers ~= nil then
        mobility = tonumber(server.shipRuntimeGetMobilityModifiers(body)) or 0.0
    end
    local limit = baseLimit * math.max(0.50, 1.0 + math.max(-0.50, mobility) * 0.35)
    local speed = VecLength(velocity)
    if speed <= limit then return end

    local clamped = VecScale(velocity, limit / math.max(0.001, speed))
    SetBodyVelocity(body, clamped)
end
