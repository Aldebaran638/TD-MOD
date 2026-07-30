---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}
server.weaponGroupStateById = server.weaponGroupStateById or {}

local function _resolveShipDefinition(shipType)
    if server.shipSlotLoadoutResolveShipDefinition ~= nil then
        local resolved = server.shipSlotLoadoutResolveShipDefinition(shipType)
        if resolved ~= nil then return resolved end
    end
    return shipDefinitionGet(shipType, server.shipContextGetType())
end

local function _buildState(group, shipType)
    local groupId = tostring((group or {}).groupId or "")
    local shipDef = _resolveShipDefinition(shipType)
    local mountCollection = tostring((group or {}).mountCollection or "")
    local mounts = shipDef[mountCollection] or {}
    local state = {
        groupId = groupId,
        slotType = tostring((group or {}).slotType or ""),
        mountCollection = mountCollection,
        shipType = shipType,
        nextMountIndex = 1,
        mounts = {},
        pending = nil,
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
    return state
end

local function _pickReadyMounts(state, weaponDef)
    local count = #(state.mounts or {})
    if count == 0 then return nil, nil end
    local profile = (weaponDef or {}).salvoProfile or {}
    local groupSize = math.max(1, math.min(count, math.floor(tonumber(profile.groupSize) or 1)))
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
    if controller ~= nil and controller.ownsHud then return end
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
    for _, group in ipairs(definition.weaponGroups or {}) do
        local groupId = tostring(group.groupId or "")
        local state = _buildState(group, resolvedType)
        server.weaponGroupStateById[groupId] = state
        local weaponType, definition = _resolveWeapon(state)
        if weaponType ~= "none" and definition ~= nil then
            local ok, err = server.weaponBehaviorValidateDefinition(definition)
            if not ok then
                valid = false
                DebugPrint("[weaponGroup] " .. groupId .. ": " .. tostring(err))
            end
            ok, err = server.weaponControllerValidateDefinition(definition)
            if not ok then
                valid = false
                DebugPrint("[weaponGroup] " .. groupId .. ": " .. tostring(err))
            end
        end
    end
    return valid
end

function server.weaponGroupReset()
    for _, state in pairs(server.weaponGroupStateById or {}) do
        state.nextMountIndex = 1
        state.pending = nil
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

function server.weaponGroupSetFireHeld(groupId, active, request)
    local state = server.weaponGroupStateById[tostring(groupId or "")]
    if state == nil then return false, "unknown weapon group" end
    local weaponType, weaponDef = _resolveWeapon(state)
    local controller = server.weaponControllerResolve(weaponDef)
    if controller ~= nil and controller.ownsHold and type(controller.setHeld) == "function" then
        state.fireHeld = false
        state.heldRequest = nil
        return controller.setHeld({
            groupId = state.groupId,
            state = state,
            weaponType = weaponType,
            weaponDefinition = weaponDef,
            request = request or {},
        }, active and true or false)
    end
    state.fireHeld = active and true or false
    if state.fireHeld then
        local source = request or {}
        state.heldRequest = {
            shipBodyId = math.floor(source.shipBodyId or server.shipContextGetBody()),
            targetVehicleId = math.floor(source.targetVehicleId or 0),
            targetBodyId = math.floor(source.targetBodyId or 0),
        }
        -- A short click can be pressed and released between two server ticks.
        -- Fire the first shot immediately; weaponGroupTick owns held refire.
        return server.weaponGroupRequestFire(state.groupId, state.heldRequest)
    else
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
    if controller ~= nil and type(controller.onSelected) == "function" then
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

local function _requestHasTarget(request)
    local targetBodyId = math.floor((request or {}).targetBodyId or 0)
    if targetBodyId ~= 0 and IsHandleValid(targetBodyId) then return true end
    local targetVehicleId = math.floor((request or {}).targetVehicleId or 0)
    if targetVehicleId == 0 then return false end
    local vehicleBodyId = math.floor(GetVehicleBody(targetVehicleId) or 0)
    return vehicleBodyId ~= 0 and IsHandleValid(vehicleBodyId)
end

local function _fireContexts(behavior, contexts, mounts, cooldown)
    local fired = false
    for i = 1, #contexts do
        if behavior.fire(contexts[i]) then
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

    local normalizedRequest = request or {}
    normalizedRequest.shipBodyId = math.floor(
        normalizedRequest.shipBodyId or server.shipContextGetBody()
    )
    normalizedRequest.targetVehicleId = math.floor(normalizedRequest.targetVehicleId or 0)
    normalizedRequest.targetBodyId = math.floor(normalizedRequest.targetBodyId or 0)
    normalizedRequest.groupId = id
    normalizedRequest.weaponType = weaponType

    if tostring(weaponDef.targetingMode or "") == "target_lock"
        and not _requestHasTarget(normalizedRequest) then
        return false, "target lock required"
    end

    local controller = server.weaponControllerResolve(weaponDef)
    if controller ~= nil then
        local fired = controller.requestFire({
            groupId = id,
            state = state,
            weaponType = weaponType,
            weaponDefinition = weaponDef,
            request = normalizedRequest,
        })
        if fired then
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
            pending.remaining = (tonumber(pending.remaining) or 0.0) - delta
            if pending.remaining <= 0.0 then
                _fireContexts(
                    pending.behavior,
                    pending.contexts or {},
                    pending.mounts or {},
                    pending.cooldown or 0.0
                )
                local _, weaponDef = _resolveWeapon(state)
                state.fireDelay = math.max(
                    0.0,
                    tonumber(((weaponDef or {}).salvoProfile or {}).interval) or 0.0
                )
                state.pending = nil
                _pushHud(state, true)
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
