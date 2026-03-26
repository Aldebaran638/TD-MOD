---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local function _lSlotVec3TableToVec(v, defaultX, defaultY, defaultZ)
    local t = v or {}
    return Vec(t.x or defaultX or 0, t.y or defaultY or 0, t.z or defaultZ or 0)
end

local function _computeLSlotFireDirLocal(slotConfig)
    local mountPos = _lSlotVec3TableToVec(slotConfig.firePosOffset, 0, 0, -4)
    local defaultDir = _lSlotVec3TableToVec(slotConfig.fireDirRelative, 0, 0, -1)
    local aimMode = slotConfig.aimMode or "fixed"
    if aimMode ~= "forwardConvergeByRange" then
        return defaultDir
    end

    local maxRange = math.max(1.0, slotConfig.maxRange or 1.0)
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

local function _updateSlotRuntime(slot, dt)
    local config = slot.config or {}
    local runtime = slot.runtime or {}

    local heat = (runtime.heat or 0.0) - math.max(0.0, config.heatDissipationPerSecond or 0.0) * dt
    if heat < 0.0 then
        heat = 0.0
    end
    runtime.heat = heat

    local cooldownRemain = runtime.cooldownRemain or 0.0
    if cooldownRemain > 0.0 then
        cooldownRemain = cooldownRemain - dt
        if cooldownRemain < 0.0 then
            cooldownRemain = 0.0
        end
    end
    runtime.cooldownRemain = cooldownRemain

    local overheated = runtime.overheated and true or false
    local overheatThreshold = config.overheatThreshold or 0.0
    local recoverThreshold = config.recoverThreshold or 0.0
    if overheated and heat <= recoverThreshold then
        runtime.overheated = false
    elseif (not overheated) and overheatThreshold > 0.0 and heat >= overheatThreshold then
        runtime.overheated = true
    end
end

function server.lSlotControlTick(dt)
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        server.lSlotStatePushHudReset(false)
        return
    end
    if not server.registryShipEnsure(shipBody, server.defaultShipType, server.defaultShipType) then
        server.lSlotStatePushHudReset(false)
        return
    end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(shipBody) then
        server.lSlotStateSetRequestFire(false)
        server.lSlotStateResetRuntime()
        server.lSlotStatePushHudReset(true)
        return
    end

    local state = server.lSlotState
    local slots = (state and state.slots) or {}
    if #slots <= 0 then
        server.lSlotStatePushHudReset(false)
        return
    end

    for i = 1, #slots do
        _updateSlotRuntime(slots[i], dt)
    end

    local primaryRuntime = (slots[1] and slots[1].runtime) or {}
    if not server.lSlotStateConsumeRequestFire() then
        server.lSlotStatePushHud(false)
        return
    end

    if (primaryRuntime.overheated and true or false) or (primaryRuntime.cooldownRemain or 0.0) > 0.0 then
        server.lSlotStatePushHud(false)
        return
    end

    local shipT = GetBodyTransform(shipBody)
    local fired = false
    for i = 1, #slots do
        local slot = slots[i] or {}
        local slotConfig = slot.config or {}
        local slotRuntime = slot.runtime or {}
        local slotWeaponType = slotConfig.weaponType or "none"
        if slotWeaponType ~= nil and slotWeaponType ~= "" and slotWeaponType ~= "none"
            and (not (slotRuntime.overheated and true or false))
            and (slotRuntime.cooldownRemain or 0.0) <= 0.0 then
            local firePosOffset = _lSlotVec3TableToVec(slotConfig.firePosOffset, 0, 0, -4)
            local firePointWorld = TransformToParentPoint(shipT, firePosOffset)
            local fireDirLocal = _computeLSlotFireDirLocal(slotConfig)
            local fireDirWorld = TransformToParentVec(shipT, fireDirLocal)
            local dirLen = VecLength(fireDirWorld)
            if dirLen >= 0.0001 then
                fireDirWorld = VecScale(fireDirWorld, 1.0 / dirLen)
                server.projectileManagerSpawnProjectile(shipBody, slotWeaponType, firePointWorld, fireDirWorld)
                fired = true
                slotRuntime.heat = (slotRuntime.heat or 0.0) + (slotConfig.heatPerShot or 0.0)
                slotRuntime.cooldownRemain = math.max(0.0, slotConfig.cooldown or 0.0)
                if (slotConfig.overheatThreshold or 0.0) > 0.0 and slotRuntime.heat >= (slotConfig.overheatThreshold or 0.0) then
                    slotRuntime.overheated = true
                end
            end
        end
    end

    server.lSlotStatePushHud(fired)
end
