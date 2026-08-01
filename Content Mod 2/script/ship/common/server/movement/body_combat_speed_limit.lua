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
        local speedMultiplier = server.shipRuntimeGetMobilityModifiers(body)
        mobility = tonumber(speedMultiplier) or 0.0
    end
    local forwardLimit = baseLimit * math.max(0.50, 1.0 + math.max(-0.50, mobility) * 0.35)
    local reverseBase = tonumber(flight.maxReverseSpeed) or baseLimit
    local reverseLimit = reverseBase * math.max(0.50, 1.0 + math.max(-0.50, mobility) * 0.35)
    local bodyTransform = GetBodyTransform(body)
    local localVelocity = TransformToLocalVec(bodyTransform, velocity)
    local longitudinal = localVelocity[3]
    local clampedLongitudinal = longitudinal
    if longitudinal < -forwardLimit then
        clampedLongitudinal = -forwardLimit
    elseif longitudinal > reverseLimit then
        clampedLongitudinal = reverseLimit
    end
    if clampedLongitudinal == longitudinal then return end
    localVelocity[3] = clampedLongitudinal
    SetBodyVelocity(body, TransformToParentVec(bodyTransform, localVelocity))
end
