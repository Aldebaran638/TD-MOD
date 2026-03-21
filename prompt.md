1. 
将现有的DebugWatch都删掉先.
现在我要完成飞船的运动(不包括旋转)系统(包括持续给飞船施加反重力,给飞船施加向前/向后的力;给飞船施加阻尼力.)我印象中之前已经完成了客户端的输入模块,就是bodyMoveInput模块.但是现在飞船运动逻辑有bug(就是点击ws没反应,飞船也没有悬浮).极有可能是因为你在这些模块的函数中写了::continue::,而这个东西在teardown脚本中是不被允许的.当然还是可能有别的问题.说说你觉得最可能是因为什么

2. 现在编写一个新的客户端模块:摄像机模块.这个模块属于Global Mod,而且也属于一类新的模块
现在我要从teardown引擎中接管摄像机.以下是参考的摄像机代码(这是我以前写单人模组的时候,编写的摄像机模组.):
```lua
------------------------------------------------
-- fallenEmpireCruiser_camera 模块 开始
------------------------------------------------

local fallenEmpireCruiser_camera_atFront = false

-- 前置相机位置（飞船本地坐标）
local fallenEmpireCruiser_camera_frontLocalOffset = Vec(0, 0, -4)

local fallenEmpireCruiser_camera_radiusBack = 18
local fallenEmpireCruiser_camera_radiusMin = 4
local fallenEmpireCruiser_camera_radiusMax = 40
local fallenEmpireCruiser_camera_zoomSpeed = 5

local fallenEmpireCruiser_camera_yaw = 0
local fallenEmpireCruiser_camera_pitch = -2
local fallenEmpireCruiser_camera_targetYaw = 0
local fallenEmpireCruiser_camera_targetPitch = -20

local fallenEmpireCruiser_camera_rotateSensitivity = 0.12
local fallenEmpireCruiser_camera_lerpSpeed = 6

-- 缓存上一帧的相机 Transform：避免在某些情况下 draw 阶段回落到游戏默认摄像机
local fallenEmpireCruiser_camera_lastActive = false
local fallenEmpireCruiser_camera_lastTransform = nil

-- 从 tick 缓存“当前驾驶的飞船 body”，供 draw 阶段每帧计算相机用
local fallenEmpireCruiser_camera_cachedIsDriving = false
local fallenEmpireCruiser_camera_cachedBody = 0
local fallenEmpireCruiser_camera_cachedDt = 0

local function fallenEmpireCruiser_camera_yawPitchFromDir(dir)
    dir = VecNormalize(dir)
    local yawRaw = math.deg(math.atan2(-dir[3], dir[1]))
    local yaw = fallenEmpireCruiser_camera_normalizeAngleDeg(yawRaw - 90.0)
    local horiz = math.sqrt(dir[1] * dir[1] + dir[3] * dir[3])
    local pitch = math.deg(math.atan2(dir[2], horiz))
    pitch = fallenEmpireCruiser_camera_clamp(pitch, -80, 80)
    return yaw, pitch
end

local function fallenEmpireCruiser_camera_dirFromYawPitch(yawDeg, pitchDeg)
    local yaw = math.rad(yawDeg)
    local pitch = math.rad(pitchDeg)
    local cp = math.cos(pitch)
    local sp = math.sin(pitch)
    -- yaw=0 面向 -Z
    return Vec(cp * math.sin(yaw), sp, -cp * math.cos(yaw))
end

-- 右键：短按切前/后视；长按（仅后视）自由观察
local fallenEmpireCruiser_camera_rmbDown = false
local fallenEmpireCruiser_camera_rmbHoldTime = 0
local fallenEmpireCruiser_camera_freeLookActive = false
local fallenEmpireCruiser_camera_longPressThreshold = 0.25

-- 切到前置相机后，下一帧用飞船朝向初始化相机 yaw/pitch（避免跳变）
local fallenEmpireCruiser_camera_pendingInitToShipForward = false

function fallenEmpireCruiser_camera_isLongPressActive()
    return fallenEmpireCruiser_camera_rmbDown and (fallenEmpireCruiser_camera_rmbHoldTime >= fallenEmpireCruiser_camera_longPressThreshold)
end

local function fallenEmpireCruiser_camera_clamp(x, a, b)
    if x < a then return a end
    if x > b then return b end
    return x
end

local function fallenEmpireCruiser_camera_normalizeAngleDeg(a)
    a = a % 360
    if a > 180 then a = a - 360 end
    if a < -180 then a = a + 360 end
    return a
end

local function fallenEmpireCruiser_camera_shortestAngleDiff(from, to)
    local d = fallenEmpireCruiser_camera_normalizeAngleDeg(to - from)
    return d
end

local function fallenEmpireCruiser_camera_handleRmb(dt)
    -- 按下立刻切换前/后视，并在切入时立即用飞船朝向初始化 yaw/pitch/targets
    if InputPressed("rmb") then
        fallenEmpireCruiser_camera_rmbDown = true
        fallenEmpireCruiser_camera_rmbHoldTime = 0

        if fallenEmpireCruiser_camera_atFront then
            -- 已在前视，按下就切回后视
            fallenEmpireCruiser_camera_atFront = false
            fallenEmpireCruiser_camera_freeLookActive = false
        else
            -- 立刻切到前视，并立即用当前飞船朝向初始化相机方向（避免帧跳变）
            fallenEmpireCruiser_camera_atFront = true
            fallenEmpireCruiser_camera_freeLookActive = false

            local body = fallenEmpireCruiser_camera_cachedBody
            if body and body ~= 0 then
                local shipT = GetBodyTransform(body)
                local shipForward = VecNormalize(TransformToParentVec(shipT, Vec(0, 0, -1)))
                local yaw, pitch = fallenEmpireCruiser_camera_yawPitchFromDir(shipForward)
                fallenEmpireCruiser_camera_yaw = yaw
                fallenEmpireCruiser_camera_pitch = pitch
                fallenEmpireCruiser_camera_targetYaw = yaw
                fallenEmpireCruiser_camera_targetPitch = pitch
            end
        end
    end

    -- 处理长按进入 free-look（保持你原有的长按语义）
    if fallenEmpireCruiser_camera_rmbDown then
        fallenEmpireCruiser_camera_rmbHoldTime = fallenEmpireCruiser_camera_rmbHoldTime + (dt or 0)
        if (not fallenEmpireCruiser_camera_atFront)
            and (fallenEmpireCruiser_camera_rmbHoldTime >= fallenEmpireCruiser_camera_longPressThreshold)
            and (not fallenEmpireCruiser_camera_freeLookActive) then
            fallenEmpireCruiser_camera_freeLookActive = true
        end
    end

    -- 释放时结束按下/长按状态
    if InputReleased("rmb") then
        fallenEmpireCruiser_camera_rmbDown = false
        fallenEmpireCruiser_camera_rmbHoldTime = 0
        if fallenEmpireCruiser_camera_freeLookActive then
            fallenEmpireCruiser_camera_freeLookActive = false
        end
    end
end

local function fallenEmpireCruiser_camera_update(isDriving, body, dt)
    if not isDriving or not body or body == 0 then
        fallenEmpireCruiser_camera_lastActive = false
        fallenEmpireCruiser_camera_lastTransform = nil
        return
    end

    local shipT = GetBodyTransform(body)

    fallenEmpireCruiser_camera_handleRmb(dt)

    local didInitToShipForward = false

    -- 切到前置相机的同一帧就初始化朝向，避免出现一帧跳变
    if fallenEmpireCruiser_camera_atFront and fallenEmpireCruiser_camera_pendingInitToShipForward then
        local shipForward = VecNormalize(TransformToParentVec(shipT, Vec(0, 0, -1)))
        local yaw, pitch = fallenEmpireCruiser_camera_yawPitchFromDir(shipForward)
        fallenEmpireCruiser_camera_yaw = -yaw
        fallenEmpireCruiser_camera_pitch = -pitch
        fallenEmpireCruiser_camera_targetYaw = -yaw
        fallenEmpireCruiser_camera_targetPitch = -pitch
        fallenEmpireCruiser_camera_pendingInitToShipForward = false
        didInitToShipForward = true
    end

    local mx = InputValue("mousedx") or 0
    local my = InputValue("mousedy") or 0
    local wheel = InputValue("mousewheel") or 0

    local camPos
    local camRot

    if fallenEmpireCruiser_camera_atFront then
        -- 前置相机：短按右键切入时，立即对齐“飞船朝向”；位置固定在飞船本地 (0,0,-4)
        camPos = TransformToParentPoint(shipT, fallenEmpireCruiser_camera_frontLocalOffset)
        local sens = fallenEmpireCruiser_camera_rotateSensitivity

        -- 切换到前置相机的这一帧：忽略鼠标微抖，确保“方向一定是飞船朝向方向”
        if not didInitToShipForward then
            -- 前置相机转动逻辑与后置一致
            fallenEmpireCruiser_camera_targetYaw = fallenEmpireCruiser_camera_normalizeAngleDeg(fallenEmpireCruiser_camera_targetYaw + mx * sens)
            fallenEmpireCruiser_camera_targetPitch = fallenEmpireCruiser_camera_clamp(fallenEmpireCruiser_camera_targetPitch - my * sens, -80, 80)
        end

        local k = math.min(1.0, fallenEmpireCruiser_camera_lerpSpeed * (dt or 0))
        local yawDelta = fallenEmpireCruiser_camera_shortestAngleDiff(fallenEmpireCruiser_camera_yaw, fallenEmpireCruiser_camera_targetYaw)
        fallenEmpireCruiser_camera_yaw = fallenEmpireCruiser_camera_normalizeAngleDeg(fallenEmpireCruiser_camera_yaw + yawDelta * k)
        fallenEmpireCruiser_camera_pitch = fallenEmpireCruiser_camera_pitch + (fallenEmpireCruiser_camera_targetPitch - fallenEmpireCruiser_camera_pitch) * k
        fallenEmpireCruiser_camera_pitch = fallenEmpireCruiser_camera_clamp(fallenEmpireCruiser_camera_pitch, -80, 80)

        local fwd = fallenEmpireCruiser_camera_dirFromYawPitch(fallenEmpireCruiser_camera_yaw, fallenEmpireCruiser_camera_pitch)
        local outTarget = VecAdd(camPos, fwd)
        camRot = QuatLookAt(camPos, outTarget)
    else
        if wheel ~= 0 then
            fallenEmpireCruiser_camera_radiusBack = fallenEmpireCruiser_camera_clamp(
                fallenEmpireCruiser_camera_radiusBack - wheel * fallenEmpireCruiser_camera_zoomSpeed,
                fallenEmpireCruiser_camera_radiusMin,
                fallenEmpireCruiser_camera_radiusMax
            )
        end

        -- 简化：后视相机的角度由鼠标直接控制（自由观察时更灵敏/不回正）
        local sens = fallenEmpireCruiser_camera_rotateSensitivity
        if fallenEmpireCruiser_camera_freeLookActive then
            sens = sens * 1.0
        end

        fallenEmpireCruiser_camera_targetYaw = fallenEmpireCruiser_camera_normalizeAngleDeg(fallenEmpireCruiser_camera_targetYaw - mx * sens)
        fallenEmpireCruiser_camera_targetPitch = fallenEmpireCruiser_camera_clamp(fallenEmpireCruiser_camera_targetPitch - my * sens, -80, 80)

        -- 轻微平滑（避免突然抖动）
        local k = math.min(1.0, fallenEmpireCruiser_camera_lerpSpeed * (dt or 0))
        local yawDelta = fallenEmpireCruiser_camera_shortestAngleDiff(fallenEmpireCruiser_camera_yaw, fallenEmpireCruiser_camera_targetYaw)
        fallenEmpireCruiser_camera_yaw = fallenEmpireCruiser_camera_normalizeAngleDeg(fallenEmpireCruiser_camera_yaw + yawDelta * k)
        fallenEmpireCruiser_camera_pitch = fallenEmpireCruiser_camera_pitch + (fallenEmpireCruiser_camera_targetPitch - fallenEmpireCruiser_camera_pitch) * k
        fallenEmpireCruiser_camera_pitch = fallenEmpireCruiser_camera_clamp(fallenEmpireCruiser_camera_pitch, -80, 80)

        local baseOffset = Vec(0, 0, fallenEmpireCruiser_camera_radiusBack)
        local orbitRot = QuatEuler(fallenEmpireCruiser_camera_pitch, fallenEmpireCruiser_camera_yaw, 0)
        local offsetWorld = QuatRotateVec(orbitRot, baseOffset)
        camPos = VecAdd(shipT.pos, offsetWorld)
        camRot = QuatLookAt(camPos, shipT.pos)
    end

    AttachCameraTo(0)
    local camT = Transform(camPos, camRot)
    fallenEmpireCruiser_camera_lastActive = true
    fallenEmpireCruiser_camera_lastTransform = camT
    SetCameraTransform(camT)
end

function fallenEmpireCruiser_camera_client_tick(dt)
    local isDriving, _, body = fallenEmpireCruiser_localShip_get()

    fallenEmpireCruiser_camera_cachedIsDriving = isDriving
    fallenEmpireCruiser_camera_cachedBody = body or 0
    fallenEmpireCruiser_camera_cachedDt = dt or 0

    -- tick 阶段设置一次相机：Teardown 的主视角通常以 tick 为准
    fallenEmpireCruiser_camera_update(isDriving, body, dt)
end

function fallenEmpireCruiser_camera_client_draw()
    -- draw 阶段再补一次：防止引擎/其他 UI 绘制阶段覆写相机
    if not fallenEmpireCruiser_camera_lastActive then
        return
    end
    if not fallenEmpireCruiser_camera_lastTransform then
        return
    end
    AttachCameraTo(0)
    SetCameraTransform(fallenEmpireCruiser_camera_lastTransform)
end

------------------------------------------------
-- fallenEmpireCruiser_camera 模块 结束
------------------------------------------------
```
先说说你看到了什么?这个摄像机的思路是什么?包括哪些功能?


