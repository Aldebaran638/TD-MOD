---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local function _lSlotVec3TableToVec(v, defaultX, defaultY, defaultZ)
    local t = v or {}
    return Vec(t.x or defaultX or 0, t.y or defaultY or 0, t.z or defaultZ or 0)
end

local function _resolveLSlotWeaponSettings(weaponType)
    local defs = lSlotWeaponRegistryData or {}
    local resolvedWeaponType = weaponType or "kineticArtillery"
    return defs[resolvedWeaponType] or defs.kineticArtillery or {}
end

local function _computeLSlotFireDirLocal(slotSnap, weaponSettings)
    local mountPos = _lSlotVec3TableToVec(slotSnap.firePosOffset, 0, 0, -4)
    local defaultDir = _lSlotVec3TableToVec(slotSnap.fireDirRelative, 0, 0, -1)
    local aimMode = slotSnap.aimMode or "fixed"
    if aimMode ~= "forwardConvergeByRange" then
        return defaultDir
    end

    local maxRange = math.max(1.0, weaponSettings.maxRange or 1.0)
    local offsetX = mountPos[1] or 0.0
    local offsetY = mountPos[2] or 0.0
    local horizontal = math.sqrt(math.max(0.0, maxRange * maxRange - offsetX * offsetX))
    local aimPoint = Vec(0, offsetY, -horizontal)
    local dir = VecSub(aimPoint, mountPos)
    local dirLen = VecLength(dir)
    if dirLen < 0.0001 then
        return defaultDir
    end

    return VecScale(dir, 1.0 / dirLen)
end

function server.lSlotControlTick(dt)
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        return
    end
    if not server.registryShipEnsure(shipBody, server.defaultShipType, server.defaultShipType) then
        return
    end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(shipBody) then
        server.registryShipSetLSlotsRequest(shipBody, 0)
        return
    end

    local shipSnap = server.registryShipGetSnapshot(shipBody)
    if shipSnap == nil or (shipSnap.lSlotCount or 0) <= 0 then
        return
    end

    local primarySlot = shipSnap.lSlots[1] or {}
    local weaponSettings = _resolveLSlotWeaponSettings(primarySlot.weaponType)
    local cooldownRemain = server.registryShipGetLSlotsCooldownRemain(shipBody)
    if cooldownRemain > 0 then
        cooldownRemain = cooldownRemain - dt
        if cooldownRemain < 0 then
            cooldownRemain = 0
        end
        server.registryShipSetLSlotsCooldownRemain(shipBody, cooldownRemain)
    end

    local heat = server.registryShipGetLSlotsHeat(shipBody)
    local dissipation = math.max(0.0, weaponSettings.heatDissipationPerSecond or 0.0)
    heat = heat - dissipation * dt
    if heat < 0 then
        heat = 0
    end
    server.registryShipSetLSlotsHeat(shipBody, heat)

    local overheated = server.registryShipGetLSlotsOverheated(shipBody)
    local overheatThreshold = weaponSettings.overheatThreshold or 0.0
    local recoverThreshold = weaponSettings.recoverThreshold or 0.0
    if overheated and heat <= recoverThreshold then
        overheated = false
        server.registryShipSetLSlotsOverheated(shipBody, false)
    elseif (not overheated) and heat >= overheatThreshold and overheatThreshold > 0 then
        overheated = true
        server.registryShipSetLSlotsOverheated(shipBody, true)
    end

    local request = server.registryShipGetLSlotsRequest(shipBody)
    if request == 0 then
        return
    end
    server.registryShipSetLSlotsRequest(shipBody, 0)

    if overheated or cooldownRemain > 0 then
        return
    end

    local shipT = GetBodyTransform(shipBody)
    local fired = false
    for i = 1, shipSnap.lSlotCount or 0 do
        local slotSnap = shipSnap.lSlots[i] or {}
        local slotWeaponType = slotSnap.weaponType or "none"
        if slotWeaponType ~= nil and slotWeaponType ~= "" and slotWeaponType ~= "none" then
            local slotSettings = _resolveLSlotWeaponSettings(slotWeaponType)
            local firePosOffset = _lSlotVec3TableToVec(slotSnap.firePosOffset, 0, 0, -4)
            local firePointWorld = TransformToParentPoint(shipT, firePosOffset)
            local fireDirLocal = _computeLSlotFireDirLocal(slotSnap, slotSettings)
            local fireDirWorld = TransformToParentVec(shipT, fireDirLocal)
            local dirLen = VecLength(fireDirWorld)
            if dirLen >= 0.0001 then
                fireDirWorld = VecScale(fireDirWorld, 1.0 / dirLen)
                server.projectileManagerSpawnProjectile(shipBody, slotWeaponType, firePointWorld, fireDirWorld)
                fired = true
            end
        end
    end

    if not fired then
        return
    end

    local newHeat = heat + (weaponSettings.heatPerShot or 0.0)
    server.registryShipSetLSlotsHeat(shipBody, newHeat)
    server.registryShipSetLSlotsCooldownRemain(shipBody, math.max(0.0, weaponSettings.cooldown or 0.0))
    if overheatThreshold > 0 and newHeat >= overheatThreshold then
        server.registryShipSetLSlotsOverheated(shipBody, true)
    end
end
