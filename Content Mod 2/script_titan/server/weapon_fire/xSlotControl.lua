---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local registryShipIndexRoot = "StellarisShips/server/ships/index"

local function _vec3TableToVec(v, defaultX, defaultY, defaultZ)
    local t = v or {}
    return Vec(t.x or defaultX or 0, t.y or defaultY or 0, t.z or defaultZ or 0)
end

local function _resolveWeaponSettings(weaponType)
    local defs = weaponData or {}
    local resolvedWeaponType = weaponType or "tachyonLance"
    local settings = defs[resolvedWeaponType] or defs.infernalRay or defs.tachyonLance or {}
    if settings.cooldown == nil and settings.CD ~= nil then
        settings.cooldown = settings.CD
    end
    return settings
end

local function _xSlotWeaponTypeUsable(weaponType)
    return weaponType ~= nil and weaponType ~= "" and weaponType ~= "none"
end

local function _safeNormalize(v, fallback)
    local len = VecLength(v)
    if len < 0.0001 then
        return fallback or Vec(0, 0, -1)
    end
    return VecScale(v, 1.0 / len)
end

local function _resolveTargetShieldRadius(targetBody, fallbackShipType)
    local radiusFallback = 20.0
    local fallbackType = fallbackShipType or server.defaultShipType or "titan"
    local fallbackShipData = (shipData and shipData[fallbackType]) or (shipData and shipData.titan) or {}
    if fallbackShipData.shieldRadius ~= nil then
        radiusFallback = fallbackShipData.shieldRadius
    end

    if targetBody == nil or targetBody == 0 then
        return radiusFallback
    end

    local radius = 0.0
    if server.registryShipGetShieldRadius ~= nil then
        radius = server.registryShipGetShieldRadius(targetBody, fallbackType) or 0.0
    end
    if radius > 0.0 then
        return radius
    end

    local targetType = server.registryShipGetShipType ~= nil and server.registryShipGetShipType(targetBody) or fallbackType
    local targetTypeData = (shipData and shipData[targetType]) or (shipData and shipData[fallbackType]) or {}
    return tonumber(targetTypeData.shieldRadius) or radiusFallback
end

local function _raySphereEntryT(origin, dirUnit, center, radius)
    local oc = VecSub(origin, center)
    local b = 2.0 * VecDot(oc, dirUnit)
    local c = VecDot(oc, oc) - radius * radius
    local disc = b * b - 4.0 * c
    if disc < 0.0 then
        return nil
    end
    local s = math.sqrt(disc)
    local t1 = (-b - s) * 0.5
    local t2 = (-b + s) * 0.5
    if t1 >= 0.0 then
        return t1
    end
    if t2 >= 0.0 then
        return t2
    end
    return nil
end

local function _getBodyCenterWorld(bodyId)
    local bodyT = GetBodyTransform(bodyId)
    local comLocal = GetBodyCenterOfMass(bodyId)
    return TransformToParentPoint(bodyT, comLocal)
end

local function _anyPlayerDrivingShip(shipBodyId)
    local players = GetAllPlayers() or {}
    local shipVehicle = GetBodyVehicle(shipBodyId)
    for i = 1, #players do
        local playerId = players[i]
        if IsPlayerValid == nil or IsPlayerValid(playerId) then
            local veh = GetPlayerVehicle(playerId)
            if veh ~= nil and veh ~= 0 then
                local body = GetVehicleBody(veh)
                if body == shipBodyId or (shipVehicle ~= nil and shipVehicle ~= 0 and veh == shipVehicle) then
                    return true
                end
            end
        end
    end
    return false
end

local function _xSlotDecayCooldowns(slots, dt)
    for i = 1, #slots do
        local runtime = (slots[i] and slots[i].runtime) or nil
        if runtime ~= nil and (runtime.cd or 0.0) > 0.0 then
            local nextCd = (runtime.cd or 0.0) - dt
            if nextCd < 0.0 then
                nextCd = 0.0
            end
            runtime.cd = nextCd
        end
    end
end

