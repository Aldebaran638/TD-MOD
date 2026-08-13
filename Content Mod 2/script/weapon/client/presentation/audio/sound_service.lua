---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local _soundDistanceThreshold = 150.0
local _soundVirtualNearDist = 40.0
local _sndMissileLoop = nil
local _weaponSoundHandles = {}
local _engineLoopHandles = {}

client.soundModuleState = client.soundModuleState or {
    lastRenderSeqByShip = {},
    lastTSlotSequenceByShip = {},
}

local function _tableToVec(t)
    if t == nil then return Vec(0, 0, 0) end
    return Vec(t.x or 0, t.y or 0, t.z or 0)
end

local function _loadSounds(paths)
    local result = {}
    for i = 1, #(paths or {}) do
        result[#result + 1] = LoadSound(paths[i])
    end
    return result
end

local function _randomPick(values)
    if values == nil or #values == 0 then return nil end
    return values[math.random(1, #values)]
end

local function _resolvePlayPos(eventPos)
    local cameraPos = GetCameraTransform().pos
    local distance = VecLength(VecSub(eventPos, cameraPos))
    if distance > _soundDistanceThreshold then
        local direction = VecNormalize(VecSub(eventPos, cameraPos))
        return VecAdd(cameraPos, VecScale(direction, _soundVirtualNearDist)), true
    end
    return eventPos, false
end

function client.playWeaponSound(weaponType, eventType, x, y, z)
    local requested = tostring(weaponType or "")
    local definition = (weaponData or {})[requested] or {}
    if tostring(definition.soundProfileId or "") == "none" then return end
    local profile = _weaponSoundHandles[requested]
        or _weaponSoundHandles[tostring(definition.soundProfileId or "")]
    if profile == nil then return end
    local position, distant = _resolvePlayPos(Vec(x or 0, y or 0, z or 0))
    local suffix = distant and "Far" or "Near"
    local handles = profile[tostring(eventType or "") .. suffix]
    if handles == nil or #handles == 0 then
        handles = profile[tostring(eventType or "") .. "Near"]
    end
    local handle = _randomPick(handles)
    client.presentationBudget.playSound(handle, position, 1.0, {
        effect = requested,
        priority = eventType == "hit" and "critical" or "normal",
        distance = distant and _soundDistanceThreshold or 0.0,
    })
end

local function _isShipOccupied(shipBodyId)
    local vehicle = GetBodyVehicle(shipBodyId)
    return vehicle ~= nil and vehicle ~= 0 and GetPlayerVehicle() == vehicle
end

local function _getShipEngineSound(shipBodyId)
    if client.registryShipGetShipType == nil or shipDefinitionGet == nil then
        return nil, 0.0
    end
    local shipType = tostring(client.registryShipGetShipType(shipBodyId) or "")
    local definition = shipDefinitionGet(shipType, shipType)
    local sound = definition.engineSound or {}
    local path = tostring(sound.idleLoopPath or "")
    local volume = tonumber(sound.volume) or 1.0
    if path == "" or volume <= 0.0 then return nil, 0.0 end
    return path, volume
end

local function _getEngineLoop(path)
    local cached = _engineLoopHandles[path]
    if cached == nil then
        cached = LoadLoop(path)
        _engineLoopHandles[path] = cached or 0
    end
    return cached
end

local function _engineTick(shipBodyId)
    if not _isShipOccupied(shipBodyId) then return end
    local path, volume = _getShipEngineSound(shipBodyId)
    if path == nil then return end
    local loop = _getEngineLoop(path)
    if loop == nil or loop == 0 then return end
    PlayLoop(loop, GetBodyTransform(shipBodyId).pos, volume)
end

local function _xSlotEventTick(shipBodyId)
    local render = client.xSlotRenderGetEvent(shipBodyId)
    if render == nil then return end
    local state = client.soundModuleState
    local sequence = render.seq or -1
    if sequence == (state.lastRenderSeqByShip[shipBodyId] or -1) then return end
    state.lastRenderSeqByShip[shipBodyId] = sequence

    local weaponType = tostring(render.weaponType or "")
    local definition = (weaponData or {})[weaponType] or {}
    if tostring(definition.soundProfileId or "") == "" then return end
    local firePoint = _tableToVec(render.firePoint)
    local eventType = tostring(render.eventType or "")
    if eventType == "charging_start" then
        client.playWeaponSound(weaponType, "windup", firePoint[1], firePoint[2], firePoint[3])
    elseif eventType == "launch_start" then
        client.playWeaponSound(weaponType, "fire", firePoint[1], firePoint[2], firePoint[3])
        if (render.didHit or 0) == 1 then
            local hitPoint = _tableToVec(render.hitPoint)
            client.playWeaponSound(weaponType, "hit", hitPoint[1], hitPoint[2], hitPoint[3])
        end
    end
end

local function _tSlotEventTick(shipBodyId)
    if client.tSlotRenderGetEvent == nil then return end
    local render = client.tSlotRenderGetEvent(shipBodyId)
    if render == nil then return end
    local weaponType = tostring(render.weaponType or "")
    local definition = (weaponData or {})[weaponType] or {}
    if tostring(definition.soundProfileId or "") == "" then return end

    local state = client.soundModuleState
    local sequence = render.seq or -1
    local firePoint = _tableToVec(render.firePoint)
    local eventType = tostring(render.eventType or "")
    if sequence ~= (state.lastTSlotSequenceByShip[shipBodyId] or -1) then
        state.lastTSlotSequenceByShip[shipBodyId] = sequence
        if eventType == "charging_start" then
            client.playWeaponSound(weaponType, "windup", firePoint[1], firePoint[2], firePoint[3])
        elseif eventType == "launch_start" then
            client.playWeaponSound(weaponType, "fire", firePoint[1], firePoint[2], firePoint[3])
            if (render.didHit or 0) == 1 then
                local hitPoint = _tableToVec(render.hitPoint)
                client.playWeaponSound(weaponType, "hit", hitPoint[1], hitPoint[2], hitPoint[3])
            end
        end
    end
end

function client.soundModuleInit()
    _sndMissileLoop = LoadLoop("MOD/sound/missile_loop.ogg")
    _weaponSoundHandles = {}
    _engineLoopHandles = {}
    client.soundModuleState.lastRenderSeqByShip = {}
    client.soundModuleState.lastTSlotSequenceByShip = {}
    for weaponType, profile in pairs(client.weaponSoundCatalog or {}) do
        _weaponSoundHandles[weaponType] = {
            windupNear = _loadSounds(profile.windupNear),
            windupFar = _loadSounds(profile.windupFar),
            fireNear = _loadSounds(profile.fireNear),
            fireFar = _loadSounds(profile.fireFar),
            hitNear = _loadSounds(profile.hitNear),
            hitFar = _loadSounds(profile.hitFar),
        }
    end
end

function client.playKineticArtilleryFireSound(weaponType, x, y, z)
    client.playWeaponSound(weaponType, "fire", x, y, z)
end

function client.playKineticArtilleryHitSound(weaponType, x, y, z)
    client.playWeaponSound(weaponType, "hit", x, y, z)
end

function client.playMissileFireSound(weaponType, x, y, z)
    client.playWeaponSound(weaponType, "fire", x, y, z)
end

function client.playMissileImpactSound(weaponType, x, y, z)
    client.playWeaponSound(weaponType, "hit", x, y, z)
end

function client.playMissileLoopSound(x, y, z)
    if _sndMissileLoop ~= nil and _sndMissileLoop ~= 0 then
        PlayLoop(_sndMissileLoop, Vec(x or 0, y or 0, z or 0), 1.0)
    end
end

function client.playHSlotGammaFireSound(x, y, z)
    client.playWeaponSound("gammaStrikeCraft", "fire", x, y, z)
end

function client.soundModuleTick(dt)
    local _ = dt
    if client.registryShipGetRegisteredBodyIds == nil then return end
    for _, shipBodyId in ipairs(client.registryShipGetRegisteredBodyIds()) do
        if client.registryShipExists(shipBodyId) then
            _engineTick(shipBodyId)
            _xSlotEventTick(shipBodyId)
            _tSlotEventTick(shipBodyId)
        end
    end
end
