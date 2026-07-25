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

    local defaultByMode = {
        xSlot = "tachyonLance",
        lSlot = "kineticArtillery",
        mSlot = "swarmerMissile",
        gSlot = "devastatorTorpedoes",
        hSlot = "gammaStrikeCraft",
    }
    return defaultByMode[mode] or ""
end

function client.getShipWeaponDefinition(shipBodyId, groupId)
    local weaponType = client.getShipWeaponType(shipBodyId, groupId)
    return (weaponData or {})[weaponType] or {}
end

function client.weaponLoadoutSyncTick(dt)
    local body = math.floor(client.shipBody or 0)
    if body == 0 or client.weaponLoadoutStateByShip[body] ~= nil then return end
    local sync = client.weaponLoadoutSyncState
    sync.age = (tonumber(sync.age) or 0.0) + math.max(0.0, tonumber(dt) or 0.0)
    if sync.age >= 0.5 and client.shipRequestWeaponConfiguration ~= nil then
        sync.age = 0.0
        client.shipRequestWeaponConfiguration(body)
    end
end

