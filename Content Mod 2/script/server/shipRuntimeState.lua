---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local _mainWeaponSyncKeepAlive = 0.5

server.shipRuntimeState = server.shipRuntimeState or {
    byBody = {},
}

local function _runtimeResolveShipDefinition(shipType, defaultShipType)
    local requestedShipType = shipType or defaultShipType or "enigmaticCruiser"
    local defs = shipTypeRegistryData or {}
    local definition = defs[requestedShipType] or defs[defaultShipType] or defs.enigmaticCruiser or {}
    local resolvedShipType = definition.shipType or requestedShipType
    return resolvedShipType, definition
end

local function _runtimeCloneRegenConfig(definition)
    local regenDef = (definition and definition.regen) or {}
    return {
        tickInterval = tonumber(regenDef.tickInterval) or 0.2,
        shieldPerSecond = tonumber(regenDef.shieldPerSecond) or 0.0,
        armorPerSecond = tonumber(regenDef.armorPerSecond) or 0.0,
        bodyPerSecond = tonumber(regenDef.bodyPerSecond) or 0.0,
        shieldNoDamageDelay = tonumber(regenDef.shieldNoDamageDelay) or 0.0,
        armorNoDamageDelay = tonumber(regenDef.armorNoDamageDelay) or 0.0,
        bodyNoDamageDelay = tonumber(regenDef.bodyNoDamageDelay) or 0.0,
    }
end

local function _runtimeClampMoveState(moveState)
    local state = math.floor(moveState or 0)
    if state < 0 then
        state = 0
    end
    if state > 2 then
        state = 2
    end
    return state
end

local function _runtimeNormalizeMode(mode)
    if mode == "lSlot" then
        return "lSlot"
    end
    if mode == "sSlot" then
        return "sSlot"
    end
    return "xSlot"
end

local function _runtimeGetOrCreate(shipBodyId, shipType, defaultShipType)
    if shipBodyId == nil or shipBodyId == 0 then
        return nil
    end

    local byBody = server.shipRuntimeState.byBody
    local state = byBody[shipBodyId]
    if state ~= nil then
        return state
    end

    local resolvedShipType, definition = _runtimeResolveShipDefinition(shipType, defaultShipType)
    local nowTime = (GetTime ~= nil) and GetTime() or 0.0
    local maxShield = tonumber(definition.maxShieldHP) or 0.0
    local maxArmor = tonumber(definition.maxArmorHP) or 0.0
    local maxBody = tonumber(definition.maxBodyHP) or 0.0

    state = {
        shipType = resolvedShipType,
        maxHP = {
            shield = maxShield,
            armor = maxArmor,
            body = maxBody,
        },
        regen = {
            config = _runtimeCloneRegenConfig(definition),
            lastDamageTimes = {
                shield = nowTime,
                armor = nowTime,
                body = nowTime,
            },
            lastObservedHP = {
                shield = maxShield,
                armor = maxArmor,
                body = maxBody,
            },
        },
        move = {
            requestState = 0,
            currentState = 0,
        },
        driverPlayerId = 0,
        rotation = {
            pitchError = 0.0,
            yawError = 0.0,
            rollError = 0.0,
        },
        mainWeapon = {
            current = "xSlot",
            lastSentMode = "",
            lastSentAt = -1000.0,
        },
        weaponAim = {
            active = false,
            localYaw = 0.0,
            localPitch = 0.0,
        },
    }

    byBody[shipBodyId] = state
    return state
end

function server.shipRuntimeStateInit(shipBodyId, shipType, defaultShipType)
    if shipBodyId == nil or shipBodyId == 0 then
        return nil
    end
    server.shipRuntimeState.byBody[shipBodyId] = nil
    return _runtimeGetOrCreate(shipBodyId, shipType, defaultShipType)
end

function server.shipRuntimeStateEnsure(shipBodyId, shipType, defaultShipType)
    return _runtimeGetOrCreate(shipBodyId, shipType, defaultShipType)
end

function server.shipRuntimeGetMaxHP(shipBodyId)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return 0.0, 0.0, 0.0
    end
    local maxHP = state.maxHP or {}
    return maxHP.shield or 0.0, maxHP.armor or 0.0, maxHP.body or 0.0
end

function server.shipRuntimeGetRegenConfig(shipBodyId)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return nil
    end
    return state.regen and state.regen.config or nil
end

function server.shipRuntimeGetRegenLastDamageTimes(shipBodyId)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return nil
    end
    return state.regen and state.regen.lastDamageTimes or nil
end

function server.shipRuntimeObserveHP(shipBodyId, shieldHP, armorHP, bodyHP, nowTime)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return nil
    end

    local regen = state.regen
    local lastObserved = regen.lastObservedHP
    local lastDamage = regen.lastDamageTimes
    local t = tonumber(nowTime) or ((GetTime ~= nil) and GetTime() or 0.0)

    if shieldHP ~= nil and shieldHP < (lastObserved.shield or shieldHP) then
        lastDamage.shield = t
    end
    if armorHP ~= nil and armorHP < (lastObserved.armor or armorHP) then
        lastDamage.armor = t
    end
    if bodyHP ~= nil and bodyHP < (lastObserved.body or bodyHP) then
        lastDamage.body = t
    end

    if shieldHP ~= nil then
        lastObserved.shield = shieldHP
    end
    if armorHP ~= nil then
        lastObserved.armor = armorHP
    end
    if bodyHP ~= nil then
        lastObserved.body = bodyHP
    end

    return lastDamage
