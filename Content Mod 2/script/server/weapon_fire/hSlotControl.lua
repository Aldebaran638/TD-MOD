---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.hSlotState = server.hSlotState or {
    fireRequested = false,
    launchers = {},
    activeCrafts = {},
}

local function _hSlotCloneVec3(v, defaultX, defaultY, defaultZ)
    local t = v or {}
    return {
        x = tonumber(t.x) or defaultX or 0.0,
        y = tonumber(t.y) or defaultY or 0.0,
        z = tonumber(t.z) or defaultZ or 0.0,
    }
end

local function _hSlotNormalize(v, fallback)
    local len = VecLength(v)
    if len < 0.0001 then
        return fallback or Vec(0, 0, -1)
    end
    return VecScale(v, 1.0 / len)
end

local function _hSlotResolveShipDefinition(shipType)
    local defs = shipTypeRegistryData or {}
    local requested = shipType or server.defaultShipType or "enigmaticCruiser"
    return defs[requested] or defs[server.defaultShipType] or defs.enigmaticCruiser or {}
end

local function _hSlotResolveWeaponDefinition(weaponType)
    local defs = hSlotWeaponRegistryData or {}
    local requested = weaponType or "gammaStrikeCraft"
    return defs[requested] or defs.gammaStrikeCraft or {}
end

local function _hSlotGetBodyCenterWorld(bodyId)
    if bodyId == nil or bodyId == 0 or not IsHandleValid(bodyId) then
        return nil
    end
    local bodyT = GetBodyTransform(bodyId)
    local centerLocal = GetBodyCenterOfMass(bodyId)
    return TransformToParentPoint(bodyT, centerLocal)
end

local function _hSlotResolveRecoveryPoint(shipBody, launcherConfig)
    local shipT = GetBodyTransform(shipBody)
    local localPos = Vec(
        tonumber((launcherConfig.firePosOffset or {}).x) or 0.0,
        tonumber((launcherConfig.firePosOffset or {}).y) or 0.0,
        tonumber((launcherConfig.firePosOffset or {}).z) or 0.0
    )
    return TransformToParentPoint(shipT, localPos)
end

local function _hSlotBuildLauncherConfig(slotDef)
    local weaponType = tostring((slotDef and slotDef.weaponType) or "gammaStrikeCraft")
    local weaponDef = _hSlotResolveWeaponDefinition(weaponType)

    return {
        weaponType = weaponType,
        firePosOffset = _hSlotCloneVec3(slotDef and slotDef.firePosOffset, 0.0, 0.0, -1.0),
        fireDirRelative = _hSlotCloneVec3(slotDef and slotDef.fireDirRelative, 0.0, 0.0, -1.0),
        cooldown = tonumber(weaponDef.cooldown) or 20.0,
        craftLifetime = tonumber(weaponDef.craftLifetime) or 24.0,
        returnTimeout = tonumber(weaponDef.returnTimeout) or 6.0,
        craftSpeed = tonumber(weaponDef.craftSpeed) or 30.0,
        turnLerp = tonumber(weaponDef.turnLerp) or 4.0,
        approachDistance = tonumber(weaponDef.approachDistance) or 14.0,
        orbitRadius = tonumber(weaponDef.orbitRadius) or 10.0,
        orbitEntryThreshold = tonumber(weaponDef.orbitEntryThreshold) or 11.0,
        orbitLeaveThreshold = tonumber(weaponDef.orbitLeaveThreshold) or 18.0,
        avoidProbeDistance = tonumber(weaponDef.avoidProbeDistance) or 7.0,
        fireInterval = tonumber(weaponDef.fireInterval) or 0.25,
        maxRange = tonumber(weaponDef.maxRange) or 160.0,
        damageMin = tonumber(weaponDef.damageMin) or 50.0,
        damageMax = tonumber(weaponDef.damageMax) or tonumber(weaponDef.damageMin) or 50.0,
        shieldFix = tonumber(weaponDef.shieldFix) or 1.0,
        armorFix = tonumber(weaponDef.armorFix) or 1.0,
        bodyFix = tonumber(weaponDef.bodyFix) or 1.0,
        collisionExplosionSize = tonumber(weaponDef.collisionExplosionSize) or 0.1,
        environmentExplosionSize = tonumber(weaponDef.environmentExplosionSize) or 0.1,
    }
