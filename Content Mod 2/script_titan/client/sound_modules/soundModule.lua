---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local _soundDistanceThreshold = 150.0
local _soundVirtualNearDist = 40.0
local _titanEngineVolume = 0.4
local _perditionWindupVolume = 1.0
local _perditionFireVolume = 1.0

local _snd_engine_loop = nil
local _snd_missile_loop = nil
local _snd_tachyon_fire_near = {}
local _snd_tachyon_fire_dist = {}
local _snd_tachyon_hit_near = {}
local _snd_tachyon_hit_dist = {}
local _snd_tachyon_windup_near = nil
local _snd_tachyon_windup_dist = nil
local _snd_perdition_fire_near = {}
local _snd_perdition_fire_dist = {}
local _snd_perdition_hit_near = {}
local _snd_perdition_hit_dist = {}
local _snd_perdition_windup_loops = {}
local _snd_titan_death = nil
local _snd_kinetic_fire_near = nil
local _snd_kinetic_fire_dist = nil
local _snd_kinetic_hit_near = {}
local _snd_kinetic_hit_dist = {}
local _snd_missile_fire_near = {}
local _snd_missile_fire_dist = {}
local _snd_missile_hit_near = {}
local _snd_missile_hit_dist = {}

client.soundModuleState = client.soundModuleState or {
    lastRenderSeqByShip = {},
    lastBodyHpByShip = {},
    deathPlayedByShip = {},
    perditionWindupPlayedByShip = {},
    perditionWindupActiveByShip = {},
}

local function _tableToVec(t)
    if t == nil then return Vec(0, 0, 0) end
    return Vec(t.x or 0, t.y or 0, t.z or 0)
end

local function _randomPick(tbl)
    if tbl == nil then return nil end
    local n = #tbl
    if n <= 0 then return nil end
    return tbl[math.random(1, n)]
end

local function _resolvePlayPos(eventPos)
    local camT = GetCameraTransform()
    local camPos = camT.pos
    local dist = VecLength(VecSub(eventPos, camPos))

    if dist > _soundDistanceThreshold then
        local dir = VecNormalize(VecSub(eventPos, camPos))
        local virtualPos = VecAdd(camPos, VecScale(dir, _soundVirtualNearDist))
        return virtualPos, true
    end

    return eventPos, false
end

local function _playAtVolume(handle, pos, volume)
    if handle == nil or handle == 0 then return end
    PlaySound(handle, pos, volume or 1.0)
end

local function _playAt(handle, pos)
    _playAtVolume(handle, pos, 1.0)
end

local function _playCollectionSingleOrRandom(collection, pos)
    if collection == nil then
        return
    end
    if type(collection) == "table" then
        _playAt(_randomPick(collection), pos)
        return
    end
    _playAt(collection, pos)
end

local function _playTachyonWindup(firePoint)
    local playPos, isDistant = _resolvePlayPos(firePoint)
    if isDistant then
        _playAt(_snd_tachyon_windup_dist, playPos)
    else
        _playAt(_snd_tachyon_windup_near, playPos)
    end
end

local function _playTachyonFire(firePoint)
    local playPos, isDistant = _resolvePlayPos(firePoint)
    if isDistant then
        _playAt(_randomPick(_snd_tachyon_fire_dist), playPos)
    else
        _playAt(_randomPick(_snd_tachyon_fire_near), playPos)
    end
end

local function _playTachyonHit(hitPoint)
    local playPos, isDistant = _resolvePlayPos(hitPoint)
    if isDistant then
        _playAt(_randomPick(_snd_tachyon_hit_dist), playPos)
    else
        _playAt(_randomPick(_snd_tachyon_hit_near), playPos)
    end
end

local function _playPerditionFire(firePoint)
    local playPos, isDistant = _resolvePlayPos(firePoint)
    if isDistant then
        _playAtVolume(_randomPick(_snd_perdition_fire_dist), playPos, _perditionFireVolume)
    else
        _playAtVolume(_randomPick(_snd_perdition_fire_near), playPos, _perditionFireVolume)
    end
end

local function _playPerditionHit(hitPoint)
    local playPos, isDistant = _resolvePlayPos(hitPoint)
    if isDistant then
        _playCollectionSingleOrRandom(_snd_perdition_hit_dist, playPos)
    else
        _playCollectionSingleOrRandom(_snd_perdition_hit_near, playPos)
    end