function server_xSlot_handleFireRequest()
    if server.xSlotStateSetRequestFire ~= nil then
        server.xSlotStateSetRequestFire(true)
    end
end

function server.xSlot_computeHitResult(shipBodyId, firePosOffset, fireDirRelative, weaponType)
    local invalidTarget = 0

    if shipBodyId == nil or shipBodyId == 0 or firePosOffset == nil or fireDirRelative == nil then
        return Vec(0, 0, 0), invalidTarget, false, false, Vec(0, 1, 0)
    end

    local shipT = GetBodyTransform(shipBodyId)
    local origin = TransformToParentPoint(shipT, firePosOffset)
    local dir = _safeNormalize(TransformToParentVec(shipT, fireDirRelative), TransformToParentVec(shipT, Vec(0, 0, -1)))

    local weaponSettings = _resolveWeaponSettings(weaponType)
    local maxRange = tonumber(weaponSettings.maxRange) or 1.0
    if maxRange <= 0.0 then
        maxRange = 1.0
    end

    QueryRequire("physical")
    QueryRejectBody(shipBodyId)
    local hit, dist, normal, shape = QueryRaycast(origin, dir, maxRange)
    if not hit then
        return VecAdd(origin, VecScale(dir, maxRange)), invalidTarget, false, false, dir
    end

    local endPos = VecAdd(origin, VecScale(dir, dist))
    if shape == nil or shape == 0 then
        return endPos, invalidTarget, true, false, normal or dir
    end

    local targetBody = GetShapeBody(shape)
    if targetBody ~= nil and targetBody ~= 0 and server.registryShipExists(targetBody) then
        local center = _getBodyCenterWorld(targetBody)
        local shieldRadius = _resolveTargetShieldRadius(targetBody, server.defaultShipType or "titan")
        local entryT = _raySphereEntryT(origin, dir, center, shieldRadius)
        if entryT ~= nil and entryT <= maxRange then
            endPos = VecAdd(origin, VecScale(dir, entryT))
        end

        return endPos, targetBody, true, true, normal or dir
    end

    return endPos, invalidTarget, true, false, normal or dir
end

local function _rollWeaponDamage(weaponType, damageScale)
    local targetWeaponData = _resolveWeaponSettings(weaponType)
    local damageMin = tonumber(targetWeaponData.damageMin) or 0.0
    local damageMax = tonumber(targetWeaponData.damageMax) or damageMin
    if damageMax < damageMin then
        damageMax = damageMin
    end

    local rolledDamage = damageMin
    if damageMax > damageMin then
        rolledDamage = math.random() * (damageMax - damageMin) + damageMin
    end

    local scale = tonumber(damageScale) or 1.0
    if scale < 0.0 then
        scale = 0.0
    end
    return rolledDamage * scale, targetWeaponData
end