end

function server.shipRuntimeSetObservedHP(shipBodyId, shieldHP, armorHP, bodyHP)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return
    end

    local lastObserved = state.regen.lastObservedHP
    if shieldHP ~= nil then
        lastObserved.shield = shieldHP
    end
    if armorHP ~= nil then
        lastObserved.armor = armorHP
    end
    if bodyHP ~= nil then
        lastObserved.body = bodyHP
    end
end

function server.shipRuntimeGetMoveState(shipBodyId)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return 0
    end
    return state.move.currentState or 0
end

function server.shipRuntimeSetMoveState(shipBodyId, moveState)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return
    end
    state.move.currentState = _runtimeClampMoveState(moveState)
end

function server.shipRuntimeGetMoveRequestState(shipBodyId)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return 0
    end
    return state.move.requestState or 0
end

function server.shipRuntimeSetMoveRequestState(shipBodyId, moveState)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return
    end
    state.move.requestState = _runtimeClampMoveState(moveState)
end

function server.shipRuntimeGetDriverPlayerId(shipBodyId)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return 0
    end
    return math.floor(state.driverPlayerId or 0)
end

function server.shipRuntimeSetDriverPlayerId(shipBodyId, playerId)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return
    end
    state.driverPlayerId = math.floor(playerId or 0)
end

function server.shipRuntimeGetRotationError(shipBodyId)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return 0.0, 0.0
    end
    local rotation = state.rotation or {}
    return tonumber(rotation.pitchError) or 0.0, tonumber(rotation.yawError) or 0.0
end

function server.shipRuntimeSetRotationError(shipBodyId, pitchError, yawError)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return
    end
    local rotation = state.rotation
    local pitchValue = tonumber(pitchError) or 0.0
    local yawValue = tonumber(yawError) or 0.0
    if pitchValue ~= pitchValue or pitchValue == math.huge or pitchValue == -math.huge then
        pitchValue = 0.0
    end
    if yawValue ~= yawValue or yawValue == math.huge or yawValue == -math.huge then
        yawValue = 0.0
    end
    rotation.pitchError = pitchValue
    rotation.yawError = yawValue
end

function server.shipRuntimeGetWeaponAim(shipBodyId)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return false, 0.0, 0.0
    end

    local weaponAim = state.weaponAim or {}
    return weaponAim.active and true or false, tonumber(weaponAim.localYaw) or 0.0, tonumber(weaponAim.localPitch) or 0.0
end

function server.shipRuntimeSetWeaponAim(shipBodyId, active, localYaw, localPitch)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return
    end

    local weaponAim = state.weaponAim or {}
    local yawValue = tonumber(localYaw) or 0.0
    local pitchValue = tonumber(localPitch) or 0.0
    if yawValue ~= yawValue or yawValue == math.huge or yawValue == -math.huge then
        yawValue = 0.0
    end
    if pitchValue ~= pitchValue or pitchValue == math.huge or pitchValue == -math.huge then
        pitchValue = 0.0
    end

    weaponAim.active = active and true or false
    weaponAim.localYaw = yawValue
    weaponAim.localPitch = pitchValue
    state.weaponAim = weaponAim
end

function server.shipRuntimeGetRollError(shipBodyId)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return 0.0
    end
    return tonumber((state.rotation or {}).rollError) or 0.0
end

function server.shipRuntimeSetRollError(shipBodyId, rollError)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return
    end
    local value = tonumber(rollError) or 0.0
    if value ~= value or value == math.huge or value == -math.huge then
        value = 0.0
    end
    state.rotation.rollError = value
end

function server.shipRuntimeGetCurrentMainWeapon(shipBodyId)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return "xSlot"
    end
    return _runtimeNormalizeMode((state.mainWeapon or {}).current)
end

function server.shipRuntimeSetCurrentMainWeapon(shipBodyId, mode)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return
    end
    state.mainWeapon.current = _runtimeNormalizeMode(mode)
end

function server.shipRuntimeSyncMainWeapon(shipBodyId, force)
    local state = _runtimeGetOrCreate(shipBodyId, server.defaultShipType, server.defaultShipType)
    if state == nil then
        return
    end

    local mainWeapon = state.mainWeapon
    local currentMode = _runtimeNormalizeMode(mainWeapon.current)
    local nowTime = (GetTime ~= nil) and GetTime() or 0.0
    local changed = currentMode ~= (mainWeapon.lastSentMode or "")
    local keepAliveDue = (nowTime - (mainWeapon.lastSentAt or -1000.0)) >= _mainWeaponSyncKeepAlive
    if (not force) and (not changed) and (not keepAliveDue) then
        return
    end

    ClientCall(0, "client.setShipMainWeaponMode", shipBodyId, currentMode)
    mainWeapon.lastSentMode = currentMode
    mainWeapon.lastSentAt = nowTime
end

function server.shipRuntimeStateSyncTick(dt)
    local _ = dt
    local shipBodyId = server.shipBody
    if shipBodyId == nil or shipBodyId == 0 then
        return
    end
    server.shipRuntimeSyncMainWeapon(shipBodyId, false)
end
