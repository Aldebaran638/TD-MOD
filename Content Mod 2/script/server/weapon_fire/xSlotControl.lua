-- xSlotControl.lua
-- 独立的 x 槽控制模块（从 test2.lua 抽取）
-- 该文件包含：请求消费、状态机推进、射线判定、命中结算、状态变化回调

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- 将 registry 存储的 vec3 表转换为 Teardown 的 Vec
local function _vec3TableToVec(v, defaultX, defaultY, defaultZ)
    local t = v or {}
    return Vec(t.x or defaultX or 0, t.y or defaultY or 0, t.z or defaultZ or 0)
end

-- 读取武器类型参数（射程、伤害系数等）
local function _resolveWeaponSettings(weaponType)
    local defs = weaponData or {}
    local resolvedWeaponType = weaponType or "tachyonLance"
    local settings = defs[resolvedWeaponType] or defs.tachyonLance or {}
    -- 兼容旧字段：weapon_data.lua 里可能使用 CD（大写）
    if settings.cooldown == nil and settings.CD ~= nil then
        settings.cooldown = settings.CD
    end
    return settings
end

local function _xSlotWeaponTypeUsable(weaponType)
    return weaponType ~= nil and weaponType ~= "" and weaponType ~= "none"
end

-- 读取目标飞船护盾半径（用于护盾球面入射点修正）
local function _resolveTargetShieldRadius(targetBody, fallbackShipType)
    local radiusFallback = 20
    local fallbackType = fallbackShipType or "enigmaticCruiser"
    local fallbackShipData = (shipData and shipData[fallbackType]) or (shipData and shipData.enigmaticCruiser) or {}
    if fallbackShipData.shieldRadius ~= nil then
        radiusFallback = fallbackShipData.shieldRadius
    end

    if targetBody == nil or targetBody == 0 then
        return radiusFallback
    end

    local targetSnap = server.registryShipGetSnapshot(targetBody)
    if targetSnap == nil then
        return radiusFallback
    end

    local targetType = targetSnap.shipType or fallbackType
    local targetTypeData = (shipData and shipData[targetType]) or (shipData and shipData[fallbackType]) or {}
    return targetTypeData.shieldRadius or radiusFallback
end

-- 服务端函数:接收来自客户端的发射请求,设置蓄力时间为非0
-- 服务端函数：接收客户端开火输入并写入统一 request 键
-- 说明：这里只写请求，不在这里推进 charging/launching
function server_xSlot_handleFireRequest()
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        return
    end
    server.registryShipEnsure(shipBody, server.defaultShipType, server.defaultShipType)
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(shipBody) then
        return
    end
    server.registryShipSetXSlotRequest(shipBody, 1, 1)
end

-- 兼容旧流程的请求消费函数（后续将并入统一 tick 状态机）
local function _xSlotConsumeRequestAndMaybeStartCharging()
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        return
    end

    server.registryShipEnsure(shipBody, server.defaultShipType, server.defaultShipType)
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(shipBody) then
        server.registryShipSetXSlotRequest(shipBody, 1, 0)
        return
    end
    local request = server.registryShipGetXSlotRequest(shipBody, 1)
    if request == 0 then
        return
    end

    -- 请求一旦读取即消费，避免重复触发
    server.registryShipSetXSlotRequest(shipBody, 1, 0)

    if server.weaponState == "idle" then
        server.weaponState = "charging"
        server.chargeTime = 0.5
    end
end