3. 现在编写一个新的模块,即旋转模块.该模块属于CM2模组的新的运动模块.
模块功能:每帧对飞船施加旋转力,使得飞船的正前方与摄像机正前方方向一致.飞船正前方与摄像机正前方的方向角度越小,施加的力越小.

我目前的思路就是摄像机模块每帧持续给服务器请求发送yaw pitch，然后服务器根据这俩数据持续给指定的飞船添加扭矩。

说说你对这个模块的思路?如果涉及到需要新建registry键值，需要明确说出来你打算添加哪些键值


4. 现在新增摄像机模块：显示血条。
在摄像机底下画一个血条。血条只有一条，分三大段，分别代表船体值/装甲值和护盾值。
在血条里面画小分界线给血条分格，每一格代表1000血.扣血的时候血条需要丝滑减短而不是突然变短

5. 新增摄像机模块：绘制准星
```lua
------------------------------------------------
-- fallenEmpireCruiser_crosshair 模块 开始
------------------------------------------------

local fallenEmpireCruiser_crosshair_distance = 200
local fallenEmpireCruiser_crosshair_size = 8

function fallenEmpireCruiser_crosshair_client_draw()
    local isDriving, _, body = fallenEmpireCruiser_localShip_get()
    if not isDriving or not body or body == 0 then
        return
    end

    local t = GetBodyTransform(body)

    -- 准星逻辑（按 test4.lua 原版）：始终沿飞船本体正前方（本地 -Z）投射
    local forwardLocal = Vec(0, 0, -1)
    local rayOrigin = TransformToParentPoint(t, VecScale(forwardLocal, 2))
    local forwardWorldDir = TransformToParentVec(t, forwardLocal)
    forwardWorldDir = VecNormalize(forwardWorldDir)

    local hit, hitDist = QueryRaycast(rayOrigin, forwardWorldDir, fallenEmpireCruiser_crosshair_distance)
    local forwardWorldPoint
    if hit then
        forwardWorldPoint = VecAdd(rayOrigin, VecScale(forwardWorldDir, hitDist))
    else
        forwardWorldPoint = TransformToParentPoint(t, VecScale(forwardLocal, fallenEmpireCruiser_crosshair_distance))
    end

    -- 只在“摄像机前方”时才画十字，避免在身后也出现
    local camT = GetCameraTransform()
    local camForward = TransformToParentVec(camT, Vec(0, 0, -1))
    camForward = VecNormalize(camForward)
    local dirToPoint = VecNormalize(VecSub(forwardWorldPoint, camT.pos))
    local dot = VecDot(camForward, dirToPoint)
    if dot <= 0 then
        return
    end

    local sx, sy = UiWorldToPixel(forwardWorldPoint)
    if not sx or not sy then
        return
    end

    UiPush()
        UiAlign("center middle")
        UiTranslate(sx, sy)
        UiColor(1, 1, 1, 1)
        local s = fallenEmpireCruiser_crosshair_size
        local th = 1
        UiRect(s * 2, th)
        UiRect(th, s * 2)
    UiPop()
end

------------------------------------------------
-- fallenEmpireCruiser_crosshair 模块 结束
------------------------------------------------
```
先说说你看到了什么?这个摄像机的思路是什么?包括哪些功能?