end

local function _playPerditionWindup(firePoint)
    local playPos, isDistant = _resolvePlayPos(firePoint)
    local windupSound = _randomPick(_snd_perdition_windup_loops)
    if windupSound ~= nil then
        _playAtVolume(windupSound, playPos, _perditionWindupVolume)
    end
end

local function _playKineticFire(firePoint)
    local playPos, isDistant = _resolvePlayPos(firePoint)
    if isDistant then
        _playAt(_snd_kinetic_fire_dist, playPos)
    else
        _playAt(_snd_kinetic_fire_near, playPos)
    end
end

local function _playKineticHit(hitPoint)
    local playPos, isDistant = _resolvePlayPos(hitPoint)
    if isDistant then
        _playAt(_randomPick(_snd_kinetic_hit_dist), playPos)
    else
        _playAt(_randomPick(_snd_kinetic_hit_near), playPos)
    end
end

local function _playMissileFire(firePoint)
    local playPos, isDistant = _resolvePlayPos(firePoint)
    if isDistant then
        _playAt(_randomPick(_snd_missile_fire_dist), playPos)
    else
        _playAt(_randomPick(_snd_missile_fire_near), playPos)
    end
end

local function _playMissileHit(hitPoint)
    local playPos, isDistant = _resolvePlayPos(hitPoint)
    if isDistant then
        _playAt(_randomPick(_snd_missile_hit_dist), playPos)
    else
        _playAt(_randomPick(_snd_missile_hit_near), playPos)
    end
end

local function _isShipOccupied(shipBodyId)
    local veh = GetBodyVehicle(shipBodyId)
    if veh ~= nil and veh ~= 0 then
        local playerVeh = GetPlayerVehicle()
        if playerVeh ~= nil and playerVeh ~= 0 and playerVeh == veh then
            return true
        end
    end

    return false
end

local function _engineTick(shipBodyId)
    if _snd_engine_loop == nil or _snd_engine_loop == 0 then
        return
    end

    if not _isShipOccupied(shipBodyId) then
        return
    end

    local t = GetBodyTransform(shipBodyId)
    PlayLoop(_snd_engine_loop, t.pos, _titanEngineVolume)
end

local function _isPerditionWindupPhase(phase)
    local p = tostring(phase or "")
    return p == "charging" or p == "charged"
end

local function _perditionWindupLoopTick(shipBodyId)
    if #_snd_perdition_windup_loops <= 0 then
        return
    end

    local state = client.soundModuleState
    local hudByShip = client.tSlotHudStateByShip
    if hudByShip == nil then
        return
    end

    local hud = hudByShip[math.floor(shipBodyId or 0)]
    if hud == nil then
        return
    end

    local isCharging = _isPerditionWindupPhase(hud.phase1) or _isPerditionWindupPhase(hud.phase2)
    local wasCharging = state.perditionWindupActiveByShip[shipBodyId] and true or false

    if not isCharging then
        state.perditionWindupActiveByShip[shipBodyId] = false
        state.perditionWindupPlayedByShip[shipBodyId] = false
        return
    end

    if not wasCharging or not state.perditionWindupPlayedByShip[shipBodyId] then
        local render = client.tSlotRenderGetEvent ~= nil and client.tSlotRenderGetEvent(shipBodyId) or nil
        local firePoint = nil
        if render ~= nil and tostring(render.weaponType or "") == "perditionBeam" then
            firePoint = _tableToVec(render.firePoint)
        else
            local t = GetBodyTransform(shipBodyId)
            firePoint = t.pos
        end
        
        _playPerditionWindup(firePoint)
        state.perditionWindupPlayedByShip[shipBodyId] = true
    end
    state.perditionWindupActiveByShip[shipBodyId] = true
end