end

local function _hSlotBuildLauncherRuntime()
    return {
        cooldownRemain = 0.0,
    }
end

function server.hSlotControlSetFireRequested(active)
    local state = server.hSlotState or {}
    state.fireRequested = active and true or false
    server.hSlotState = state
end

local function _hSlotConsumeFireRequested()
    local state = server.hSlotState or {}
    local requested = state.fireRequested and true or false
    state.fireRequested = false
    server.hSlotState = state
    return requested
end

local function _hSlotPickReadyLauncher(state)
    local launchers = state.launchers or {}
    local activeCrafts = state.activeCrafts or {}

    for i = 1, #launchers do
        local launcher = launchers[i]
        local runtime = launcher and launcher.runtime or nil
        if runtime ~= nil and (runtime.cooldownRemain or 0.0) <= 0.0 and activeCrafts[i] == nil then
            return i, launcher
        end
    end

    return nil, nil
end

local function _hSlotTryDirection(shipBody, fromPos, dir, dist)
    QueryRequire("physical")
    QueryRejectBody(shipBody)
    local hit = QueryRaycast(fromPos, dir, dist, 0.2)
    return not hit
end

local function _hSlotResolveAvoidDir(shipBody, pos, desiredDir, forwardDir, probeDistance)
    local forward = _hSlotNormalize(desiredDir, forwardDir)
    local right = _hSlotNormalize(VecCross(forward, Vec(0, 1, 0)), Vec(1, 0, 0))
    local left = VecScale(right, -1.0)
    local up = Vec(0, 1, 0)

    if _hSlotTryDirection(shipBody, pos, forward, probeDistance) then
        return forward
    end
    if _hSlotTryDirection(shipBody, pos, left, probeDistance) then
        return _hSlotNormalize(VecAdd(VecScale(forward, 0.4), VecScale(left, 0.6)), left)
    end
    if _hSlotTryDirection(shipBody, pos, right, probeDistance) then
        return _hSlotNormalize(VecAdd(VecScale(forward, 0.4), VecScale(right, 0.6)), right)
    end
    if _hSlotTryDirection(shipBody, pos, up, probeDistance) then
        return _hSlotNormalize(VecAdd(VecScale(forward, 0.25), VecScale(up, 0.75)), up)
    end
    return nil
end

local function _hSlotApplyBeamDamage(hitPos, hitBody, weaponType, environmentExplosionSize)
    if hitBody ~= nil and hitBody ~= 0 and server.registryShipExists(hitBody) then
        local resolvedDefaultShipType = server.defaultShipType or "enigmaticCruiser"
        if not server.registryShipEnsure(hitBody, resolvedDefaultShipType, resolvedDefaultShipType) then
            return
        end

        if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(hitBody) then
            if hitPos ~= nil then
                Explosion(hitPos, environmentExplosionSize)
            end
            return
        end

        local targetShipType = server.registryShipGetShipType ~= nil and server.registryShipGetShipType(hitBody) or resolvedDefaultShipType
        local targetShieldHP, targetArmorHP, targetBodyHP = server.registryShipGetHP(hitBody)
        if targetShieldHP == nil or targetArmorHP == nil or targetBodyHP == nil then
            return
        end

        local targetShipData = (shipData and shipData[targetShipType]) or (shipData and shipData[resolvedDefaultShipType]) or {}
        local weapon = (weaponData and weaponData[weaponType]) or (weaponData and weaponData.gammaStrikeCraft) or {}
        local damageMin = tonumber(weapon.damageMin) or 0.0
        local damageMax = tonumber(weapon.damageMax) or damageMin
        if damageMax < damageMin then
            damageMax = damageMin
        end

        local rolledDamage = damageMin
        if damageMax > damageMin then
            rolledDamage = damageMin + (damageMax - damageMin) * math.random()
        end

        local rawRemain = rolledDamage
        local function _applyLayer(currentHp, damageFix)
            local hp = currentHp or 0.0
            local fix = tonumber(damageFix) or 1.0
            if hp <= 0.0 or rawRemain <= 0.0 or fix <= 0.0 then
                return hp
            end

            local potential = rawRemain * fix
            if potential < hp then
                hp = hp - potential
                rawRemain = 0.0
            else
                rawRemain = rawRemain - (hp / fix)
                hp = 0.0
            end

            if rawRemain < 0.0 then
                rawRemain = 0.0
            end
            return hp
        end

        targetShieldHP = _applyLayer(targetShieldHP, weapon.shieldFix)
        targetArmorHP = _applyLayer(targetArmorHP, weapon.armorFix)
        targetBodyHP = _applyLayer(targetBodyHP, weapon.bodyFix)

        local maxShield = tonumber(targetShipData.maxShieldHP) or targetShieldHP or 0.0
        local maxArmor = tonumber(targetShipData.maxArmorHP) or targetArmorHP or 0.0
        local maxBody = tonumber(targetShipData.maxBodyHP) or targetBodyHP or 0.0
        if targetShieldHP > maxShield then targetShieldHP = maxShield end
        if targetArmorHP > maxArmor then targetArmorHP = maxArmor end
        if targetBodyHP > maxBody then targetBodyHP = maxBody end

        server.registryShipSetHP(hitBody, targetShieldHP, targetArmorHP, targetBodyHP)
        return
    end

    if hitPos ~= nil then
        Explosion(hitPos, environmentExplosionSize)
    end