local function _applyLayeredShipDamage(hitBody, weaponType, damageScale)
    if hitBody == nil or hitBody == 0 or (not server.registryShipExists(hitBody)) then
        return {
            didDamage = false,
            didHitShield = false,
            impactLayer = "none",
        }
    end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(hitBody) then
        return {
            didDamage = false,
            didHitShield = false,
            impactLayer = "none",
        }
    end

    local targetShipType = server.registryShipGetShipType ~= nil and server.registryShipGetShipType(hitBody) or (server.defaultShipType or "titan")
    local targetShieldHP, targetArmorHP, targetBodyHP = server.registryShipGetHP(hitBody)
    if targetShieldHP == nil or targetArmorHP == nil or targetBodyHP == nil then
        return {
            didDamage = false,
            didHitShield = false,
            impactLayer = "none",
        }
    end

    local resolvedDefaultShipType = server.defaultShipType or "titan"
    local targetShipData = (shipData and shipData[targetShipType]) or (shipData and shipData[resolvedDefaultShipType]) or {}
    local rawRemain, targetWeaponData = _rollWeaponDamage(weaponType, damageScale)

    local result = {
        didDamage = false,
        didHitShield = false,
        impactLayer = "none",
    }

    local function _applyLayer(layerName, currentHp, damageFix)
        local hp = currentHp or 0.0
        local fix = tonumber(damageFix) or 1.0
        if hp <= 0.0 or rawRemain <= 0.0 or fix <= 0.0 then
            return hp
        end

        local potential = rawRemain * fix
        if potential <= 0.0 then
            return hp
        end

        local consumedRaw = 0.0
        if potential < hp then
            hp = hp - potential
            consumedRaw = rawRemain
        else
            consumedRaw = hp / fix
            hp = 0.0
        end

        rawRemain = rawRemain - consumedRaw
        if rawRemain < 0.0 then
            rawRemain = 0.0
        end

        if result.impactLayer == "none" then
            result.impactLayer = layerName
        end
        if layerName == "shield" then
            result.didHitShield = true
        end
        result.didDamage = true
        return hp
    end

    targetShieldHP = _applyLayer("shield", targetShieldHP or 0.0, targetWeaponData.shieldFix)
    targetArmorHP = _applyLayer("armor", targetArmorHP or 0.0, targetWeaponData.armorFix)
    targetBodyHP = _applyLayer("body", targetBodyHP or 0.0, targetWeaponData.bodyFix)

    local maxShield = tonumber(targetShipData.maxShieldHP) or targetShieldHP or 0.0
    local maxArmor = tonumber(targetShipData.maxArmorHP) or targetArmorHP or 0.0
    local maxBody = tonumber(targetShipData.maxBodyHP) or targetBodyHP or 0.0
    if targetShieldHP > maxShield then targetShieldHP = maxShield end
    if targetArmorHP > maxArmor then targetArmorHP = maxArmor end
    if targetBodyHP > maxBody then targetBodyHP = maxBody end

    server.registryShipSetHP(hitBody, targetShieldHP, targetArmorHP, targetBodyHP)
    return result
end

local function _infernalRayDistanceToShipSurface(hitPos, targetBodyId)
    local center = _getBodyCenterWorld(targetBodyId)
    local shieldRadius = _resolveTargetShieldRadius(targetBodyId, server.defaultShipType or "titan")
    local centerDistance = VecLength(VecSub(hitPos, center))
    local surfaceDistance = centerDistance - shieldRadius
    if surfaceDistance < 0.0 then
        surfaceDistance = 0.0
    end
    return surfaceDistance
end

local function _startInfernalRayHitShake(targetBodyId, strength, weaponSettings)
    local amplitudeBase = tonumber((weaponSettings or {}).hitShakeAmplitude) or 0.18
    local duration = tonumber((weaponSettings or {}).hitShakeDuration) or 0.45
    local amplitude = amplitudeBase * math.max(0.0, tonumber(strength) or 0.0)
    if amplitude <= 0.0001 or duration <= 0.0 then
        return
    end
    ClientCall(0, "client.startTitanHitShake", targetBodyId, amplitude, duration)
end

local function _applyInfernalRayAoe(ownerShipBody, hitPos, weaponType, directHitTarget)
    local weaponSettings = _resolveWeaponSettings(weaponType)
    local aoeRadius = tonumber(weaponSettings.aoeRadius) or 0.0
    local minFactor = tonumber(weaponSettings.aoeMinDamageFactor) or 0.0
    if minFactor < 0.0 then
        minFactor = 0.0
    elseif minFactor > 1.0 then
        minFactor = 1.0
    end

    local summary = {
        didHitShield = false,
        impactLayer = "environment",
        hitTargetBodyId = 0,
        didHitStellarisBody = false,
    }

    if aoeRadius <= 0.0 then
        return summary
    end

    local bestDistance = math.huge
    local count = GetInt(registryShipIndexRoot .. "/count")
    for i = 1, count do
        local bodyId = GetInt(registryShipIndexRoot .. "/" .. tostring(i) .. "/bodyId")
        if bodyId ~= nil and bodyId ~= 0 and bodyId ~= ownerShipBody and server.registryShipExists(bodyId) then
            if server.registryShipIsBodyDead == nil or (not server.registryShipIsBodyDead(bodyId)) then
                local distance = _infernalRayDistanceToShipSurface(hitPos, bodyId)
                if distance <= aoeRadius then
                    local falloff = 1.0 - (distance / aoeRadius)
                    if falloff < 0.0 then
                        falloff = 0.0
                    elseif falloff > 1.0 then
                        falloff = 1.0
                    end

                    local damageScale = minFactor + (1.0 - minFactor) * falloff
                    local damageResult = _applyLayeredShipDamage(bodyId, weaponType, damageScale)
                    if damageResult.didDamage then
                        local isPreferred = (bodyId == directHitTarget)
                        if isPreferred or summary.hitTargetBodyId == 0 or distance < bestDistance then
                            bestDistance = distance
                            summary.hitTargetBodyId = bodyId
                            summary.didHitShield = damageResult.didHitShield
                            summary.impactLayer = damageResult.impactLayer
                            summary.didHitStellarisBody = true
                        end
                        _startInfernalRayHitShake(bodyId, falloff, weaponSettings)
                    end
                end
            end
        end
    end

    return summary