6. 新增模块:声音播放模块

声音文件全部在CM2文件夹下的sound文件夹下.先说说你看到了哪些类型的声音文件,可能需要添加哪几类声音

音效目前不需要实装missile的音效和kinectic_artillery_fire音效,只需要实装快子光矛音效,引擎音效和推进音效(move.ogg)

快子光矛音效发射分为远近两种.近距离的不用说,客户端随机挑一个在发射点播放即可;当客户端所在位置和飞船所在位置太远,就在发射点播放distance的音乐.但是注意,播放distance音乐,客户端可能因为距离太远本身就听不到.这个时候就需要调整.给出你的调整方案(我的方案是把播放点相对于客户端拉近一点,确保客户端听得到).快子光矛命中音效逻辑一样,只是要在命中点播放.

引擎音效:只要飞船上有人(不论是不是当前玩家),就在飞船位置循环播放引擎音效

说说你打算怎么搞?

这种模块要写在客户端中,作为一类新的客户端模块,即音效播放模块

7. 新增模块
众所周知,一个飞船在三维空间随便乱转,可能导致飞船飞船在摄像机中的视角不是"正"的,可能歪过来(比如在xy平面向左旋转了45度那种).这个问题你觉得如何解决呢?

当然前提是你需要先向我确认你是知道我在说什么的.