end

local function _hSlotFireGammaBeam(shipBody, craft, targetCenter, weaponConfig)
    local origin = craft.pos or targetCenter
    local toTarget = VecSub(targetCenter, origin)
    local dir = _hSlotNormalize(toTarget, craft.forward or Vec(0, 0, -1))
    local maxRange = math.max(1.0, tonumber(weaponConfig.maxRange) or 160.0)

    QueryRequire("physical")
    QueryRejectBody(shipBody)
    local hit, dist, normal, shape = QueryRaycast(origin, dir, maxRange, 0.05)
    if not hit then
        return
    end

    local hitPos = VecAdd(origin, VecScale(dir, dist))
    local hitBody = shape ~= nil and shape ~= 0 and GetShapeBody(shape) or 0
    _hSlotApplyBeamDamage(hitPos, hitBody, craft.weaponType, tonumber(weaponConfig.environmentExplosionSize) or 0.1)

    if normal ~= nil and normal[2] ~= nil then
        local _ = normal
    end
end

local function _hSlotCraftExplode(craft, weaponConfig)
    local pos = craft and craft.pos or nil
    if pos ~= nil then
        Explosion(pos, tonumber(weaponConfig.collisionExplosionSize) or 0.1)
    end
end

local function _hSlotFinishCraft(state, slotIndex)
    local launchers = state.launchers or {}
    local launcher = launchers[slotIndex]
    local runtime = launcher and launcher.runtime or nil
    local config = launcher and launcher.config or {}

    if runtime ~= nil then
        runtime.cooldownRemain = math.max(0.0, tonumber(config.cooldown) or 0.0)
    end

    local active = state.activeCrafts or {}
    active[slotIndex] = nil
    state.activeCrafts = active
end

function server.hSlotStateInit(shipType)
    local shipDef = _hSlotResolveShipDefinition(shipType)
    if server.shipSlotLoadoutResolveShipDefinition ~= nil then
        shipDef = server.shipSlotLoadoutResolveShipDefinition(shipType) or shipDef
    end

    local state = {
        fireRequested = false,
        launchers = {},
        activeCrafts = {},
    }

    local slotDefs = shipDef.hSlots or {}
    for i = 1, #slotDefs do
        state.launchers[i] = {
            config = _hSlotBuildLauncherConfig(slotDefs[i]),
            runtime = _hSlotBuildLauncherRuntime(),
        }
    end

    server.hSlotState = state
    server.hSlotLastFireRequest = nil
    return state
end

function server.hSlotStateResetRuntime()
    local state = server.hSlotState or {}
    state.fireRequested = false
    state.activeCrafts = {}

    local launchers = state.launchers or {}
    for i = 1, #launchers do
        local runtime = launchers[i] and launchers[i].runtime or nil
        if runtime ~= nil then
            runtime.cooldownRemain = 0.0
        end
    end

    server.hSlotLastFireRequest = nil
    server.hSlotState = state
end