local function _tSlotEventTick(shipBodyId)
    local state = client.soundModuleState
    local render = client.tSlotRenderGetEvent(shipBodyId)
    if render == nil then
        return
    end

    local seq = render.seq or -1
    local lastSeq = state.lastRenderSeqByShip[shipBodyId] or -1
    if seq == lastSeq then
        return
    end

    state.lastRenderSeqByShip[shipBodyId] = seq

    local weaponType = tostring(render.weaponType or "")
    if weaponType ~= "tachyonLance" and weaponType ~= "perditionBeam" then
        return
    end

    local eventType = render.eventType or ""
    if eventType == "charging_start" then
        if weaponType ~= "perditionBeam" then
            _playTachyonWindup(_tableToVec(render.firePoint))
        end
    elseif eventType == "launch_start" then
        if weaponType == "perditionBeam" then
            _playPerditionFire(_tableToVec(render.firePoint))
        else
            _playTachyonFire(_tableToVec(render.firePoint))
        end
        if (render.didHit or 0) == 1 then
            if weaponType == "perditionBeam" then
                _playPerditionHit(_tableToVec(render.hitPoint))
            else
                _playTachyonHit(_tableToVec(render.hitPoint))
            end
        end
    end
end

local function _titanDeathTick(shipBodyId)
    if _snd_titan_death == nil or _snd_titan_death == 0 then
        return
    end
    if client.registryShipGetHP == nil then
        return
    end

    local state = client.soundModuleState
    local _, _, bodyHP = client.registryShipGetHP(shipBodyId)
    if bodyHP == nil then
        return
    end

    local current = tonumber(bodyHP) or 0.0
    local previous = state.lastBodyHpByShip[shipBodyId]

    if current > 0.0 then
        state.deathPlayedByShip[shipBodyId] = false
    elseif previous ~= nil and previous > 0.0 and (not state.deathPlayedByShip[shipBodyId]) then
        _playAt(_snd_titan_death, GetCameraTransform().pos)
        state.deathPlayedByShip[shipBodyId] = true
    end

    state.lastBodyHpByShip[shipBodyId] = current
end

