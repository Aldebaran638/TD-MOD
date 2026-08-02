---@diagnostic disable: undefined-global

client = client or {}

local _shipContext = nil

function client.shipContextInit(shipType, bodyTag)
    local resolvedType = tostring(shipType or "")
    local body = FindBody(tostring(bodyTag or "stellarisShip"), false)
    local definition = shipDefinitionGet(resolvedType, resolvedType)
    if tostring(definition.shipType or "") ~= resolvedType then
        error("unknown ship type: " .. resolvedType)
    end
    _shipContext = {
        shipType = resolvedType,
        definition = definition,
        bodyId = body,
        bodyTag = tostring(bodyTag or "stellarisShip"),
    }
    return _shipContext
end

function client.shipContextGet()
    return _shipContext
end

function client.shipContextGetBody()
    return math.floor((_shipContext or {}).bodyId or 0)
end

function client.shipContextGetType()
    return tostring((_shipContext or {}).shipType or "")
end

function client.shipContextGetDefinition()
    return (_shipContext or {}).definition
        or shipDefinitionGet(client.shipContextGetType(), client.shipContextGetType())
end
