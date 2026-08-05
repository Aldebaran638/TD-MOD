---@diagnostic disable: undefined-global

client = client or {}
client.weaponLoadoutStateByShip = client.weaponLoadoutStateByShip or {}
client.weaponLoadoutSyncState = client.weaponLoadoutSyncState or { age = 0.0 }

function client.updateShipWeaponConfiguration(
    shipBodyId,
    configurationId,
    tWeapon,
    xWeapon,
    lWeapon,
    lWeapon2,
    mWeapon,
    gWeapon,
    hWeapon,
    pWeapon,
    sensorRange,
    sensorInterval,
    trackingAdd,
    energyOutput,
    energyUse,
    energyBalance,
    weaponDamageMultiplier,
    speedMultiplier,
    turnResponseMultiplier,
    turnForceMultiplier,
    cloakAvailable,
    cloakStrength,
    cloakShieldReduction,
    cloakShipLimit
)
    local body = math.floor(shipBodyId or 0)
    if body == 0 then return end
    local previous = client.weaponLoadoutStateByShip[body] or {}
    local serverProfile = previous.serverProfile
    if sensorRange ~= nil then
        serverProfile = {
            sensor = {
                range = tonumber(sensorRange) or 0.0,
                interval = tonumber(sensorInterval) or 1.0,
                trackingAdd = tonumber(trackingAdd) or 0.0,
            },
            energy = {
                output = tonumber(energyOutput) or 0.0,
                use = tonumber(energyUse) or 0.0,
                balance = tonumber(energyBalance) or 0.0,
                weaponDamageMultiplier = tonumber(weaponDamageMultiplier) or 0.0,
            },
            mobility = {
                speedMultiplier = tonumber(speedMultiplier) or 0.0,
                turnResponseMultiplier = tonumber(turnResponseMultiplier) or 0.0,
                turnForceMultiplier = tonumber(turnForceMultiplier) or 0.0,
            },
            cloak = {
                available = math.floor(tonumber(cloakAvailable) or 0) ~= 0,
                strength = tonumber(cloakStrength) or 0.0,
                shieldReduction = tonumber(cloakShieldReduction) or 0.0,
                shipLimit = math.floor(tonumber(cloakShipLimit) or 0),
            },
        }
    end
    client.weaponLoadoutStateByShip[body] = {
        configurationId = tostring(configurationId or ""),
        tSlot = tostring(tWeapon or ""),
        xSlot = tostring(xWeapon or ""),
        lSlot = tostring(lWeapon or ""),
        lSlot2 = tostring(lWeapon2 or lWeapon or ""),
        mSlot = tostring(mWeapon or ""),
        gSlot = tostring(gWeapon or ""),
        hSlot = tostring(hWeapon or ""),
        pSlot = tostring(pWeapon or ""),
        serverProfile = serverProfile,
    }
    local binding = client.weaponConfigurationBindingState
    if binding ~= nil and math.floor(binding.shipBody or 0) == body then
        binding.serverProfile = serverProfile
    end
end

function client.getShipSensorProfile(shipBodyId)
    local body = math.floor(shipBodyId or 0)
    local state = client.weaponLoadoutStateByShip[body] or {}
    local serverProfile = state.serverProfile or {}
    if serverProfile.sensor ~= nil then return serverProfile.sensor end

    local binding = client.weaponConfigurationBindingState or {}
    local snapshot = binding.snapshot or {}
    local shipType = tostring(binding.shipType or client.shipContextGetType())
    local definition = (shipTypeRegistryData or {})[shipType]
        or client.shipContextGetDefinition() or {}
    local configuration = shipComponentFindConfiguration(
        definition,
        snapshot.configurationId
    )
    return (shipComponentResolveProfile(
        definition,
        snapshot.componentLoadout,
        configuration,
        snapshot.loadout
    ) or {}).sensor or {}
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
            local defaults = (configuration or {}).defaultLoadout or {}
            local loadoutKey = shipDefinitionGetGroupLoadoutKey(
                group.groupId,
                group.slotType
            )
            return tostring(defaults[tostring(group.groupId or "")]
                or defaults[loadoutKey]
                or defaults[tostring(group.slotType or "")] or "")
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

