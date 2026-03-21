---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

-- 接收来自服务端的充能广播（charging 第一帧）
function client_ReceiveBroadcastChargingStart(shipBodyId, firePosOffsetShip, weaponType)
    local shipData = client.ensureShipRegistered(shipBodyId)
    if shipData == nil then
        return
    end

    local xSlot = shipData.weapons.xSlot
    xSlot.state = "charging"
    xSlot.weaponType = weaponType
    xSlot.firePoint = firePosOffsetShip
    xSlot.hitPoint = nil
    xSlot.hitTarget = nil
    xSlot.didHit = nil
    xSlot.didHitStellarisBody = nil
    client.hitNormals[shipBodyId] = nil
end

-- 接收来自服务端的发射广播（launching 第一帧）
function client_ReceiveBroadcastLaunchingStart(shipBodyId, firePoint, hitPoint, didHit, hitTarget, didHitStellarisBody, weaponType, normal)
    local shipData = client.ensureShipRegistered(shipBodyId)
    if shipData == nil then
        return
    end

    local xSlot = shipData.weapons.xSlot
    xSlot.state = "launching"
    xSlot.weaponType = weaponType
    xSlot.firePoint = firePoint
    xSlot.hitPoint = hitPoint
    xSlot.hitTarget = hitTarget
    xSlot.didHit = didHit
    xSlot.didHitStellarisBody = didHitStellarisBody

    client.hitNormals[shipBodyId] = normal
end

-- 接收来自服务端的 idle 广播（idle 第一帧）
function client_ReceiveBroadcastWeaponIdle(shipBodyId)
    local shipData = client.ensureShipRegistered(shipBodyId)
    if shipData == nil then
        return
    end

    local xSlot = shipData.weapons.xSlot
    xSlot.state = "idle"
    xSlot.weaponType = nil
    xSlot.firePoint = nil
    xSlot.hitPoint = nil
    xSlot.hitTarget = nil
    xSlot.didHit = nil
    xSlot.didHitStellarisBody = nil

    client.hitNormals[shipBodyId] = nil
end