8. 忘掉之前所有内容,重新阅读代码

 现在编写一个新的模块,即旋转模块.该模块属于CM2模组的新的运动模块.
模块功能:每帧对飞船施加旋转力,使得飞船的正前方与摄像机正前方方向一致.飞船正前方与摄像机正前方的方向角度越小,施加的力越小.

我目前的思路就是摄像机模块每帧持续给服务器请求发送yaw pitch，然后服务器根据这俩数据持续给指定的飞船添加扭矩。

说说你对这个模块的思路?如果涉及到需要新建registry键值，需要明确说出来你打算添加哪些键值
我再给你一个参考代码,是我以前单机模组的旋转模块.这个模块不会出现天旋地转的感觉.你看看你的思路和我发的代码的思路哪个更好
------------------------------------------------
-- fallenEmpireCruiser_attitudeControl 模块 开始
------------------------------------------------

-- 客户端：不在长按右键时，上报当前摄像机朝向（前/后相机都适用）
-- 服务端：根据上报的朝向，平滑转向并自动回正（参考 test4.lua 的实现风格）

local fallenEmpireCruiser_attitudeControl_clientTime = 0
local fallenEmpireCruiser_attitudeControl_clientLastSendTime = -999
local fallenEmpireCruiser_attitudeControl_clientSendInterval = 0.05