end

function server.xSlot_applyHitResult(shipBodyId, endPos, hitTarget, isHit, isHitStellarisBody, weaponType)
    local renderResult = {
        didHitShield = false,
        impactLayer = "none",
        hitTargetBodyId = 0,
        didHitStellarisBody = false,
    }

    if not isHit then
        return renderResult
    end

    local weaponSettings = _resolveWeaponSettings(weaponType)
    if tostring(weaponSettings.weaponType or weaponType) == "infernalRay" then
        local aoeResult = _applyInfernalRayAoe(shipBodyId, endPos, weaponType, hitTarget)
        renderResult.didHitShield = aoeResult.didHitShield
        renderResult.impactLayer = aoeResult.impactLayer
        renderResult.hitTargetBodyId = aoeResult.hitTargetBodyId
        renderResult.didHitStellarisBody = aoeResult.didHitStellarisBody
        if renderResult.impactLayer == "none" then
            renderResult.impactLayer = "environment"
        end
        return renderResult
    end

    if isHitStellarisBody then
        local damageResult = _applyLayeredShipDamage(hitTarget, weaponType, 1.0)
        renderResult.didHitShield = damageResult.didHitShield
        renderResult.impactLayer = damageResult.impactLayer
        renderResult.hitTargetBodyId = hitTarget or 0
        renderResult.didHitStellarisBody = damageResult.didDamage
        return renderResult
    end

    renderResult.impactLayer = "environment"
    if endPos ~= nil then
        Explosion(endPos, 4.0)
    end
    return renderResult
end

function server.xSlot_broadcastChargingStart(shipBodyId, slotIndex, weaponType, firePointWorld)
    server.xSlotRenderPushEvent(shipBodyId, {
        eventType = "charging_start",
        slotIndex = slotIndex,
        weaponType = weaponType,
        firePoint = firePointWorld,
        hitPoint = firePointWorld,
        didHit = false,
        didHitStellarisBody = false,
        didHitShield = false,
        hitTargetBodyId = 0,
        normal = { x = 0, y = 1, z = 0 },
        impactLayer = "none",
        incrementShotId = 0,
    })
end

function server.xSlot_broadcastChargeState(shipBodyId, slotIndex, weaponType, firePointWorld, eventType)
    server.xSlotRenderPushEvent(shipBodyId, {
        eventType = eventType or "charging_start",
        slotIndex = slotIndex,
        weaponType = weaponType,
        firePoint = firePointWorld,
        hitPoint = firePointWorld,
        didHit = false,
        didHitStellarisBody = false,
        didHitShield = false,
        hitTargetBodyId = 0,
        normal = { x = 0, y = 1, z = 0 },
        impactLayer = "none",
        incrementShotId = 0,
    })
end