function server.hSlotControlSyncHud()
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        return
    end

    local state = server.hSlotState or {}
    local launchers = state.launchers or {}
    local activeCrafts = state.activeCrafts or {}

    local cd1 = ((launchers[1] or {}).runtime or {}).cooldownRemain or 0.0
    local cd2 = ((launchers[2] or {}).runtime or {}).cooldownRemain or 0.0
    local max1 = ((launchers[1] or {}).config or {}).cooldown or 1.0
    local max2 = ((launchers[2] or {}).config or {}).cooldown or 1.0
    local active1 = activeCrafts[1] ~= nil and 1 or 0
    local active2 = activeCrafts[2] ~= nil and 1 or 0

    ClientCall(0, "client.updateHSlotHudState", shipBody, cd1, cd2, max1, max2, active1, active2)
end

function server.hSlotControlTick(dt)
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        return
    end

    if not server.registryShipEnsure(shipBody, server.defaultShipType, server.defaultShipType) then
        return
    end

    local state = server.hSlotState
    if state == nil then
        return
    end

    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(shipBody) then
        server.hSlotStateResetRuntime()
        return
    end

    local launchers = state.launchers or {}
    for i = 1, #launchers do
        local runtime = launchers[i] and launchers[i].runtime or nil
        if runtime ~= nil and (runtime.cooldownRemain or 0.0) > 0.0 then
            runtime.cooldownRemain = math.max(0.0, (runtime.cooldownRemain or 0.0) - (dt or 0.0))
        end
    end

    local activeCrafts = state.activeCrafts or {}
    for slotIndex, craft in pairs(activeCrafts) do
        local launcher = launchers[slotIndex]
        local weaponConfig = launcher and launcher.config or {}
        local keepUpdating = true

        craft.lifeRemain = (craft.lifeRemain or 0.0) - (dt or 0.0)
        if craft.lifeRemain <= 0.0 then
            _hSlotCraftExplode(craft, weaponConfig)
            _hSlotFinishCraft(state, slotIndex)
        else
            local targetCenter = _hSlotGetBodyCenterWorld(craft.targetBodyId or 0)
            if targetCenter == nil then
                craft.state = "returning"
            end

            if craft.state == "approach" and targetCenter ~= nil then
                local toTarget = VecSub(targetCenter, craft.pos)
                if VecLength(toTarget) <= (weaponConfig.orbitEntryThreshold or 11.5) then
                    craft.state = "orbit"
                end
            end

            if craft.state == "orbit" and targetCenter ~= nil then
                local toTarget = VecSub(targetCenter, craft.pos)
                local dist = VecLength(toTarget)
                if dist > (weaponConfig.orbitLeaveThreshold or 18.0) then
                    craft.state = "approach"
                end
            end

            if craft.state ~= "returning" and (targetCenter == nil) then
                craft.state = "returning"
            end

            if craft.state == "returning" then
                craft.returnRemain = (craft.returnRemain or (weaponConfig.returnTimeout or 6.0)) - (dt or 0.0)
                if craft.returnRemain <= 0.0 then
                    _hSlotCraftExplode(craft, weaponConfig)
                    _hSlotFinishCraft(state, slotIndex)
                    keepUpdating = false
                end
            end

            local desiredDir = craft.forward or Vec(0, 0, -1)

            if keepUpdating and craft.state == "returning" then
                local recovery = _hSlotResolveRecoveryPoint(shipBody, weaponConfig)
                local toRecovery = VecSub(recovery, craft.pos)
                if VecLength(toRecovery) <= 1.8 then
                    _hSlotFinishCraft(state, slotIndex)
                    keepUpdating = false
                end
                if keepUpdating then
                    desiredDir = _hSlotNormalize(toRecovery, desiredDir)
                end
            elseif keepUpdating and craft.state == "orbit" and targetCenter ~= nil then
                craft.orbitAngle = (craft.orbitAngle or 0.0) + (dt or 0.0) * 1.2
                local radial = _hSlotNormalize(VecSub(craft.pos, targetCenter), Vec(1, 0, 0))
                local tangent = _hSlotNormalize(VecCross(Vec(0, 1, 0), radial), Vec(0, 0, -1))
                local dist = VecLength(VecSub(craft.pos, targetCenter))
                local radiusErr = ((weaponConfig.orbitRadius or 10.0) - dist)
                desiredDir = _hSlotNormalize(VecAdd(tangent, VecScale(radial, -radiusErr * 0.25)), tangent)

                craft.fireRemain = (craft.fireRemain or 0.0) - (dt or 0.0)
                if craft.fireRemain <= 0.0 then
                    _hSlotFireGammaBeam(shipBody, craft, targetCenter, weaponConfig)
                    craft.fireRemain = math.max(0.05, weaponConfig.fireInterval or 0.22)
                end
            elseif keepUpdating then
                local approachTarget = nil
                if targetCenter ~= nil then
                    local shipCenter = _hSlotGetBodyCenterWorld(shipBody) or craft.pos
                    local inDir = _hSlotNormalize(VecSub(targetCenter, shipCenter), Vec(0, 0, -1))
                    approachTarget = VecAdd(targetCenter, VecScale(inDir, weaponConfig.approachDistance or 14.0))
                else
                    approachTarget = _hSlotResolveRecoveryPoint(shipBody, weaponConfig)
                end
                desiredDir = _hSlotNormalize(VecSub(approachTarget, craft.pos), desiredDir)
            end

            if keepUpdating then
                local avoidDir = _hSlotResolveAvoidDir(shipBody, craft.pos, desiredDir, craft.forward or desiredDir, weaponConfig.avoidProbeDistance or 7.0)
                if avoidDir == nil then
                    _hSlotCraftExplode(craft, weaponConfig)
                    _hSlotFinishCraft(state, slotIndex)
                    keepUpdating = false
                end

                if keepUpdating then
                    local turnLerp = math.max(0.0, tonumber(weaponConfig.turnLerp) or 4.0)
                    local blend = math.min(1.0, turnLerp * (dt or 0.0))
                    local blended = _hSlotNormalize(
                        VecAdd(VecScale(craft.forward or avoidDir, 1.0 - blend), VecScale(avoidDir, blend)),
                        avoidDir
                    )
                    local speed = math.max(4.0, tonumber(weaponConfig.craftSpeed) or 30.0)
                    local nextPos = VecAdd(craft.pos, VecScale(blended, speed * (dt or 0.0)))

                    local step = VecSub(nextPos, craft.pos)
                    local stepLen = VecLength(step)
                    if stepLen > 0.0001 then
                        QueryRequire("physical")
                        QueryRejectBody(shipBody)
                        local hit = QueryRaycast(craft.pos, VecScale(step, 1.0 / stepLen), stepLen, 0.15)
                        if hit then
                            _hSlotCraftExplode(craft, weaponConfig)
                            _hSlotFinishCraft(state, slotIndex)
                            keepUpdating = false
                        end
                    end

                    if keepUpdating then
                        craft.forward = blended
                        craft.pos = nextPos
                    end
                end
            end
        end
    end

    server.hSlotControlSyncHud()

    if not _hSlotConsumeFireRequested() then
        return
    end

    local request = server.hSlotLastFireRequest
    server.hSlotLastFireRequest = nil
    if request == nil then
        return
    end

    local targetBodyId = math.floor(request.targetBodyId or 0)
    if targetBodyId == 0 then
        return
    end

    local slotIndex, launcher = _hSlotPickReadyLauncher(state)
    if slotIndex == nil or launcher == nil then
        return
    end

    local shipT = GetBodyTransform(shipBody)
    local firePos = TransformToParentPoint(shipT, Vec(
        tonumber((launcher.config.firePosOffset or {}).x) or 0.0,
        tonumber((launcher.config.firePosOffset or {}).y) or 0.0,
        tonumber((launcher.config.firePosOffset or {}).z) or -1.0
    ))
    local fireDir = _hSlotNormalize(TransformToParentVec(shipT, Vec(
        tonumber((launcher.config.fireDirRelative or {}).x) or 0.0,
        tonumber((launcher.config.fireDirRelative or {}).y) or 0.0,
        tonumber((launcher.config.fireDirRelative or {}).z) or -1.0
    )), Vec(0, 0, -1))

    state.activeCrafts[slotIndex] = {
        slotIndex = slotIndex,
        weaponType = tostring(launcher.config.weaponType or "gammaStrikeCraft"),
        targetBodyId = targetBodyId,
        pos = firePos,
        forward = fireDir,
        state = "approach",
        lifeRemain = math.max(0.5, tonumber(launcher.config.craftLifetime) or 24.0),
        returnRemain = math.max(0.5, tonumber(launcher.config.returnTimeout) or 6.0),
        fireRemain = 0.0,
        orbitAngle = 0.0,
    }
end