local fallenEmpireCruiser_attitudeControl_inputTimeout = 0.25

local fallenEmpireCruiser_attitudeControl_maxPitch = 80
local fallenEmpireCruiser_attitudeControl_maxYawOffset = 120

local fallenEmpireCruiser_attitudeControl_kP_yaw = 2.0
local fallenEmpireCruiser_attitudeControl_kP_pitch = 2.0
local fallenEmpireCruiser_attitudeControl_maxYawSpeed = 90.0
local fallenEmpireCruiser_attitudeControl_maxPitchSpeed = 60.0

-- 服务端状态（vehicleId -> st）
-- st = { driverId=number, body=handle, t=number, aimYaw=number, aimPitch=number }
local fallenEmpireCruiser_attitudeControl_serverVehicleStates = {}

local function fallenEmpireCruiser_attitudeControl_clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function fallenEmpireCruiser_attitudeControl_normalizeAngleDeg(a)
    return (a + 180) % 360 - 180
end

local function fallenEmpireCruiser_attitudeControl_shortestAngleDiff(a, b)
    local d = (b - a + 180) % 360 - 180
    return d
end

local function fallenEmpireCruiser_attitudeControl_getShipYaw(t)
    local forward = TransformToParentVec(t, Vec(0, 0, -1))
    forward = VecNormalize(forward)
    local yawRaw = math.deg(math.atan2(-forward[3], forward[1]))
    return fallenEmpireCruiser_attitudeControl_normalizeAngleDeg(yawRaw - 90.0)
end

local function fallenEmpireCruiser_attitudeControl_getShipPitch(t)
    local forward = TransformToParentVec(t, Vec(0, 0, -1))
    forward = VecNormalize(forward)
    local horiz = math.sqrt(forward[1] * forward[1] + forward[3] * forward[3])
    local pitch = math.deg(math.atan2(forward[2], horiz))
    return pitch
end

local function fallenEmpireCruiser_attitudeControl_dirToYawPitch(dir)
    dir = VecNormalize(dir)
    local yawRaw = math.deg(math.atan2(-dir[3], dir[1]))
    local yaw = fallenEmpireCruiser_attitudeControl_normalizeAngleDeg(yawRaw - 90.0)
    local horiz = math.sqrt(dir[1] * dir[1] + dir[3] * dir[3])
    local pitch = math.deg(math.atan2(dir[2], horiz))
    pitch = fallenEmpireCruiser_attitudeControl_clamp(pitch, -fallenEmpireCruiser_attitudeControl_maxPitch, fallenEmpireCruiser_attitudeControl_maxPitch)
    return yaw, pitch
