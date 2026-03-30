---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local _soundDistanceThreshold = 150.0
local _soundVirtualNearDist = 40.0

local _snd_engine_loop = nil
local _snd_gamma_fire = {}
local _snd_gamma_hit = {}
local _snd_p_fire = {}
local _snd_p_hit = nil
local _snd_g_fire = {}
local _snd_g_hit = {}
local _snd_missile_loop = nil

client.soundModuleState = client.soundModuleState or {
    lastEscortSRenderSeqByShip = {},
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
        return VecAdd(camPos, VecScale(dir, _soundVirtualNearDist))
    end
    return eventPos
end

local function _playAt(handle, pos, volume)
    if handle == nil or handle == 0 then
        return
    end
    PlaySound(handle, pos, volume or 1.0)
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

function client.soundModuleInit()
    _snd_engine_loop = LoadLoop("MOD/sound/dem_sfx_psi_ship_transport_ship_idle_01.ogg")
    _snd_gamma_fire[1] = LoadSound("MOD/sound/laser_fire_01.ogg")
    _snd_gamma_fire[2] = LoadSound("MOD/sound/laser_fire_02.ogg")
    _snd_gamma_fire[3] = LoadSound("MOD/sound/laser_fire_03.ogg")
    _snd_gamma_hit[1] = LoadSound("MOD/sound/laser_hit_01.ogg")
    _snd_p_fire[1] = LoadSound("MOD/sound/flak_weapon_fire_01.ogg")
    _snd_p_fire[2] = LoadSound("MOD/sound/flak_weapon_fire_02.ogg")
    _snd_p_fire[3] = LoadSound("MOD/sound/flak_weapon_fire_03.ogg")
    _snd_p_fire[4] = LoadSound("MOD/sound/flak_weapon_fire_04.ogg")
    _snd_p_hit = LoadSound("MOD/sound/kinectic_artillery_hit_01.ogg")
    _snd_g_fire[1] = LoadSound("MOD/sound/swarmer_missile_fire_01.ogg")
    _snd_g_fire[2] = LoadSound("MOD/sound/swarmer_missile_fire_02.ogg")
    _snd_g_fire[3] = LoadSound("MOD/sound/swarmer_missile_fire_03.ogg")
    _snd_g_hit[1] = LoadSound("MOD/sound/distance_missile_fire_01.ogg")
    _snd_g_hit[2] = LoadSound("MOD/sound/distance_missile_fire_02.ogg")
    _snd_missile_loop = LoadLoop("MOD/sound/missile_loop.ogg")
end

function client.playEscortPFireSound(x, y, z)
    _playAt(_randomPick(_snd_p_fire), _resolvePlayPos(Vec(x or 0, y or 0, z or 0)), 1.0)
end

function client.playEscortPHitSound(x, y, z)
    _playAt(_snd_p_hit, _resolvePlayPos(Vec(x or 0, y or 0, z or 0)), 1.0)
end

function client.playEscortGFireSound(x, y, z)
    _playAt(_randomPick(_snd_g_fire), _resolvePlayPos(Vec(x or 0, y or 0, z or 0)), 0.2)
end

function client.playEscortGHitSound(x, y, z)
    _playAt(_randomPick(_snd_g_hit), _resolvePlayPos(Vec(x or 0, y or 0, z or 0)), 1.0)
end

function client.playMissileLoopSound(x, y, z)
    if _snd_missile_loop == nil or _snd_missile_loop == 0 then
        return
    end
    PlayLoop(_snd_missile_loop, _resolvePlayPos(Vec(x or 0, y or 0, z or 0)), 1.0)
end

function client.soundModuleTick(dt)
    local _ = dt
    local shipBody = client.shipBody or 0
    if shipBody ~= 0 and _snd_engine_loop ~= nil and _snd_engine_loop ~= 0 and _isShipOccupied(shipBody) then
        local t = GetBodyTransform(shipBody)
        PlayLoop(_snd_engine_loop, t.pos, 1.0)
    end

    local state = client.soundModuleState
    local shipIds = client.registryShipGetRegisteredBodyIds()
    for i = 1, #shipIds do
        local shipBodyId = shipIds[i]
        local render = client.escortSSlotRenderGetEvent ~= nil and client.escortSSlotRenderGetEvent(shipBodyId) or nil
        if render ~= nil then
            local seq = render.seq or -1
            local lastSeq = state.lastEscortSRenderSeqByShip[shipBodyId] or -1
            if seq ~= lastSeq and render.eventType == "launch_start" then
                _playAt(_randomPick(_snd_gamma_fire), _resolvePlayPos(_tableToVec(render.firePoint)), 1.0)
                if render.didHit == 1 then
                    _playAt(_randomPick(_snd_gamma_hit), _resolvePlayPos(_tableToVec(render.hitPoint)), 1.0)
                end
            end
            state.lastEscortSRenderSeqByShip[shipBodyId] = seq
        end
    end
end