function server.xSlot_broadcastLaunchingStart(shipBodyId, slotIndex, weaponType, firePointWorld, hitPointWorld, didHit, didHitStellarisBody, didHitShield, hitTargetBodyId, normal, impactLayer)
    server.xSlotRenderPushEvent(shipBodyId, {
        eventType = "launch_start",
        slotIndex = slotIndex,
        weaponType = weaponType,
        firePoint = firePointWorld,
        hitPoint = hitPointWorld,
        didHit = didHit,
        didHitStellarisBody = didHitStellarisBody,
        didHitShield = didHitShield,
        hitTargetBodyId = hitTargetBodyId,
        normal = normal,
        impactLayer = impactLayer,
        incrementShotId = 1,
    })
end

function server.xSlot_broadcastWeaponIdle(shipBodyId, slotIndex, weaponType, firePointWorld)
    server.xSlotRenderPushEvent(shipBodyId, {
        eventType = "idle",
        slotIndex = slotIndex,
        weaponType = weaponType,
        firePoint = firePointWorld,
        hitPoint = firePointWorld,
        didHit = false,
        didHitStellarisBody = false,
        didHitShield = false,
        hitTargetBodyId = 0,
        normal = { x = 0, y = 1, z = 0 },
        impactLayer = "none",
        incrementShotId = 0,
    })
end

local function _xSlotPickReadySlot(slots, preferredSlot)
    local preferred = math.floor(preferredSlot or 0)
    if preferred >= 1 and preferred <= #slots then
        local entry = slots[preferred] or {}
        local config = entry.config or {}
        local runtime = entry.runtime or {}
        if _xSlotWeaponTypeUsable(config.weaponType) and (runtime.cd or 0.0) <= 0.0 then
            return preferred
        end
    end

    for i = 1, #slots do
        local entry = slots[i] or {}
        local config = entry.config or {}
        local runtime = entry.runtime or {}
        if _xSlotWeaponTypeUsable(config.weaponType) and (runtime.cd or 0.0) <= 0.0 then
            return i
        end
    end

    return nil
end

local function _xSlotBeginLegacyCharging(slotEntry)
    local config = slotEntry.config or {}
    local runtime = slotEntry.runtime or {}
    runtime.state = "charging"
    runtime.charge = 0.0
    runtime.launchRemain = 0.0
    runtime.cd = 0.0
    if (tonumber(config.chargeDuration) or 0.0) <= 0.0 then
        runtime.state = "launching"
        runtime.launchRemain = math.max(0.0, tonumber(config.launchDuration) or 0.0)
    end
end

local function _xSlotTickHoldReleaseWeapon(slotEntry, holdRequested, releaseRequested, dt)
    local config = slotEntry.config or {}
    local runtime = slotEntry.runtime or {}
    local currentState = tostring(runtime.state or "idle")
    local prevState = currentState
    local launchTriggered = false

    local chargeDuration = math.max(0.0, tonumber(config.chargeDuration) or 0.0)
    local launchDuration = math.max(0.0, tonumber(config.launchDuration) or 0.0)
    local decayDuration = math.max(0.0001, tonumber(config.chargeDecayDuration) or chargeDuration or 0.0001)
    local decayRate = chargeDuration / decayDuration

    if currentState == "idle" then
        if holdRequested and (runtime.cd or 0.0) <= 0.0 then
            runtime.state = "charging"
            currentState = "charging"
        end
    end

    if currentState == "charging" then
        if not holdRequested and (runtime.charge or 0.0) < chargeDuration then
            runtime.state = "decaying"
            currentState = "decaying"
        else
            local nextCharge = math.min(chargeDuration, (runtime.charge or 0.0) + dt)
            runtime.charge = nextCharge
            if chargeDuration <= 0.0 or nextCharge >= chargeDuration then
                runtime.charge = chargeDuration
                runtime.state = "charged"
                currentState = "charged"
            end
        end
    end

    if currentState == "charged" then
        runtime.charge = chargeDuration
        if releaseRequested then
            runtime.state = "launching"
            runtime.launchRemain = launchDuration
            currentState = "launching"
            launchTriggered = true
        end
    elseif currentState == "decaying" then
        if holdRequested and (runtime.cd or 0.0) <= 0.0 then
            runtime.state = "charging"
            currentState = "charging"
        else
            local nextCharge = (runtime.charge or 0.0) - decayRate * dt
            if nextCharge <= 0.0 then
                runtime.charge = 0.0
                runtime.state = "idle"
                currentState = "idle"
            else
                runtime.charge = nextCharge
            end
        end
    elseif currentState == "launching" then
        local nextRemain = (runtime.launchRemain or 0.0) - dt
        if nextRemain <= 0.0 then
            runtime.launchRemain = 0.0
            runtime.charge = 0.0
            runtime.state = "idle"
            runtime.cd = math.max(0.0, tonumber(config.cooldown) or 0.0)
            currentState = "idle"
        else
            runtime.launchRemain = nextRemain
        end
    end

    return prevState, tostring(runtime.state or currentState), launchTriggered