end

function fallenEmpireCruiser_attitudeControl_client_tick(dt)
    fallenEmpireCruiser_attitudeControl_clientTime = fallenEmpireCruiser_attitudeControl_clientTime + (dt or 0)

    if localPlayerId == -1 then
        return
    end

    local myVeh = GetPlayerVehicle()
    local okTag, has = pcall(HasTag, myVeh, "ship")
    if (not okTag) or (not has) then
        return
    end

    -- 长按右键：自由观察，不上报
    if fallenEmpireCruiser_camera_isLongPressActive() then
        return
    end

    local due = (fallenEmpireCruiser_attitudeControl_clientTime - fallenEmpireCruiser_attitudeControl_clientLastSendTime) >= fallenEmpireCruiser_attitudeControl_clientSendInterval
    if not due then
        return
    end

    local camT = GetCameraTransform()
    local camForward = TransformToParentVec(camT, Vec(0, 0, -1))
    camForward = VecNormalize(camForward)

    ServerCall(
        "fallenEmpireCruiser_attitudeControl_ReportCameraDir",
        localPlayerId,
        camForward[1],
        camForward[2],
        camForward[3]
    )

    fallenEmpireCruiser_attitudeControl_clientLastSendTime = fallenEmpireCruiser_attitudeControl_clientTime
end

-- RPC: client -> server
function fallenEmpireCruiser_attitudeControl_ReportCameraDir(playerId, dx, dy, dz)
    if not IsPlayerValid(playerId) then
        return
    end

    local okVeh, veh = pcall(GetPlayerVehicle, playerId)
    if (not okVeh) or (not veh) or veh == 0 then
        return
    end
    local okTag, has = pcall(HasTag, veh, "ship")
    if (not okTag) or (not has) then
        return
    end

    -- 单驾驶者锁（跨模块共享）
    if not fallenEmpireCruiser_driverLock_tryAcquire(veh, playerId) then
        return
    end

    local dir = Vec(dx or 0, dy or 0, dz or 0)
    if VecLength(dir) < 0.0001 then
        return
    end

    local st = fallenEmpireCruiser_attitudeControl_serverVehicleStates[veh]
    if not st then
        st = { driverId = playerId, body = 0, t = -999, aimYaw = 0, aimPitch = 0 }
        fallenEmpireCruiser_attitudeControl_serverVehicleStates[veh] = st
    end

    local okBody, body = pcall(GetVehicleBody, veh)
    if (not okBody) or (not body) or body == 0 then
        return
    end

    st.driverId = playerId
    st.body = body
    st.t = serverTime

    local shipT = GetBodyTransform(body)
    local aimYaw, aimPitch = fallenEmpireCruiser_attitudeControl_dirToYawPitch(dir)

    -- 限制相对偏航，避免绕到背后导致翻转
    local currentYaw = fallenEmpireCruiser_attitudeControl_getShipYaw(shipT)
    local yawDiff = fallenEmpireCruiser_attitudeControl_shortestAngleDiff(currentYaw, aimYaw)
    yawDiff = fallenEmpireCruiser_attitudeControl_clamp(yawDiff, -fallenEmpireCruiser_attitudeControl_maxYawOffset, fallenEmpireCruiser_attitudeControl_maxYawOffset)
    st.aimYaw = fallenEmpireCruiser_attitudeControl_normalizeAngleDeg(currentYaw + yawDiff)
    st.aimPitch = aimPitch
end

