---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}
server.weaponGroupStateById = server.weaponGroupStateById or {}
server.weaponGroupDebugEnabled = server.weaponGroupDebugEnabled or false

-- 空闲批量更新优化：无人驾驶时降低tick频率。用秒数而不是帧数，避免
-- 不同帧率下冷却、热量和蓄力推进速度不一致。
local _idleTickInterval = 0.25
local _idleAccumulatedDelta = 0.0

local function _resolveShipDefinition(shipType)
    if server.shipSlotLoadoutResolveShipDefinition ~= nil then
        return server.shipSlotLoadoutResolveShipDefinition(shipType)
    end
    return shipDefinitionGet(shipType, server.shipContextGetType())
end

local function _weaponGroupBreakCloak(shipBodyId)
    if server.shipCloakBreakForWeapon ~= nil then
        server.shipCloakBreakForWeapon(math.floor(tonumber(shipBodyId) or 0))
    end
end

local function _weaponGroupIsChargedRay(weaponDefinition)
    local definition = weaponDefinition or {}
    return tostring(definition.weaponClass or "") == "chargedRay"
        or tostring(definition.controllerType or "") == "chargedRay"
end

local function _weaponGroupRequiresTargetLock(weaponDefinition)
    return weaponTargetingPolicy.requiresTargetLock(weaponDefinition)
end

local function _weaponGroupPushChargedRayEvent(context, eventType, payload)
    local source = context or {}
    local event = payload or {}
    event.eventType = eventType
    event.weaponType = tostring(source.weaponType or "")
    event.slotIndex = math.floor(source.mountIndex or 1)
    event.firePoint = event.firePoint or select(1,
        server.weaponBehaviorResolveFireTransform(source)
    )

    local slotType = tostring(source.slotType or "")
    if slotType == "T" and server.tSlotRenderPushEvent ~= nil then
        server.tSlotRenderPushEvent(source.shipBodyId, event)
    elseif server.xSlotRenderPushEvent ~= nil then
        server.xSlotRenderPushEvent(source.shipBodyId, event)
    end
end