end

local function _xSlotTickLegacyWeapon(slotEntry, requestFire, dt)
    local config = slotEntry.config or {}
    local runtime = slotEntry.runtime or {}
    local currentState = tostring(runtime.state or "idle")
    local prevState = currentState
    local launchTriggered = false

    if currentState == "idle" and requestFire and (runtime.cd or 0.0) <= 0.0 then
        _xSlotBeginLegacyCharging(slotEntry)
        currentState = tostring(runtime.state or "charging")
        if currentState == "launching" then
            launchTriggered = true
        end
    end

    if currentState == "charging" then
        local chargeDuration = math.max(0.0, tonumber(config.chargeDuration) or 0.0)
        local nextCharge = (runtime.charge or 0.0) + dt
        runtime.charge = nextCharge
        if chargeDuration <= 0.0 or nextCharge >= chargeDuration then
            runtime.charge = chargeDuration
            runtime.state = "launching"
            runtime.launchRemain = math.max(0.0, tonumber(config.launchDuration) or 0.0)
            currentState = "launching"
            launchTriggered = true
        end
    elseif currentState == "launching" then
        local nextRemain = (runtime.launchRemain or 0.0) - dt
        if nextRemain <= 0.0 then
            runtime.launchRemain = 0.0
            runtime.charge = 0.0
            runtime.state = "idle"
            runtime.cd = math.max(0.0, tonumber(config.cooldown) or 0.0)
            currentState = "idle"
        else
            runtime.launchRemain = nextRemain
        end
    end

    return prevState, tostring(runtime.state or currentState), launchTriggered
end