-- x槽武器 计算命中点信息的统一函数
-- 参数:发射刚体ID 起始发射点 发射方向 武器类型
-- 返回值: 激光结束点,命中目标ID(如果没有命中或者命中的是非群星body则为无效值),是否命中,是否命中的shape所属的body是群星body
-- 逻辑:
--   - 未命中任何 shape: isHit=false,isHitStellarisBody=false,hitTarget=0,endPos=最远点
--   - 命中 shape 但其父 Body 未注册到 registry: isHit=true,isHitStellarisBody=false,hitTarget=0,endPos=命中点
--   - 命中 shape 且其父 Body 已注册到 registry: isHit=true,isHitStellarisBody=true,hitTarget=该父 Body 的 handle,endPos=命中点
function server.xSlot_computeHitResult(shipBodyId, firePosOffset, fireDirRelative, weaponType)
    local function _xSlot_dbgReturn(endPos, hitTarget, isHit, isHitStellarisBody)
        return
    end

    local function _raySphereEntryT(origin, dirUnit, center, radius)
        -- 求射线 p=origin+dir*t 与球 |p-center|=radius 的入射点 t（最小非负解）
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

    -- 默认无效值约定：Body handle 用 0 代表无效
    local invalidTarget = 0

    if shipBodyId == nil or shipBodyId == 0 or firePosOffset == nil or fireDirRelative == nil then
        local endPos, hitTarget, isHit, isHitStellarisBody, normal = Vec(0, 0, 0), invalidTarget, false, false, Vec(0, 1, 0)
        _xSlot_dbgReturn(endPos, hitTarget, isHit, isHitStellarisBody)
        return endPos, hitTarget, isHit, isHitStellarisBody, normal
    end

    -- 1) 将发射点偏移转换成世界坐标
    local shipT = GetBodyTransform(shipBodyId)
    local origin = TransformToParentPoint(shipT, firePosOffset)

    -- 2) 将相对方向转换成世界方向向量，并归一化
    local dir = TransformToParentVec(shipT, fireDirRelative)
    local dirLen = VecLength(dir)
    if dirLen < 0.0001 then
        dir = TransformToParentVec(shipT, Vec(0, 0, -1))
        dirLen = VecLength(dir)
    end
    if dirLen < 0.0001 then
        dir = Vec(0, 0, -1)
        dirLen = 1.0
    end
    dir = VecScale(dir, 1.0 / dirLen)

    -- 3) 射线检测（射程来自武器类型参数）
    local weaponSettings = _resolveWeaponSettings(weaponType)
    local maxRange = weaponSettings.maxRange or 1
    if maxRange <= 0 then
        maxRange = 1
    end

    QueryRequire("physical")
    QueryRejectBody(shipBodyId)
    local hit, dist, normal, shape = QueryRaycast(origin, dir, maxRange)
    if not hit then
        local endPos = VecAdd(origin, VecScale(dir, maxRange))
        local hitTarget, isHit, isHitStellarisBody = invalidTarget, false, false
        _xSlot_dbgReturn(endPos, hitTarget, isHit, isHitStellarisBody)
        return endPos, hitTarget, isHit, isHitStellarisBody, dir
    end

    local endPos = VecAdd(origin, VecScale(dir, dist))
    if shape == nil or shape == 0 then
        local hitTarget, isHit, isHitStellarisBody = invalidTarget, true, false
        _xSlot_dbgReturn(endPos, hitTarget, isHit, isHitStellarisBody)
        return endPos, hitTarget, isHit, isHitStellarisBody, normal
    end

    local targetBody = GetShapeBody(shape)
    if targetBody ~= nil and targetBody ~= 0 and server.registryShipExists(targetBody) then
        -- 命中群星飞船：把 endPos 修正为护盾球面入射点
        local bodyT = GetBodyTransform(targetBody)
        local comLocal = GetBodyCenterOfMass(targetBody)
        local center = TransformToParentPoint(bodyT, comLocal)
        local shieldRadius = _resolveTargetShieldRadius(targetBody, server.defaultShipType or "enigmaticCruiser")
        local entryT = _raySphereEntryT(origin, dir, center, shieldRadius)
        if entryT ~= nil and entryT <= maxRange then
            endPos = VecAdd(origin, VecScale(dir, entryT))
        end

        local hitTarget, isHit, isHitStellarisBody = targetBody, true, true
        _xSlot_dbgReturn(endPos, hitTarget, isHit, isHitStellarisBody)
        return endPos, hitTarget, isHit, isHitStellarisBody, normal
    end

    local hitTarget, isHit, isHitStellarisBody = invalidTarget, true, false
    _xSlot_dbgReturn(endPos, hitTarget, isHit, isHitStellarisBody)
    return endPos, hitTarget, isHit, isHitStellarisBody, normal
end