function client.soundModuleInit()
    _snd_engine_loop = LoadLoop("MOD/sound/fallen_machine_empire_titan_idle_01.ogg")
    _snd_missile_loop = LoadLoop("MOD/sound/missile_loop.ogg")

    _snd_tachyon_fire_near[1] = LoadSound("MOD/sound/tachyon_lance_fire_01.ogg")
    _snd_tachyon_fire_near[2] = LoadSound("MOD/sound/tachyon_lance_fire_02.ogg")
    _snd_tachyon_fire_near[3] = LoadSound("MOD/sound/tachyon_lance_fire_03.ogg")

    _snd_tachyon_fire_dist[1] = LoadSound("MOD/sound/distance_tachyon_lance_fire_01.ogg")
    _snd_tachyon_fire_dist[2] = LoadSound("MOD/sound/distance_tachyon_lance_fire_02.ogg")
    _snd_tachyon_fire_dist[3] = LoadSound("MOD/sound/distance_tachyon_lance_fire_03.ogg")

    _snd_tachyon_hit_near[1] = LoadSound("MOD/sound/tachyon_lance_hit_01.ogg")
    _snd_tachyon_hit_near[2] = LoadSound("MOD/sound/tachyon_lance_hit_02.ogg")
    _snd_tachyon_hit_near[3] = LoadSound("MOD/sound/tachyon_lance_hit_03.ogg")

    _snd_tachyon_hit_dist[1] = LoadSound("MOD/sound/distance_tachyon_lance_hit_01.ogg")
    _snd_tachyon_hit_dist[2] = LoadSound("MOD/sound/distance_tachyon_lance_hit_02.ogg")

    _snd_tachyon_windup_near = LoadSound("MOD/sound/tachyon_lance_windup_01.ogg")
    _snd_tachyon_windup_dist = LoadSound("MOD/sound/distance_tachyon_lance_windup_01.ogg")
    _snd_perdition_fire_near[1] = LoadSound("MOD/sound/perdition_beam_fire_01.ogg")
    _snd_perdition_fire_near[2] = LoadSound("MOD/sound/perdition_beam_fire_03.ogg")
    _snd_perdition_fire_near[3] = LoadSound("MOD/sound/titan_laser_fire_01.ogg")
    _snd_perdition_fire_dist[1] = LoadSound("MOD/sound/distance_perdition_beam_fire_01.ogg")
    _snd_perdition_fire_dist[2] = LoadSound("MOD/sound/distance_perdition_beam_fire_02.ogg")
    _snd_perdition_fire_dist[3] = LoadSound("MOD/sound/distance_perdition_beam_fire_03.ogg")
    _snd_perdition_hit_near[1] = LoadSound("MOD/sound/perdition_beam_hit_01.ogg")
    _snd_perdition_hit_dist[1] = LoadSound("MOD/sound/distance_perdition_beam_hit_01.ogg")
    _snd_perdition_windup_loops[1] = LoadSound("MOD/sound/perdition_beam_windup_02.ogg")
    _snd_perdition_windup_loops[2] = LoadSound("MOD/sound/titan_laser_windup_02.ogg")
    _snd_titan_death = LoadSound("MOD/sound/fallen_machine_empire_titan_death_01.ogg")
    _snd_kinetic_fire_near = LoadSound("MOD/sound/kinectic_artillery_fire_01.ogg")
    _snd_kinetic_fire_dist = LoadSound("MOD/sound/distance_kinectic_artillery_fire_01.ogg")
    _snd_kinetic_hit_near[1] = LoadSound("MOD/sound/kinectic_artillery_hit_01.ogg")
    _snd_kinetic_hit_near[2] = LoadSound("MOD/sound/kinectic_artillery_hit_02.ogg")
    _snd_kinetic_hit_near[3] = LoadSound("MOD/sound/kinectic_artillery_hit_03.ogg")
    _snd_kinetic_hit_dist[1] = LoadSound("MOD/sound/distance_kinectic_artillery_hit_01.ogg")
    _snd_kinetic_hit_dist[2] = LoadSound("MOD/sound/distance_kinectic_artillery_hit_02.ogg")
    _snd_missile_fire_near[1] = LoadSound("MOD/sound/missile_fire_01.ogg")
    _snd_missile_fire_near[2] = LoadSound("MOD/sound/missile_fire_02.ogg")
    _snd_missile_fire_dist[1] = LoadSound("MOD/sound/distance_missile_fire_01.ogg")
    _snd_missile_fire_dist[2] = LoadSound("MOD/sound/distance_missile_fire_02.ogg")
    _snd_missile_fire_dist[3] = LoadSound("MOD/sound/distance_missile_fire_03.ogg")
    _snd_missile_hit_near[1] = LoadSound("MOD/sound/missile_hit_01.ogg")
    _snd_missile_hit_near[2] = LoadSound("MOD/sound/missile_hit_02.ogg")
    _snd_missile_hit_near[3] = LoadSound("MOD/sound/missile_hit_03.ogg")
    _snd_missile_hit_dist[1] = LoadSound("MOD/sound/distance_missile_hit_01.ogg")
    _snd_missile_hit_dist[2] = LoadSound("MOD/sound/distance_missile_hit_02.ogg")
end

function client.playKineticArtilleryFireSound(x, y, z)
    _playKineticFire(Vec(x or 0, y or 0, z or 0))
end

function client.playKineticArtilleryHitSound(x, y, z)
    _playKineticHit(Vec(x or 0, y or 0, z or 0))
end

function client.playMissileFireSound(x, y, z)
    _playMissileFire(Vec(x or 0, y or 0, z or 0))
end

function client.playMissileImpactSound(x, y, z)
    _playMissileHit(Vec(x or 0, y or 0, z or 0))
end

function client.playMissileLoopSound(x, y, z)
    if _snd_missile_loop == nil or _snd_missile_loop == 0 then
        return
    end
    PlayLoop(_snd_missile_loop, Vec(x or 0, y or 0, z or 0), 1.0)
end

function client.soundModuleTick(dt)
    local _ = dt
    if client.registryShipGetRegisteredBodyIds == nil then
        return
    end

    local shipIds = client.registryShipGetRegisteredBodyIds()
    for i = 1, #shipIds do
        local shipBodyId = shipIds[i]
        if client.registryShipExists(shipBodyId) then
            _engineTick(shipBodyId)
            _perditionWindupLoopTick(shipBodyId)
            _tSlotEventTick(shipBodyId)
        end
    end

    local controlledTitanBody = client.shipBody or 0
    if controlledTitanBody ~= 0 and client.registryShipExists(controlledTitanBody) then
        _titanDeathTick(controlledTitanBody)
    end
end
