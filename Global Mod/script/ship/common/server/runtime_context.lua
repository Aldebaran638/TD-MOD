---@diagnostic disable: undefined-global

server = server or {}

local _context = nil

function server.shipContextInit(shipType, bodyTag)
    local resolvedType = tostring(shipType or "")
    local resolvedBodyTag = tostring(bodyTag or "stellarisShip")
    local bodyId = FindBody(resolvedBodyTag, false)
    local definition = shipDefinitionGet(resolvedType, resolvedType)
    if tostring(definition.shipType or "") ~= resolvedType then
        error("unknown ship type: " .. resolvedType)
    end
    if bodyId == nil or bodyId == 0 then
        error("ship body not found for tag: " .. resolvedBodyTag)
    end
    _context = {
        shipType = resolvedType,
        definition = definition,
        bodyId = bodyId,
        bodyTag = resolvedBodyTag,
    }

    return _context
end

function server.shipContextGet()
    return _context
end

function server.shipContextGetBody()
    return math.floor((_context or {}).bodyId or 0)
end

function server.shipContextGetType()
    return tostring((_context or {}).shipType or "")
end

function server.shipContextGetDefinition()
    return (_context or {}).definition
        or shipDefinitionGet(
            server.shipContextGetType(),
            server.shipContextGetType()
        )
end