function server.xSlotControlTick(dt)
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        return
    end
    if not server.registryShipEnsure(shipBody, server.defaultShipType, server.defaultShipType) then
        return
    end

    local xState = server.xSlotState
    if xState == nil then
        return
    end

    local slots = xState.slots or {}
    if #slots <= 0 then
        return
    end

    _xSlotDecayCooldowns(slots, dt)

    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(shipBody) then
        if server.xSlotStateResetRuntime ~= nil then
            server.xSlotStateResetRuntime()
        end
        if server.xSlotStatePushHud ~= nil then
            server.xSlotStatePushHud(true)
        end
        return
    end

    local currentMode = server.shipRuntimeGetCurrentMainWeapon ~= nil and server.shipRuntimeGetCurrentMainWeapon(shipBody) or "tSlot"
    local shipOccupied = _anyPlayerDrivingShip(shipBody)
    local canOperate = (currentMode == "tSlot") and shipOccupied
    if not canOperate then
        if server.xSlotStateClearTransientRuntime ~= nil then
            server.xSlotStateClearTransientRuntime()
        end
    end

    local holdRequested = canOperate and (server.xSlotStateGetHoldRequested ~= nil and server.xSlotStateGetHoldRequested() or false) or false
    local releaseRequested = canOperate and (server.xSlotStateConsumeReleaseRequested ~= nil and server.xSlotStateConsumeReleaseRequested() or false) or false
    local legacyRequest = canOperate and (server.xSlotStateConsumeRequestFire ~= nil and server.xSlotStateConsumeRequestFire() or false) or false

    local activeSlot = math.floor(xState.activeSlot or 1)
    if activeSlot < 1 or activeSlot > #slots then
        activeSlot = 1
        xState.activeSlot = activeSlot
    end

    local activeEntry = slots[activeSlot] or {}
    local activeConfig = activeEntry.config or {}
    local activeRuntime = activeEntry.runtime or {}
    local activeState = tostring(activeRuntime.state or "idle")
    local triggerMode = tostring(activeConfig.triggerMode or "press")

    if activeState == "idle" or (activeRuntime.cd or 0.0) > 0.0 or (not _xSlotWeaponTypeUsable(activeConfig.weaponType)) then
        local preferredSlot = activeSlot
        if triggerMode == "hold_release" and ((activeRuntime.charge or 0.0) > 0.0) and (activeRuntime.cd or 0.0) <= 0.0 then
            preferredSlot = activeSlot
        elseif holdRequested or legacyRequest then
            preferredSlot = _xSlotPickReadySlot(slots, activeSlot) or activeSlot
        end

        if preferredSlot ~= activeSlot then
            activeSlot = preferredSlot
            xState.activeSlot = activeSlot
            activeEntry = slots[activeSlot] or {}
            activeConfig = activeEntry.config or {}
            activeRuntime = activeEntry.runtime or {}
            activeState = tostring(activeRuntime.state or "idle")
            triggerMode = tostring(activeConfig.triggerMode or "press")
        end
    end

    local prevState, newState, launchTriggered
    if triggerMode == "hold_release" then
        prevState, newState, launchTriggered = _xSlotTickHoldReleaseWeapon(activeEntry, holdRequested, releaseRequested, dt)
    else
        prevState, newState, launchTriggered = _xSlotTickLegacyWeapon(activeEntry, legacyRequest, dt)
    end

    local mountPos = activeConfig.firePosOffset or { x = 0, y = 0, z = -4 }
    local mountDir = activeConfig.fireDirRelative or { x = 0, y = 0, z = -1 }
    local firePosOffset = _vec3TableToVec(mountPos, 0, 0, -4)
    local fireDir = _vec3TableToVec(mountDir, 0, 0, -1)
    local shipT = GetBodyTransform(shipBody)
    local firePointWorld = TransformToParentPoint(shipT, firePosOffset)
    local runtimeWeaponType = tostring(activeConfig.weaponType or "none")

    if newState ~= prevState then
        if newState == "charging" then
            server.xSlot_broadcastChargingStart(shipBody, activeSlot, runtimeWeaponType, firePointWorld)
        elseif newState == "charged" then
            server.xSlot_broadcastChargeState(shipBody, activeSlot, runtimeWeaponType, firePointWorld, "charged_hold")
        elseif newState == "decaying" then
            server.xSlot_broadcastChargeState(shipBody, activeSlot, runtimeWeaponType, firePointWorld, "decaying_start")
        elseif newState == "idle" then
            server.xSlot_broadcastWeaponIdle(shipBody, activeSlot, runtimeWeaponType, firePointWorld)
        end
    end

    if launchTriggered and _xSlotWeaponTypeUsable(runtimeWeaponType) then
        local endPos, hitTarget, isHit, isHitStellarisBody, normal = server.xSlot_computeHitResult(shipBody, firePosOffset, fireDir, runtimeWeaponType)
        local renderHitResult = server.xSlot_applyHitResult(shipBody, endPos, hitTarget, isHit, isHitStellarisBody, runtimeWeaponType)
        server.xSlot_broadcastLaunchingStart(
            shipBody,
            activeSlot,
            runtimeWeaponType,
            firePointWorld,
            endPos,
            isHit,
            renderHitResult.didHitStellarisBody,
            renderHitResult.didHitShield,
            renderHitResult.hitTargetBodyId or hitTarget,
            normal,
            renderHitResult.impactLayer
        )
    end

    xState.lastTickState = tostring((activeEntry.runtime or {}).state or "idle")
    xState.lastTickActiveSlot = activeSlot

    if server.xSlotStatePushHud ~= nil then
        server.xSlotStatePushHud(false)
    end
end