local function _buildState(group, shipType)
    local groupId = tostring((group or {}).groupId or "")
    local shipDef = _resolveShipDefinition(shipType)
    if shipDef == nil then
        return nil, "resolved ship loadout is unavailable"
    end
    local mountCollection = tostring((group or {}).mountCollection or "")
    local mounts = shipDef[mountCollection] or {}
    local configuredCount = math.max(0, math.floor(tonumber((group or {}).count) or 0))
    if #mounts < configuredCount then
        return nil, "resolved mount collection " .. mountCollection
            .. " has " .. tostring(#mounts) .. " mounts, expected "
            .. tostring(configuredCount)
    end
    -- slot_loadout has already normalized this ship-owned override.
    local salvoGroupSize = (group or {}).salvoGroupSize
    local state = {
        groupId = groupId,
        slotType = tostring((group or {}).slotType or ""),
        mountCollection = mountCollection,
        shipType = shipType,
        salvoGroupSize = salvoGroupSize,
        nextMountIndex = 1,
        mounts = {},
        pending = nil,
        releaseRequested = false,
        fireHeld = false,
        heldRequest = nil,
        fireDelay = 0.0,
        hudSyncAge = 0.0,
        hudLastSignature = "",
        hudLastSentAt = -1000.0,
    }
    for i = 1, #mounts do
        state.mounts[i] = {
            definition = mounts[i],
            cooldownRemain = 0.0,
            heat = 0.0,
            overheated = false,
        }
    end
    if server.weaponGroupDebugEnabled and state.groupId == "tSlot" then
        DebugPrint("[perditionHud] server mounts=" .. tostring(#state.mounts)
            .. " configured=" .. tostring(configuredCount)
            .. " collection=" .. mountCollection)
    end
    return state
end

local function _pickReadyMounts(state, weaponDef)
    local count = #(state.mounts or {})
    if count == 0 then return nil, nil end
    local profile = (weaponDef or {}).salvoProfile or {}
    local groupSize = state.salvoGroupSize
    if groupSize == nil then
        groupSize = math.floor(tonumber(profile.groupSize) or 1)
    end
    groupSize = math.max(1, math.min(count, groupSize))
    local groupCount = math.ceil(count / groupSize)
    local startMount = math.max(1, math.min(count, math.floor(state.nextMountIndex or 1)))
    local startGroup = math.floor((startMount - 1) / groupSize) + 1

    for offset = 0, groupCount - 1 do
        local groupIndex = ((startGroup - 1 + offset) % groupCount) + 1
        local firstIndex = (groupIndex - 1) * groupSize + 1
        local mounts, indices = {}, {}
        local ready = true
        for index = firstIndex, math.min(count, firstIndex + groupSize - 1) do
            local mount = state.mounts[index]
            if (tonumber(mount.cooldownRemain) or 0.0) > 0.0
                or (mount.overheated and true or false) then
                ready = false
                break
            end
            mounts[#mounts + 1] = mount
            indices[#indices + 1] = index
        end
        if ready and #mounts > 0 then
            local nextGroup = (groupIndex % groupCount) + 1
            state.nextMountIndex = (nextGroup - 1) * groupSize + 1
            return mounts, indices
        end
    end
    return nil, nil
end

local function _resolveWeapon(state)
    local first = (state.mounts or {})[1]
    local weaponType = tostring(first and first.definition and first.definition.weaponType or "none")
    return weaponType, (weaponData or {})[weaponType]
end

local function _pushHud(state, force)
    local weaponType, weaponDef = _resolveWeapon(state)
    local controller = server.weaponControllerResolve(weaponDef)
    if controller ~= nil and not controller.delegatesToWeaponGroup
        and controller.ownsHud then return end
    local cooldown = math.max(0.0, tonumber((weaponDef or {}).cooldown) or 0.0)
    local overheatThreshold = math.max(0.0, tonumber((weaponDef or {}).overheatThreshold) or 0.0)
    local usesHeat = overheatThreshold > 0.0
    local values, maximums, phases = {}, {}, {}
    for i = 1, 4 do
        local mount = (state.mounts or {})[i]
        local remaining = mount and math.max(0.0, tonumber(mount.cooldownRemain) or 0.0) or 0.0
        if mount ~= nil and usesHeat then
            values[i] = math.max(0.0, tonumber(mount.heat) or 0.0)
            maximums[i] = overheatThreshold
            phases[i] = mount.overheated and "overheated" or "heat"
        else
            values[i] = remaining
            maximums[i] = mount and cooldown or 0.0
            phases[i] = remaining > 0.0001 and "cooldown" or "idle"
        end
        local pending = state.pending
        local isPending = false
        for pendingIndex = 1, #((pending or {}).mounts or {}) do
            if pending.mounts[pendingIndex] == mount then
                isPending = true
                break
            end
        end
        if mount ~= nil and pending ~= nil and isPending then
            local total = math.max(0.0, tonumber(pending.total) or 0.0)
            values[i] = math.max(0.0, total - math.max(0.0, tonumber(pending.remaining) or 0.0))
            maximums[i] = total
            phases[i] = "charging"
        end
        values[i] = server.netSyncQuantize(values[i], 0.05)
    end

    local signatureParts = {
        tostring(state.groupId or ""),
        weaponType,
    }
    for i = 1, 4 do
        signatureParts[#signatureParts + 1] = string.format("%.2f", values[i])
        signatureParts[#signatureParts + 1] = tostring(phases[i] or "")
    end
    local signature = table.concat(signatureParts, "|")
    local now = (GetTime ~= nil) and GetTime() or 0.0
    local changed = signature ~= tostring(state.hudLastSignature or "")
    local intervalDue = now - (state.hudLastSentAt or -1000.0) >= 0.2
    local keepAlive = now - (state.hudLastSentAt or -1000.0) >= 1.0
    if not force and not (changed and intervalDue) and not keepAlive then return end

    local shipBody = server.shipContextGetBody()
    local playerId = server.netResolveShipDriver(shipBody)
    if playerId <= 0 then return end
    if server.weaponGroupDebugEnabled and state.groupId == "tSlot" and maximums[2] <= 0.0 then
        DebugPrint("[perditionHud] server missing T2 HUD mount; mounts="
            .. tostring(#(state.mounts or {})))
    end
    server.netClientCall(
        "hud.weaponGroup",
        playerId,
        "client.updateWeaponGroupHudState",
        shipBody,
        tostring(state.groupId or ""),
        weaponType,
        values[1], values[2], values[3], values[4],
        maximums[1], maximums[2], maximums[3], maximums[4],
        phases[1], phases[2], phases[3], phases[4]
    )
    state.hudLastSignature = signature
    state.hudLastSentAt = now
end

function server.weaponGroupInit(shipType)
    local resolvedType = tostring(shipType or server.shipContextGetType())
    server.weaponGroupStateById = {}
    for _, behavior in pairs(server.weaponBehaviorRegistry or {}) do
        if type(behavior.reset) == "function" then behavior.reset() end
    end
    local valid = true
    local definition = _resolveShipDefinition(resolvedType)
    if definition == nil then
        DebugPrint("[weaponGroup] resolved ship loadout is unavailable")
        return false
    end
    for _, group in ipairs(definition.weaponGroups or {}) do
        local groupId = tostring(group.groupId or "")
        local state, stateError = _buildState(group, resolvedType)
        if state == nil then
            valid = false
            DebugPrint("[weaponGroup] " .. groupId .. ": " .. tostring(stateError or "invalid state"))
        else
            server.weaponGroupStateById[groupId] = state
        end
        if state ~= nil then
            local weaponType, weaponDefinition = _resolveWeapon(state)
            if weaponType ~= "none" and weaponDefinition ~= nil then
                local ok, err = server.weaponBehaviorValidateDefinition(weaponDefinition)
                if not ok then
                    valid = false
                    DebugPrint("[weaponGroup] " .. groupId .. ": " .. tostring(err))
                end
                ok, err = server.weaponControllerValidateDefinition(weaponDefinition)
                if not ok then
                    valid = false
                    DebugPrint("[weaponGroup] " .. groupId .. ": " .. tostring(err))
                end
            end
        end
    end
    return valid
end

function server.weaponGroupReset()
    for _, state in pairs(server.weaponGroupStateById or {}) do
        state.nextMountIndex = 1
        state.pending = nil
        state.releaseRequested = false
        state.fireHeld = false
        state.heldRequest = nil
        state.fireDelay = 0.0
        for i = 1, #(state.mounts or {}) do
            state.mounts[i].cooldownRemain = 0.0
            state.mounts[i].heat = 0.0
            state.mounts[i].overheated = false
        end
    end
    for _, behavior in pairs(server.weaponBehaviorRegistry or {}) do
        if type(behavior.reset) == "function" then behavior.reset() end
    end
end

local function _weaponGroupNormalizeRequest(groupId, weaponType, request)
    local source = request or {}
    local normalized = {
        shipBodyId = math.floor(
            tonumber(source.shipBodyId) or tonumber(server.shipContextGetBody()) or 0
        ),
        targetVehicleId = math.floor(tonumber(source.targetVehicleId) or 0),
        targetBodyId = math.floor(tonumber(source.targetBodyId) or 0),
        groupId = tostring(groupId or ""),
        weaponType = tostring(weaponType or "none"),
    }
    return normalized
end

local function _requestHasTarget(request)
    local targetBodyId = math.floor((request or {}).targetBodyId or 0)
    if targetBodyId ~= 0 and IsHandleValid(targetBodyId) then return true end
    local targetVehicleId = math.floor((request or {}).targetVehicleId or 0)
    if targetVehicleId == 0 then return false end
    local vehicleBodyId = math.floor(GetVehicleBody(targetVehicleId) or 0)
    return vehicleBodyId ~= 0 and IsHandleValid(vehicleBodyId)
end

local function _requestTargetPosition(request)
    local targetBodyId = math.floor((request or {}).targetBodyId or 0)
    if targetBodyId ~= 0 and IsHandleValid(targetBodyId) then
        local transform = GetBodyTransform(targetBodyId)
        return TransformToParentPoint(transform, GetBodyCenterOfMass(targetBodyId))
    end
    local targetVehicleId = math.floor((request or {}).targetVehicleId or 0)
    if targetVehicleId ~= 0 then
        local bodyId = math.floor(GetVehicleBody(targetVehicleId) or 0)
        if bodyId ~= 0 and IsHandleValid(bodyId) then
            local transform = GetBodyTransform(bodyId)
            return TransformToParentPoint(transform, GetBodyCenterOfMass(bodyId))
        end
        local vehicleTransform = GetVehicleTransform(targetVehicleId)
        return vehicleTransform and vehicleTransform.pos or nil
    end
    return nil
end

local function _requestWithinSensorAndWeaponRange(request, weaponDefinition)
    local targetPosition = _requestTargetPosition(request)
    local shipBodyId = math.floor((request or {}).shipBodyId or 0)
    if targetPosition == nil or shipBodyId == 0 or not IsHandleValid(shipBodyId) then
        return false
    end
    local shipTransform = GetBodyTransform(shipBodyId)
    local shipPosition = TransformToParentPoint(
        shipTransform,
        GetBodyCenterOfMass(shipBodyId)
    )
    local distance = VecLength(VecSub(targetPosition, shipPosition))
    local weaponRange = tonumber((weaponDefinition or {}).maxRange) or 0.0
    if weaponRange > 0.0 and distance > weaponRange then
        return false
    end
    local sensor = ((server.shipComponentProfile or {}).sensor or {})
    local sensorRange = tonumber(sensor.range) or 0.0
    return sensorRange <= 0.0 or distance <= sensorRange
end

local function _weaponGroupValidateRequest(
    groupId,
    weaponType,
    weaponDefinition,
    request
)
    if weaponDefinition == nil or weaponType == "none" then
        return false, "weapon not found", nil
    end

    local normalized = _weaponGroupNormalizeRequest(groupId, weaponType, request)
    local hasTarget = _requestHasTarget(normalized)
    local requiresTargetLock = _weaponGroupRequiresTargetLock(weaponDefinition)
    if requiresTargetLock and not hasTarget then
        return false, "target lock required", nil
    end
    if (requiresTargetLock or _weaponGroupIsChargedRay(weaponDefinition))
        and hasTarget
        and not _requestWithinSensorAndWeaponRange(normalized, weaponDefinition) then
        if requiresTargetLock then
            return false, "target outside sensor or weapon range", nil
        end
        return false, "charged ray target outside sensor or weapon range", nil
    end
    return true, nil, normalized
end

function server.weaponGroupSetFireHeld(groupId, active, request)
    local state = server.weaponGroupStateById[tostring(groupId or "")]
    if state == nil then return false, "unknown weapon group" end
    local weaponType, weaponDef = _resolveWeapon(state)
    local normalizedRequest = _weaponGroupNormalizeRequest(
        state.groupId,
        weaponType,
        request
    )
    if active then
        local valid, validationError, normalized = _weaponGroupValidateRequest(
            state.groupId,
            weaponType,
            weaponDef,
            normalizedRequest
        )
        if not valid then return false, validationError end
        normalizedRequest = normalized
    end
    local controller = server.weaponControllerResolve(weaponDef)
    if controller ~= nil and not controller.delegatesToWeaponGroup
        and controller.ownsHold and type(controller.setHeld) == "function" then
        if active then
            _weaponGroupBreakCloak(normalizedRequest.shipBodyId)
        end
        state.fireHeld = false
        state.heldRequest = nil
        return controller.setHeld({
            groupId = state.groupId,
            state = state,
            weaponType = weaponType,
            weaponDefinition = weaponDef,
            request = normalizedRequest,
        }, active and true or false)
    end
    state.fireHeld = active and true or false
    if state.fireHeld then
        state.releaseRequested = false
        state.heldRequest = {
            shipBodyId = normalizedRequest.shipBodyId,
            targetVehicleId = normalizedRequest.targetVehicleId,
            targetBodyId = normalizedRequest.targetBodyId,
        }
        -- A short click can be pressed and released between two server ticks.
        -- Fire the first shot immediately; weaponGroupTick owns held refire.
        return server.weaponGroupRequestFire(state.groupId, state.heldRequest)
    else
        if (weaponDef.fireProfile or {}).mode == "charged_release" then
            state.releaseRequested = true
        end
        state.heldRequest = nil
    end
    return true, nil
end

function server.weaponGroupClearFireHeld()
    for _, state in pairs(server.weaponGroupStateById or {}) do
        state.fireHeld = false
        state.heldRequest = nil
    end
    server.weaponControllerClearHeld()
end

function server.weaponGroupUsesController(controllerType)
    local requested = tostring(controllerType or "")
    for _, state in pairs(server.weaponGroupStateById or {}) do
        local _, definition = _resolveWeapon(state)
        if tostring((definition or {}).controllerType or "") == requested then
            return true
        end
    end
    return false
end

function server.weaponGroupUsesWeaponClass(weaponClass)
    local requested = tostring(weaponClass or "")
    for _, state in pairs(server.weaponGroupStateById or {}) do
        local _, definition = _resolveWeapon(state)
        if tostring((definition or {}).weaponClass or "") == requested then
            return true
        end
    end
    return false
end

function server.weaponGroupNeedsTick()
    local body = server.shipContextGetBody()
    if body ~= 0 and server.shipRuntimeGetDriverPlayerId(body) > 0 then
        return true
    end
    for _, state in pairs(server.weaponGroupStateById or {}) do
        if state.fireHeld or state.pending ~= nil
            or (tonumber(state.fireDelay) or 0.0) > 0.0 then
            return true
        end
        for _, mount in ipairs(state.mounts or {}) do
            if (tonumber(mount.cooldownRemain) or 0.0) > 0.0
                or (tonumber(mount.heat) or 0.0) > 0.0 then
                return true
            end
        end
    end
    return false
end

function server.weaponGroupSyncHud(groupId, force)
    local state = server.weaponGroupStateById[tostring(groupId or "")]
    if state == nil then return false end
    local weaponType, weaponDef = _resolveWeapon(state)
    local controller = server.weaponControllerResolve(weaponDef)
    if controller ~= nil and not controller.delegatesToWeaponGroup
        and type(controller.onSelected) == "function" then
        controller.onSelected({
            groupId = state.groupId,
            state = state,
            weaponType = weaponType,
            weaponDefinition = weaponDef,
        })
        return true
    end
    _pushHud(state, force and true or false)
    return true
end

local function _fireContexts(behavior, contexts, mounts, cooldown)
    local fired = false
    for i = 1, #contexts do
        if behavior.fire(contexts[i]) then
            _weaponGroupBreakCloak(contexts[i].shipBodyId)
            mounts[i].cooldownRemain = cooldown
            local definition = contexts[i].weaponDefinition or {}
            local overheatThreshold = math.max(
                0.0,
                tonumber(definition.overheatThreshold) or 0.0
            )
            if overheatThreshold > 0.0 then
                mounts[i].heat = math.min(
                    overheatThreshold,
                    math.max(0.0, tonumber(mounts[i].heat) or 0.0)
                        + math.max(0.0, tonumber(definition.heatPerShot) or 0.0)
                )
                if mounts[i].heat >= overheatThreshold then
                    mounts[i].overheated = true
                end
            end
            fired = true
        end
    end
    return fired
end

function server.weaponGroupRequestFire(groupId, request)
    local id = tostring(groupId or "")
    local state = server.weaponGroupStateById[id]
    if state == nil then return false, "unknown weapon group" end
    local weaponType, weaponDef = _resolveWeapon(state)
    if weaponDef == nil or weaponType == "none" then return false, "weapon not found" end
    if (tonumber(state.fireDelay) or 0.0) > 0.0 then return false, "weapon group pacing" end

    local valid, validationError, normalizedRequest = _weaponGroupValidateRequest(
        id,
        weaponType,
        weaponDef,
        request
    )
    if not valid then return false, validationError end

    local controller = server.weaponControllerResolve(weaponDef)
    if controller ~= nil and not controller.delegatesToWeaponGroup then
        local fired = controller.requestFire({
            groupId = id,
            state = state,
            weaponType = weaponType,
            weaponDefinition = weaponDef,
            request = normalizedRequest,
        })
        if fired then
            _weaponGroupBreakCloak(normalizedRequest.shipBodyId)
            state.fireDelay = math.max(
                0.0,
                tonumber((weaponDef.salvoProfile or {}).interval) or 0.0
            )
        end
        return fired
    end

    if state.pending ~= nil then return false, "weapon group is charging" end
    local mounts, mountIndices = _pickReadyMounts(state, weaponDef)
    if mounts == nil then return false, "all mounts cooling down" end
    local behavior = server.weaponBehaviorGet(weaponDef.behaviorType)
    if behavior == nil then return false, "behavior not registered" end
    local contexts = {}
    for i = 1, #mounts do
        contexts[i] = {
            groupId = id,
            slotType = state.slotType,
            shipBodyId = normalizedRequest.shipBodyId,
            targetVehicleId = normalizedRequest.targetVehicleId,
            targetBodyId = normalizedRequest.targetBodyId,
            weaponType = weaponType,
            weaponDefinition = weaponDef,
            mountDefinition = mounts[i].definition,
            mountIndex = mountIndices[i],
        }
    end
    local fireProfile = weaponDef.fireProfile or {}
    local chargeDuration = math.max(0.0, tonumber(fireProfile.chargeDuration) or 0.0)
    local cooldown = math.max(0.0, tonumber(weaponDef.cooldown) or 0.0)
    if chargeDuration > 0.0 then
        _weaponGroupBreakCloak(normalizedRequest.shipBodyId)
        if _weaponGroupIsChargedRay(weaponDef) then
            _weaponGroupPushChargedRayEvent(
                contexts[1],
                "charging_start"
            )
            server.chargedRayVisualBeginCharge(weaponType, weaponDef)
        end
        state.pending = {
            remaining = chargeDuration,
            total = chargeDuration,
            behavior = behavior,
            contexts = contexts,
            mounts = mounts,
            cooldown = cooldown,
        }
        _pushHud(state, true)
        return true, nil
    end
    local fired = _fireContexts(behavior, contexts, mounts, cooldown)
    if fired then
        state.fireDelay = math.max(
            0.0,
            tonumber((weaponDef.salvoProfile or {}).interval) or 0.0
        )
    end
    _pushHud(state, true)
    return fired, fired and nil or "controller rejected fire"
end

function server.weaponGroupTick(dt)
    local delta = math.max(0.0, tonumber(dt) or 0.0)

    -- 批量更新优化：无人驾驶时降低tick频率
    local body = server.shipContextGetBody()
    local hasDriver = body ~= 0 and server.shipRuntimeGetDriverPlayerId(body) > 0

    if not hasDriver then
        _idleAccumulatedDelta = _idleAccumulatedDelta + delta
        if _idleAccumulatedDelta < _idleTickInterval then
            return  -- 跳过这一帧，节省CPU
        end

        -- 达到间隔，使用累积的delta执行一次完整更新
        delta = _idleAccumulatedDelta
        _idleAccumulatedDelta = 0.0
    else
        -- 驾驶员重新进入时，先补算无人驾驶期间累计的时间，避免冷却/热量丢失。
        delta = delta + _idleAccumulatedDelta
        _idleAccumulatedDelta = 0.0
    end

    for _, state in pairs(server.weaponGroupStateById or {}) do
        state.fireDelay = math.max(0.0, (tonumber(state.fireDelay) or 0.0) - delta)
        local _, weaponDef = _resolveWeapon(state)
        local heatDissipation = math.max(
            0.0,
            tonumber((weaponDef or {}).heatDissipationPerSecond) or 0.0
        )
        local recoverThreshold = math.max(
            0.0,
            tonumber((weaponDef or {}).recoverThreshold) or 0.0
        )
        for i = 1, #(state.mounts or {}) do
            local mount = state.mounts[i]
            mount.cooldownRemain = math.max(0.0, (tonumber(mount.cooldownRemain) or 0.0) - delta)
            mount.heat = math.max(
                0.0,
                (tonumber(mount.heat) or 0.0) - heatDissipation * delta
            )
            if mount.overheated and mount.heat <= recoverThreshold then
                mount.overheated = false
            end
        end
        local pending = state.pending
        if pending ~= nil then
            local fireProfile = (weaponDef or {}).fireProfile or {}
            if fireProfile.mode == "charged_release" then
                pending.remaining = (tonumber(pending.remaining) or 0.0) - delta
                if pending.remaining <= 0.0 then
                    pending.remaining = 0.0
                    pending.charged = true
                    _pushHud(state, true)
                end
                if state.releaseRequested then
                    if pending.charged then
                        _fireContexts(
                            pending.behavior,
                            pending.contexts or {},
                            pending.mounts or {},
                            pending.cooldown or 0.0
                        )
                        state.fireDelay = math.max(
                            0.0,
                            tonumber(((weaponDef or {}).salvoProfile or {}).interval) or 0.0
                        )
                    elseif _weaponGroupIsChargedRay(weaponDef) then
                        local context = (pending.contexts or {})[1] or {}
                        _weaponGroupPushChargedRayEvent(
                            context,
                            "charge_cancel"
                        )
                        server.chargedRayVisualStop(context.weaponType, weaponDef)
                    end
                    state.pending = nil
                    state.releaseRequested = false
                    _pushHud(state, true)
                end
            else
                pending.remaining = (tonumber(pending.remaining) or 0.0) - delta
                if pending.remaining <= 0.0 then
                    _fireContexts(
                        pending.behavior,
                        pending.contexts or {},
                        pending.mounts or {},
                        pending.cooldown or 0.0
                    )
                    state.fireDelay = math.max(
                        0.0,
                        tonumber(((weaponDef or {}).salvoProfile or {}).interval) or 0.0
                    )
                    state.pending = nil
                    _pushHud(state, true)
                end
            end
        end
        if state.fireHeld and state.pending == nil then
            server.weaponGroupRequestFire(state.groupId, state.heldRequest or {})
        end
        state.hudSyncAge = (tonumber(state.hudSyncAge) or 0.0) + delta
        local currentMode = server.shipRuntimeGetCurrentMainWeapon ~= nil
            and server.shipRuntimeGetCurrentMainWeapon(server.shipContextGetBody()) or ""
        if state.hudSyncAge >= 0.20 and currentMode == state.groupId then
            state.hudSyncAge = 0.0
            _pushHud(state, false)
        end
    end
    for _, behavior in pairs(server.weaponBehaviorRegistry or {}) do
        if type(behavior.tick) == "function" then behavior.tick(delta) end
    end
end