-- 根据命中信息结算效果
-- 命中群星飞船：按 shield->armor->body 顺序结算伤害，支持跨层溢出
-- 命中非群星飞船：在命中点产生一次爆炸
-- 未命中：不产生效果
-- 返回值：渲染层辅助信息（didHitShield / impactLayer）
function server.xSlot_applyHitResult(endPos, hitTarget, isHit, isHitStellarisBody, weaponType)

    -- 返回给渲染层的命中补充信息
    local renderResult = {
        didHitShield = false,
        impactLayer = "none",
    }

    if not isHit then
        return renderResult
    end

    if isHitStellarisBody then
        local resolvedDefaultShipType = server.defaultShipType or "enigmaticCruiser"
        if not server.registryShipEnsure(hitTarget, resolvedDefaultShipType, resolvedDefaultShipType) then
            return renderResult
        end

        -- 命中已摧毁的群星飞船：按环境命中处理，保证仍有普通爆炸效果
        if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(hitTarget) then
            renderResult.impactLayer = "environment"
            if endPos ~= nil then
                Explosion(endPos, 4.0)
            end
            return renderResult
        end

        local targetShip = server.registryShipGetSnapshot(hitTarget)
        if targetShip == nil then
            return renderResult
        end

        local targetShipData = (shipData and shipData[targetShip.shipType]) or (shipData and shipData[resolvedDefaultShipType]) or {}
        local targetWeaponData = (weaponData and weaponData[weaponType]) or (weaponData and weaponData.tachyonLance) or {}
        local damageMin = targetWeaponData.damageMin or 0
        local damageMax = targetWeaponData.damageMax or damageMin
        if damageMax < damageMin then
            damageMax = damageMin
        end

        local rolledDamage = damageMin
        if damageMax > damageMin then
            rolledDamage = math.random(damageMin, damageMax)
        end

        -- 伤害跨层溢出模型：
        -- rawDamage 按层系数转换为当前层有效伤害；若本层被打穿，剩余“原始伤害”继续传给下一层
        local rawRemain = rolledDamage

        local function _applyLayerOverflow(layerName, currentHp, damageFix)
            local hp = currentHp or 0
            local fix = damageFix or 1
            if hp <= 0 or rawRemain <= 0 or fix <= 0 then
                return hp
            end

            local potential = rawRemain * fix
            if potential <= 0 then
                return hp
            end

            local consumedRaw = 0
            if potential < hp then
                hp = hp - potential
                consumedRaw = rawRemain
            else
                consumedRaw = hp / fix
                hp = 0
            end

            rawRemain = rawRemain - consumedRaw
            if rawRemain < 0 then
                rawRemain = 0
            end

            -- 记录第一命中层：用于客户端特效分层
            if renderResult.impactLayer == "none" then
                renderResult.impactLayer = layerName
            end
            if layerName == "shield" then
                renderResult.didHitShield = true
            end

            return hp
        end

        targetShip.shieldHP = _applyLayerOverflow("shield", targetShip.shieldHP or 0, targetWeaponData.shieldFix)
        targetShip.armorHP = _applyLayerOverflow("armor", targetShip.armorHP or 0, targetWeaponData.armorFix)
        targetShip.bodyHP = _applyLayerOverflow("body", targetShip.bodyHP or 0, targetWeaponData.bodyFix)

        -- 上限钳制，避免异常数值超过类型定义的最大值
        local maxShield = targetShipData.maxShieldHP or targetShip.shieldHP or 0
        local maxArmor = targetShipData.maxArmorHP or targetShip.armorHP or 0
        local maxBody = targetShipData.maxBodyHP or targetShip.bodyHP or 0
        if targetShip.shieldHP > maxShield then targetShip.shieldHP = maxShield end
        if targetShip.armorHP > maxArmor then targetShip.armorHP = maxArmor end
        if targetShip.bodyHP > maxBody then targetShip.bodyHP = maxBody end

        server.registryShipSetHP(hitTarget, targetShip.shieldHP, targetShip.armorHP, targetShip.bodyHP)

        return renderResult
    end

    renderResult.impactLayer = "environment"
    if endPos == nil then
        return renderResult
    end

    -- Teardown API: Explosion(pos, size) 其中 size 范围 0.5 - 4.0
    -- 为了看清客户端渲染特效.暂时屏蔽爆炸效果
    Explosion(endPos, 4.0)
    return renderResult
end

