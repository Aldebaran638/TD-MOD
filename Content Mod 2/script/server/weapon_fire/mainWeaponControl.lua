---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

function server.mainWeaponControlTick(dt)
    local _ = dt
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        return
    end
    if not server.registryShipEnsure(shipBody, server.defaultShipType, server.defaultShipType) then
        return
    end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(shipBody) then
        server.registryShipSetMainWeaponFireRequest(shipBody, 0)
        server.registryShipSetMainWeaponToggleRequest(shipBody, 0)
        server.registryShipSetXSlotsRequest(shipBody, 0)
        server.registryShipSetLSlotsRequest(shipBody, 0)
        return
    end

    local toggleRequest = server.registryShipGetMainWeaponToggleRequest(shipBody)
    if toggleRequest ~= 0 then
        server.registryShipSetMainWeaponToggleRequest(shipBody, 0)
        local current = server.registryShipGetCurrentMainWeapon(shipBody)
        local nextMode = (current == "lSlot") and "xSlot" or "lSlot"
        server.registryShipSetCurrentMainWeapon(shipBody, nextMode)
    end

    local fireRequest = server.registryShipGetMainWeaponFireRequest(shipBody)
    if fireRequest == 0 then
        return
    end

    server.registryShipSetMainWeaponFireRequest(shipBody, 0)
    local current = server.registryShipGetCurrentMainWeapon(shipBody)
    if current == "lSlot" then
        server.registryShipSetLSlotsRequest(shipBody, 1)
    else
        server.registryShipSetXSlotsRequest(shipBody, 1)
    end
end
