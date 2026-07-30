---@diagnostic disable: undefined-global

client = client or {}
client.weaponLoadoutStateByShip = client.weaponLoadoutStateByShip or {}
client.weaponLoadoutSyncState = client.weaponLoadoutSyncState or { age = 0.0 }

function client.updateShipWeaponConfiguration(shipBodyId, configurationId, xWeapon, lWeapon, mWeapon, gWeapon, hWeapon)
    local body = math.floor(shipBodyId or 0)
    if body == 0 then return end
    client.weaponLoadoutStateByShip[body] = {
        configurationId = tostring(configurationId or ""),
        xSlot = tostring(xWeapon or ""),
        lSlot = tostring(lWeapon or ""),
        mSlot = tostring(mWeapon or ""),
        gSlot = tostring(gWeapon or ""),
        hSlot = tostring(hWeapon or ""),
    }
end

function client.getShipWeaponType(shipBodyId, groupId)
    local state = client.weaponLoadoutStateByShip[math.floor(shipBodyId or 0)] or {}
    local mode = tostring(groupId or "")
    local configured = tostring(state[mode] or "")
    if configured ~= "" then return configured end

    local shipType = client.registryShipGetShipType(shipBodyId)
    if shipType == "" then shipType = client.shipContextGetType() end
    local definition = shipDefinitionGet(shipType, shipType)
    local configuration = shipDefinitionFindConfiguration(
        definition,
        state.configurationId or definition.defaultSlotConfigurationId
    )
    for _, group in ipairs((configuration or {}).slotGroups or {}) do
        if tostring(group.groupId or "") == mode then
            return tostring(((configuration or {}).defaultLoadout or {})
                [tostring(group.slotType or "")] or "")
        end
    end
    return ""
end

function client.getShipWeaponDefinition(shipBodyId, groupId)
    local weaponType = client.getShipWeaponType(shipBodyId, groupId)
    return (weaponData or {})[weaponType] or {}
end

function client.getShipWeaponMounts(shipBodyId, groupId)
    local body = math.floor(shipBodyId or 0)
    local state = client.weaponLoadoutStateByShip[body] or {}
    local shipType = client.registryShipGetShipType(body)
    if shipType == "" then shipType = client.shipContextGetType() end
    local definition = shipDefinitionGet(shipType, shipType)
    return shipDefinitionResolveMounts(
        shipType,
        state.configurationId or definition.defaultSlotConfigurationId,
        groupId,
        client.getShipWeaponType(body, groupId)
    )
end

function client.weaponLoadoutSyncTick(dt)
    local body = client.shipContextGetBody()
    if body == 0 or client.weaponLoadoutStateByShip[body] ~= nil then return end
    local sync = client.weaponLoadoutSyncState
    sync.age = (tonumber(sync.age) or 0.0) + math.max(0.0, tonumber(dt) or 0.0)
    if sync.age >= 0.5 and client.shipRequestWeaponConfiguration ~= nil then
        sync.age = 0.0
        client.shipRequestWeaponConfiguration(body)
    end
end