-- 写入渲染事件：开始充能
-- 说明：不再使用 ClientCall，统一写入 Registry 供客户端拉取
function server.xSlot_broadcastChargingStart(shipBodyId, slotIndex, weaponType, firePointWorld)
    server.registryShipWriteXSlotsRenderEvent(shipBodyId, {
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

-- 写入渲染事件：开始发射
function server.xSlot_broadcastLaunchingStart(shipBodyId, slotIndex, weaponType, firePointWorld, hitPointWorld, didHit, didHitStellarisBody, didHitShield, hitTargetBodyId, normal, impactLayer)
    server.registryShipWriteXSlotsRenderEvent(shipBodyId, {
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

-- 写入渲染事件：武器回到 idle
function server.xSlot_broadcastWeaponIdle(shipBodyId, slotIndex, weaponType, firePointWorld)
    server.registryShipWriteXSlotsRenderEvent(shipBodyId, {
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

-- x 槽控制主 Tick
-- 设计目标：
-- 1) 统一 request 键（xSlots/request）
-- 2) 单系统管理（同一时刻只允许一个武器流程）
-- 3) 全流程由 Registry 驱动（state/chargeRemain/launchRemain）
function server.xSlotControlTick(dt)

    -- 步骤1：确认当前飞船有效
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        return
    end

    -- 步骤2：确保飞船已注册到 Registry
    if not server.registryShipEnsure(shipBody, server.defaultShipType, server.defaultShipType) then
        return
    end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(shipBody) then
        server.registryShipSetXSlotsRequest(shipBody, 0)
        return
    end

    -- 步骤3：读取飞船快照（用于获取槽位数量和槽位参数）
    local shipSnap = server.registryShipGetSnapshot(shipBody)
    if shipSnap == nil then
        return
    end

    -- 步骤4：没有 x 槽时直接返回
    local xSlotCount = shipSnap.xSlotCount or 0
    if xSlotCount <= 0 then
        return
    end

    -- 步骤5：每帧更新所有 x 槽冷却（cd>0 则递减；cd==-1 表示不可用，保持不变）
    for i = 1, xSlotCount do
        local cd = server.registryShipGetXSlotCD(shipBody, i)
        if cd > 0 then
            cd = cd - dt
            if cd < 0 then
                cd = 0
            end
            server.registryShipSetXSlotCD(shipBody, i, cd)
        end
    end

    -- 冷却更新后刷新一次快照，确保后续选槽读取到最新 cd
    shipSnap = server.registryShipGetSnapshot(shipBody) or shipSnap

    -- 步骤6：确定当前活跃槽位（lastReadSeq 表示“当前被系统处理的槽位”）
    local activeSlot = server.registryShipGetXSlotsLastReadSeq(shipBody)
    if activeSlot == nil or activeSlot < 1 or activeSlot > xSlotCount then
        activeSlot = 1
        server.registryShipSetXSlotsLastReadSeq(shipBody, activeSlot)
    end

    local activeState = server.registryShipGetXSlotState(shipBody, activeSlot)

    ------------------------------------------------
    -- 步骤7：统一 request 消费逻辑（单 request 键）
    -- 规则：只有 activeState 为 idle 才接收新请求；且仅能选中“cd==0 且 state=idle”的首个槽位
    ------------------------------------------------
    local request = server.registryShipGetXSlotsRequest(shipBody)
    if request ~= 0 then
        -- 请求一旦读取立即消费，避免同一次点击重复触发与排队补发
        server.registryShipSetXSlotsRequest(shipBody, 0)

        if activeState ~= "idle" then
            request = 0
        end
    end

    if request ~= 0 and activeState == "idle" then

        local selectedSlot = nil
        for i = 1, xSlotCount do
            local slotCd = server.registryShipGetXSlotCD(shipBody, i)
            local slotState = server.registryShipGetXSlotState(shipBody, i)
            local slotSnap = (shipSnap and shipSnap.xSlots and shipSnap.xSlots[i]) or {}
            local slotWeaponType = slotSnap.weaponType
            if slotCd == 0 and slotState == "idle" and _xSlotWeaponTypeUsable(slotWeaponType) then
                selectedSlot = i
                break
            end
        end

        -- 只有找到可用槽位才进入 charging；否则本次点击无效
        if selectedSlot ~= nil then
            activeSlot = selectedSlot
            server.registryShipSetXSlotsLastReadSeq(shipBody, activeSlot)

            local selectedSlotSnap = shipSnap.xSlots[activeSlot] or {}
            local chargeDuration = selectedSlotSnap.chargeDuration or 0
            if chargeDuration < 0 then
                chargeDuration = 0
            end

            server.registryShipSetXSlotChargeRemain(shipBody, activeSlot, chargeDuration)
            server.registryShipSetXSlotState(shipBody, activeSlot, "charging")

            -- charging 开始时将 cd 置为 -1，表示冷却不可用
            server.registryShipSetXSlotCD(shipBody, activeSlot, -1)
            activeState = "charging"
        end
    end

    -- 步骤8：强制其余槽位回 idle，保证“同一时刻仅一个武器流程”
    for i = 1, xSlotCount do
        if i ~= activeSlot then
            server.registryShipSetXSlotState(shipBody, i, "idle")
        end
    end

    ------------------------------------------------
    -- 步骤9：状态持续逻辑（Registry 驱动）
    -- charging: 递减 chargeRemain，到 0 后切到 launching
    -- launching: 递减 launchRemain，到 0 后切到 idle
    ------------------------------------------------
    if activeState == "charging" then
        local chargeRemain = server.registryShipGetXSlotChargeRemain(shipBody, activeSlot) - dt
        if chargeRemain <= 0 then
            chargeRemain = 0
            server.registryShipSetXSlotChargeRemain(shipBody, activeSlot, chargeRemain)

            local refreshedSnap = server.registryShipGetSnapshot(shipBody)
            local slotSnap = (refreshedSnap and refreshedSnap.xSlots and refreshedSnap.xSlots[activeSlot]) or {}
            local launchDuration = slotSnap.launchDuration or 0
            if launchDuration < 0 then
                launchDuration = 0
            end

            server.registryShipSetXSlotLaunchRemain(shipBody, activeSlot, launchDuration)
            server.registryShipSetXSlotState(shipBody, activeSlot, "launching")
            activeState = "launching"
        else
            server.registryShipSetXSlotChargeRemain(shipBody, activeSlot, chargeRemain)
        end
    elseif activeState == "launching" then
        local launchRemain = server.registryShipGetXSlotLaunchRemain(shipBody, activeSlot) - dt
        if launchRemain <= 0 then
            launchRemain = 0
            server.registryShipSetXSlotLaunchRemain(shipBody, activeSlot, launchRemain)
            server.registryShipSetXSlotState(shipBody, activeSlot, "idle")

            -- launching 结束进入 idle 时，按武器配置写入正式冷却
            local refreshedSnap = server.registryShipGetSnapshot(shipBody)
            local slotSnap = (refreshedSnap and refreshedSnap.xSlots and refreshedSnap.xSlots[activeSlot]) or {}
            local runtimeWeaponType = slotSnap.weaponType or "none"
            local cooldown = 0
            if _xSlotWeaponTypeUsable(runtimeWeaponType) then
                local runtimeWeaponSettings = _resolveWeaponSettings(runtimeWeaponType)
                cooldown = runtimeWeaponSettings.cooldown or runtimeWeaponSettings.CD or 0
                if cooldown < 0 then
                    cooldown = 0
                end
            end
            server.registryShipSetXSlotCD(shipBody, activeSlot, cooldown)

            activeState = "idle"
        else
            server.registryShipSetXSlotLaunchRemain(shipBody, activeSlot, launchRemain)
        end
    else
        activeState = "idle"
        server.registryShipSetXSlotState(shipBody, activeSlot, "idle")
    end

    ------------------------------------------------
    -- 步骤10：状态变化检测（统一第一帧处理）
    -- 说明：这里处理“进入 charging/launching/idle 的第一帧事件”
    ------------------------------------------------
    local lastState = server.xSlotStateLastTick or "idle"
    local lastSlot = server.xSlotActiveSlotLastTick or activeSlot
    if activeState ~= lastState or activeSlot ~= lastSlot then
        local runtimeSnap = server.registryShipGetSnapshot(shipBody)
        local slotSnap = (runtimeSnap and runtimeSnap.xSlots and runtimeSnap.xSlots[activeSlot]) or {}

        local mountPos = slotSnap.firePosOffset or { x = 0, y = 0, z = 4 }
        local mountDir = slotSnap.fireDirRelative or { x = 0, y = 0, z = 1 }
        local runtimeWeaponType = slotSnap.weaponType or "none"

        local firePosOffset = _vec3TableToVec(mountPos, 0, 0, 4)
        local fireDir = _vec3TableToVec(mountDir, 0, 0, 1)
        local shipT = GetBodyTransform(shipBody)
        local firePointWorld = TransformToParentPoint(shipT, firePosOffset)

        if activeState == "charging" then
            -- charging 第一帧：写入 charging_start 渲染事件
            server.xSlot_broadcastChargingStart(shipBody, activeSlot, runtimeWeaponType, firePointWorld)
        elseif activeState == "launching" then
            -- launching 第一帧：计算命中、应用伤害、触发发射回调
            local endPos, hitTarget, isHit, isHitStellarisBody, normal = server.xSlot_computeHitResult(shipBody, firePosOffset, fireDir, runtimeWeaponType)
            local renderHitResult = server.xSlot_applyHitResult(endPos, hitTarget, isHit, isHitStellarisBody, runtimeWeaponType)
            server.xSlot_broadcastLaunchingStart(
                shipBody,
                activeSlot,
                runtimeWeaponType,
                firePointWorld,
                endPos,
                isHit,
                isHitStellarisBody,
                renderHitResult.didHitShield,
                hitTarget,
                normal,
                renderHitResult.impactLayer
            )
        elseif activeState == "idle" then
            -- idle 第一帧：写入 idle 渲染事件
            server.xSlot_broadcastWeaponIdle(shipBody, activeSlot, runtimeWeaponType, firePointWorld)
        end
    end
    -- 步骤11：记录本帧结果，供下一帧做“状态变化检测”
    server.xSlotStateLastTick = activeState
    server.xSlotActiveSlotLastTick = activeSlot

end
