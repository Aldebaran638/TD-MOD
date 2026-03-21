---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

-- 距离阈值：超过此距离切换为 distance 音效
local _soundDistanceThreshold = 150.0
-- distance 音效的虚拟播放距离：将播放点沿视线拉近至相机前方此距离处
local _soundVirtualNearDist = 40.0

-- 声音 Handle（由 client.shipSoundInit 加载）
local _snd_tachyon_fire_near = {}
local _snd_tachyon_fire_dist = {}
local _snd_tachyon_hit_near  = {}
local _snd_tachyon_hit_dist  = {}
local _snd_tachyon_windup_near = nil
local _snd_tachyon_windup_dist = nil
local _snd_engine_loop = nil

-- 根据事件发生位置与相机距离，决定实际播放点与使用 distance/near 音效
-- 返回: playPos(Vec), isDistant(bool)
local function _resolvePlayPos(eventPos)
    local camT = GetCameraTransform()
    local camPos = camT.pos
    local dist = VecLength(VecSub(eventPos, camPos))
    if dist > _soundDistanceThreshold then
        -- 将播放点拉向相机，保持方向但缩短距离，确保距离音效可被听见
        local dir = VecNormalize(VecSub(eventPos, camPos))
        local virtualPos = VecAdd(camPos, VecScale(dir, _soundVirtualNearDist))
        return virtualPos, true
    end
    return eventPos, false
end

-- 从列表中随机抽取一个音效 handle
local function _randomPick(tbl)
    return tbl[math.random(1, #tbl)]
end

-- 初始化：加载所有需要的声音文件
function client.shipSoundInit()
    -- 快子光矛 近距发射
    _snd_tachyon_fire_near[1] = LoadSound("MOD/sound/tachyon_lance_fire_01.ogg")
    _snd_tachyon_fire_near[2] = LoadSound("MOD/sound/tachyon_lance_fire_02.ogg")
    _snd_tachyon_fire_near[3] = LoadSound("MOD/sound/tachyon_lance_fire_03.ogg")

    -- 快子光矛 远距发射
    _snd_tachyon_fire_dist[1] = LoadSound("MOD/sound/distance_tachyon_lance_fire_01.ogg")
    _snd_tachyon_fire_dist[2] = LoadSound("MOD/sound/distance_tachyon_lance_fire_02.ogg")
    _snd_tachyon_fire_dist[3] = LoadSound("MOD/sound/distance_tachyon_lance_fire_03.ogg")

    -- 快子光矛 近距命中
    _snd_tachyon_hit_near[1] = LoadSound("MOD/sound/tachyon_lance_hit_01.ogg")
    _snd_tachyon_hit_near[2] = LoadSound("MOD/sound/tachyon_lance_hit_02.ogg")
    _snd_tachyon_hit_near[3] = LoadSound("MOD/sound/tachyon_lance_hit_03wav.ogg")

    -- 快子光矛 远距命中
    _snd_tachyon_hit_dist[1] = LoadSound("MOD/sound/distance_tachyon_lance_hit_01.ogg")
    _snd_tachyon_hit_dist[2] = LoadSound("MOD/sound/distance_tachyon_lance_hit_02.ogg")

    -- 快子光矛 充能音效
    _snd_tachyon_windup_near = LoadSound("MOD/sound/tachyon_lance_windup_01.ogg")
    _snd_tachyon_windup_dist = LoadSound("MOD/sound/distance_tachyon_lance_windup_01.ogg")

    -- 引擎循环音效
    _snd_engine_loop = LoadLoop("MOD/sound/engine.ogg")
end

-- == 内部播放函数 ==

local function _playTachyonWindup(firePoint)
    if firePoint == nil then return end
    local playPos, isDistant = _resolvePlayPos(firePoint)
    if isDistant then
        PlaySound(_snd_tachyon_windup_dist, playPos, 1.0)
    else
        PlaySound(_snd_tachyon_windup_near, playPos, 1.0)
    end
end

local function _playTachyonFire(firePoint)
    if firePoint == nil then return end
    local playPos, isDistant = _resolvePlayPos(firePoint)
    if isDistant then
        PlaySound(_randomPick(_snd_tachyon_fire_dist), playPos, 1.0)
    else
        PlaySound(_randomPick(_snd_tachyon_fire_near), playPos, 1.0)
    end
end

local function _playTachyonHit(hitPoint)
    if hitPoint == nil then return end
    local playPos, isDistant = _resolvePlayPos(hitPoint)
    if isDistant then
        PlaySound(_randomPick(_snd_tachyon_hit_dist), playPos, 1.0)
    else
        PlaySound(_randomPick(_snd_tachyon_hit_near), playPos, 1.0)
    end
end

-- == 内部 tick 函数 ==

local function _engineTick(shipBodyId)
    if shipBodyId == nil or shipBodyId == 0 then return end

    local veh = GetBodyVehicle(shipBodyId)
    if veh == nil or veh == 0 then return end

    local hasDriver = false
    local players = GetAllPlayers() or {}
    for i = 1, #players do
        if GetPlayerVehicle(players[i]) == veh then
            hasDriver = true
            break
        end
    end
    if not hasDriver then return end

    local t = GetBodyTransform(shipBodyId)
    PlayLoop(_snd_engine_loop, t.pos, 1.0)
end

-- 武器状态跃迁缓存（shipBodyId -> lastState）
local _lastXSlotState = {}

local function _xSlotSoundTick(shipBodyId)
    local shipData = client.ships and client.ships[shipBodyId]
    if shipData == nil then return end

    local xSlot = shipData.weapons.xSlot
    local prev = _lastXSlotState[shipBodyId] or "idle"
    local curr = xSlot.state or "idle"

    if prev ~= curr then
        if curr == "charging" then
            if xSlot.weaponType == "tachyonLance" then
                _playTachyonWindup(xSlot.firePoint)
            end
        elseif curr == "launching" then
            if xSlot.weaponType == "tachyonLance" then
                _playTachyonFire(xSlot.firePoint)
                if xSlot.didHit then
                    _playTachyonHit(xSlot.hitPoint)
                end
            end
        end
        _lastXSlotState[shipBodyId] = curr
    end
end

-- == 对外接口 ==

-- 对外唯一 tick 入口：封装所有音效逻辑
function client.shipSoundTick(shipBodyId)
    _xSlotSoundTick(shipBodyId)
    _engineTick(shipBodyId)
end
