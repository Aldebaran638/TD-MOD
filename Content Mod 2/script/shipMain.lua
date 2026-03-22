-- 璇ヨ剼鏈殑body鐐瑰嚮宸﹂敭浠ュ悗鍚戝墠鏂瑰彂灏勫揩瀛愬厜锟?
#version 2
#include "script/include/common.lua"

#include "server/ship_data.lua"
#include "server/weapon_data.lua"

#include "server/registry/shipRegistry.lua"
#include "server/registry/shipRegistryRequest.lua"

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field


-- server = server or {}

-- -- registry 璁块棶锟?
-- #include "server/registry/shipRegistry.lua"

-- 鏈嶅姟绔嚱鏁帮細娉ㄥ唽鈥滃綋鍓嶈繖鑹橀鑸光€濆埌 Registry锟?
-- 褰撳墠椋炶埞锟?server.shipBody 鎸囧畾锛涜鑴氭湰鍙淮鎶よ繖涓€鑹橀鑸癸拷?
function server.registerCurrentShip(shipType)

    local shipBodyId = server.shipBody
    if shipBodyId == nil or shipBodyId == 0 then
        return nil
    end
    server.registryShipRegister(shipBodyId, shipType, server.defaultShipType)
    return server.registryShipGetSnapshot(shipBodyId)
end

-- 鏈嶅姟绔嚱鏁帮細纭繚鈥滃綋鍓嶈繖鑹橀鑸光€濆湪 Registry 涓瓨鍦拷?
-- 鑻ュ綋鍓嶉鑸硅繕鏈敞鍐岋紝鍒欐寜榛樿椋炶埞妯℃澘琛ラ綈杩愯鏃剁姸鎬侊拷?
function server.ensureCurrentShipState(shipType)
    local shipBodyId = server.shipBody
    if shipBodyId == nil or shipBodyId == 0 then
        return nil
    end
    server.registryShipEnsure(shipBodyId, shipType or server.defaultShipType, server.defaultShipType)
    return server.registryShipGetSnapshot(shipBodyId)
end

-- x 妲芥帶鍒舵ā鍧椾粠澶栭儴鎶藉彇涓虹嫭绔嬫枃浠讹細script/server/weapon_fire/xSlotControl.lua
#include "server/weapon_fire/xSlotControl.lua"
-- 绉诲姩绫绘ā鍧楋細鏍规嵁 body 璐ㄩ噺鏂藉姞绔栫洿鍚戜笂锟?
#include "server/movement/bodyMassUpwardMove.lua"
-- 绉诲姩绫绘ā鍧楋細鏍规嵁 W/S 杈撳叆鏂藉姞鍓嶅悗鎺ㄨ繘锟?
#include "server/movement/bodyDirectionalMove.lua"
-- 绉诲姩绫绘ā鍧楋細鎺ユ敹瀹㈡埛锟?moveState 鏇存柊
#include "server/movement/bodyMoveStateReceive.lua"
-- 绉诲姩绫绘ā鍧楋細濮嬬粓鏂藉姞涓庨€熷害鍙嶅悜鐨勫钩鏂归樆锟?
#include "server/movement/bodyVelocityQuadraticDamping.lua"
-- 绉诲姩绫绘ā锟?鏍规嵁 registry 涓殑濮挎€佽宸柦鍔犳壄鐭╄繘琛岃嚜鍔ㄨ皟锟?
#include "server/movement/shipAttitudeController.lua"
#include "server/movement/shipRollStabilizer.lua"
#include "server/movement/shipDeathExplosion.lua"

-- 鏈嶅姟绔垵濮嬪寲
function server.init()
    -- -- 褰撳墠姝﹀櫒鐘讹拷?
    -- -- "idle"      绌洪棽
    -- -- "charging"  鍏呰兘锟?
    -- -- "launching" 鍙戝皠锟?
    -- server.weaponState = "idle"

    -- -- 涓婁竴甯ф鍣ㄧ姸锟?鐢ㄤ簬妫€娴嬬姸鎬佸彉鍖栫殑绗竴锟?
    -- server.weaponStateLastTick = "idle"

    -- -- 鍏呰兘鎵€闇€鏃堕棿
    -- server.chargeTime = 20

    -- -- 鍙戝皠鎸佺画鏃堕棿
    -- server.launchTime = 0.2

    -- 鍒濆鍖栧綋鍓嶉鑸?
    server.shipBody = FindBody("stellarisShip", false)
    SetBool("StellarisShips/debug/inputTestEnabled", false)
    -- 娉ㄥ唽褰撳墠椋炶埞骞跺姞杞介鑸规暟锟?
    server.registerCurrentShip("enigmaticCruiser")

end

-- 鍦╰ick涓娇鐢ㄥ埌鐨勫彉锟?
-- server.weaponState 褰撳墠姝﹀櫒鐘讹拷?"idle"/"charging"/"launching")
-- server.weaponStateLastTick 姝﹀櫒鍦ㄤ笂涓€甯х殑鐘讹拷?鐢ㄤ簬妫€娴嬬姸鎬佸彉鍖栫殑绗竴锟?
-- server.chargeTime 椋炶埞鍏呰兘鎵€闇€鏃堕棿
-- server.launchTime 椋炶埞鍙戝皠鎸佺画鏃堕棿
function server.serverTick(dt)
    -- server.ensureCurrentShipState(defaultShipType)
    server.xSlotControlTick(dt)
    server.shipDeathExplosionTick(dt)
    server.bodyMoveStateReceiveTick(dt)
    server.bodyMassUpwardMoveTick(dt)
    server.bodyDirectionalMoveTick(dt)
    server.bodyVelocityQuadraticDampingTick(dt)
end

function server.update(dt)
    server.shipAttitudeControllerUpdate(dt)
    server.shipRollStabilizerUpdate(dt)
end

#include "client/client.lua"


-- 瀹㈡埛锟?tick锛氬彧璋冪敤鎬绘帶鍑芥暟
function client.tick(dt)
    client.clientTick(dt)
end

function client.draw()
    client.clientDraw()
end

function server.tick(dt)
    server.serverTick(dt)

end