local function fallenEmpireCruiser_attitudeControl_server_applyRotation(dt)
    for veh, st in pairs(fallenEmpireCruiser_attitudeControl_serverVehicleStates) do
        if not veh or veh == 0 or (not st) then
            fallenEmpireCruiser_attitudeControl_serverVehicleStates[veh] = nil
        else
            if not st.driverId or not IsPlayerValid(st.driverId) then
                fallenEmpireCruiser_attitudeControl_serverVehicleStates[veh] = nil
            else
                local okVeh, curVeh = pcall(GetPlayerVehicle, st.driverId)
                if (not okVeh) or curVeh ~= veh then
                    fallenEmpireCruiser_attitudeControl_serverVehicleStates[veh] = nil
                elseif (serverTime - (st.t or -999)) > fallenEmpireCruiser_attitudeControl_inputTimeout then
                    -- 超时：不再继续转向
                else
                    local body = st.body
                    if not body or body == 0 then
                        local okBody, b = pcall(GetVehicleBody, veh)
                        if okBody then body = b end
                        st.body = body
                    end
                    if body and body ~= 0 then
                        local t = GetBodyTransform(body)

                        -- 根据当前朝向与目标朝向误差设置角速度（Yaw+Pitch）
                        local currentYaw = fallenEmpireCruiser_attitudeControl_getShipYaw(t)
                        local currentPitch = fallenEmpireCruiser_attitudeControl_getShipPitch(t)
                        local yawError = fallenEmpireCruiser_attitudeControl_shortestAngleDiff(currentYaw, st.aimYaw or 0)
                        local pitchError = fallenEmpireCruiser_attitudeControl_clamp((st.aimPitch or 0) - currentPitch, -fallenEmpireCruiser_attitudeControl_maxPitch, fallenEmpireCruiser_attitudeControl_maxPitch)

                        local yawSpeedDeg = fallenEmpireCruiser_attitudeControl_clamp(yawError * fallenEmpireCruiser_attitudeControl_kP_yaw, -fallenEmpireCruiser_attitudeControl_maxYawSpeed, fallenEmpireCruiser_attitudeControl_maxYawSpeed)
                        local pitchSpeedDeg = fallenEmpireCruiser_attitudeControl_clamp(pitchError * fallenEmpireCruiser_attitudeControl_kP_pitch, -fallenEmpireCruiser_attitudeControl_maxPitchSpeed, fallenEmpireCruiser_attitudeControl_maxPitchSpeed)

                        local yawSpeedRad = yawSpeedDeg * math.pi / 180.0
                        local pitchSpeedRad = pitchSpeedDeg * math.pi / 180.0

                        local localAngVel = Vec(pitchSpeedRad, yawSpeedRad, 0)
                        local worldAngVel = TransformToParentVec(t, localAngVel)
                        SetBodyAngularVelocity(body, worldAngVel)
                    end
                end
            end
        end
    end
end

local function fallenEmpireCruiser_attitudeControl_server_tick(dt)
    fallenEmpireCruiser_attitudeControl_server_applyRotation(dt or 0)
end

------------------------------------------------
-- fallenEmpireCruiser_attitudeControl 模块 结束
------------------------------------------------

9. 
对于用摄像机控制飞船转向这一块的内容,我有异议:
现在将思路转变为:服务器根据鼠标移动信息确定pitcherror和yawerror,而不是通过摄像机朝向实现.
然后服务器还是正常根据以上两个值逐步控制转向.

摄像机也会根据鼠标控制信息,围绕球面转动.确保转动前后


在CM2的server部分,shipAttitudeController模块,先编写数值方向的力:
error值越小,力越小;设置一个参数deathzone,代表当error值绝对值(不要用abs函数表示)小于这个死区值的时候,不施加力
当yawerror值为正的时候,在0,0,1和0,0,-1的位置分别施加1,0,0和-1,0,0方向的力形成力矩.力的大小需要乘以一个参数再乘以yawerror值,确保角度越小,力越小,且力的大小要合理

现在添加pitcherror值为正,在0,1,0和0,-1,0的位置分别施加-1,0,0和1,0,0方向的力形成力矩,力的大小需要乘以一个参数再乘以yawerror值,确保角度越小,力越小,且力的大小要合理

10. 从现在开始重构摄像机模块.需要重构的文件包括:
Content Mod 2\script\client\camera_modules\shipCamera.lua
Content Mod 2\script\server\movement\shipAttitudeController.lua
重构要求
1. Content Mod 2\script\client\camera_modules\shipCamera.lua文件输入的是鼠标移动的信息,然后通过改pitcherror和yawerror两个registry键来告诉服务器,当前飞船的前向方向和摄像机前向方向的误差.以及,只能使用SetCameraOffsetTransform函数设置摄像机的位置.yaw和pitch的计算方式不能变,角度限制也不能变.
2. Content Mod 2\script\server\movement\shipAttitudeController.lua文件输入的是对应飞船body的pitcherror和yawerror两个registry键,然后通过施加力矩的方式(比如说ApplyBodyImpulse)来改变飞船的转向.
3. Content Mod 2\script\client\camera_modules\shipCamera.lua功能要求.现在要求鼠标滑动一段距离,然后立即停止,在游戏中摄像机不会立即停止运动,而是会"滑动"一小段距离才会停止;
4. 现在有一个bug:当飞船被力矩扭动的时候,比如向左扭动,按理说这个时候摄像机在飞船的右边.飞船扭过来,摄像机相对飞船的位置会慢慢回正是吧?但是事实不会,摄像机相对于飞船的相对位置始终是没变的,这就非常难操控了.
一样的,你先设计详细方案.我决定以后你再拍板.你的方案要尽量形象,通俗易懂!

