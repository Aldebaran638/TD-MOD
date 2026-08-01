---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local _soundDistanceThreshold = 150.0
local _soundVirtualNearDist = 40.0
local _sndEngineLoop = nil
local _sndMissileLoop = nil
local _weaponSoundHandles = {}

client.soundModuleState = client.soundModuleState or {
    lastRenderSeqByShip = {},
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
    if handle ~= nil and handle ~= 0 then PlaySound(handle, position, 1.0) end
end

local function _isShipOccupied(shipBodyId)
    local vehicle = GetBodyVehicle(shipBodyId)
    return vehicle ~= nil and vehicle ~= 0 and GetPlayerVehicle() == vehicle
end

local function _shouldUseGenericShipSounds(shipBodyId)
    if client.registryShipGetShipType == nil then return true end
    return tostring(client.registryShipGetShipType(shipBodyId) or "") ~= "titan"
end

local function _engineTick(shipBodyId)
    if _sndEngineLoop == nil or _sndEngineLoop == 0
        or not _shouldUseGenericShipSounds(shipBodyId)
        or not _isShipOccupied(shipBodyId) then
        return
    end
    PlayLoop(_sndEngineLoop, GetBodyTransform(shipBodyId).pos, 1.0)
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
    if definition.family ~= "energy_lance" and definition.family ~= "arc_emitter" then return end
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

function client.soundModuleInit()
    _sndEngineLoop = LoadLoop("MOD/sound/dem_sfx_psi_ship_transport_ship_idle_01.ogg")
    _sndMissileLoop = LoadLoop("MOD/sound/missile_loop.ogg")
    _weaponSoundHandles = {}
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
        end
    end
end