11. 现在我点击左键,我发现x槽武器发射点和发射方向都和飞船朝向相反.检查原因,我来排版是否修复
12. 现在用户点击左键->武器发射->蓄力->命中点判定(是否命中,是否命中群星飞船,是否打到护盾等)->命中效果结算(给对面的群星body减血等)->特效绘制  等这一套武器逻辑是如何做的?详细说说,我需要你来修复问题改代码了

13. 现在用户点击w/s->飞船移动这一套移动逻辑是如何做的?

14. 现在查看CM2下的main.xml的
```xml
	<script pos="-15.2 7.9 12.8" file="MOD/script/shipMain.lua">
		<vehicle name="ship" tags="stellarisShip" pos="0.0 0.0 0.0" driven="true" sound=" " spring="0.5" damping="0" topspeed="0" acceleration="0" strength="0" friction="0.5">
			<body name="body" tags="stellarisShip" pos="0.0 0.0 0.0" dynamic="true">
				<vox tags="missileLauncher" pos="0.5 7.0 1.1" file="MOD/vox/missileLauncher.vox"/>
				<vox tags="missileLauncher" pos="-0.5 -7.0 1.1" rot="0 0 180" file="MOD/vox/missileLauncher.vox"/>
				<vox tags="missileLauncher" pos="-0.5 7.0 1.1" file="MOD/vox/missileLauncher.vox" mirrorx="true"/>
				<vox tags="missileLauncher" pos="0.5 -7.0 1.1" rot="0 0 180" file="MOD/vox/missileLauncher.vox" mirrorx="true"/>
				<vox tags="primaryWeaponLauncher" pos="0.0 0.0 0.0" file="MOD/vox/primaryWeaponLauncher.vox"/>
				<vox tags="hull" pos="0.0 0.0 0.0" file="MOD/vox/hull.vox"/>
				<vox tags="thruster" pos="-1.1 0.4 1.3" file="MOD/vox/thruster.vox"/>
				<vox tags="thruster" pos="1.1 0.4 1.3" file="MOD/vox/thruster.vox"/>
				<vox tags="thruster" pos="-1.1 -0.5 1.3" file="MOD/vox/thruster.vox"/>
				<vox tags="thruster" pos="1.1 -0.5 1.3" file="MOD/vox/thruster.vox"/>
				<vox tags="engine" pos="-0.5 -0.4 0.0" file="MOD/vox/engine.vox"/>
				<vox tags="engine" pos="-0.2 -0.4 0.0" file="MOD/vox/engine.vox"/>
				<vox tags="engine" pos="0.1 -0.4 0.0" file="MOD/vox/engine.vox"/>
				<vox tags="engine" pos="0.4 -0.4 0.0" file="MOD/vox/engine.vox"/>
				<vox tags="engine" pos="0.7 -0.4 0.0" file="MOD/vox/engine.vox"/>
				<vox tags="smallThruster" pos="2.1 0.1 0.0" rot="0 0 180" file="MOD/vox/smallThruster.vox"/>
				<vox tags="smallThruster" pos="-2.1 -0.1 0.0" file="MOD/vox/smallThruster.vox"/>
				<vox tags="secondaryLightSystem" pos="0.0 0.0 0.0" file="MOD/vox/secondaryLightSystem.vox"/>
				<vox tags="mainLightSystem" pos="0.0 0.0 0.0" file="MOD/vox/mainLightSystem.vox"/>
				<vox tags="armor" pos="0.0 0.0 0.0" file="MOD/vox/armor.vox"/>
			</body>
			<location name="Player" tags="player" pos="0.0 -0.1 -0.3" rot="0 180 180"/>
			<location name="exit" tags="exit" pos="0.0 0.2 -2.6"/>
		</vehicle>
	</script>
```

对所有engine的shape都添加特效.冒火的特效(类似引擎燃烧).这需要一个新模块,写在CM2 client下的draw_modules文件夹下

顺带一问.现在点击w,secondaryLightSystem就暗,s就亮.系统看起来把secondaryLightSystem当尾灯了.我怎么保证secondaryLightSystem所有方块始终亮呢?当然有人上船才亮,没有人就灭