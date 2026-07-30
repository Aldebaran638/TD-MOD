---@diagnostic disable: undefined-global

server = server or {}

local function _register(componentId, component)
    local ok, err = server.weaponRuntimeRegister(componentId, component)
    if not ok then
        error("weapon runtime registration failed: " .. tostring(err))
    end
end

-- 特殊武器可以保留自己的状态机，但必须通过统一生命周期和控制器接口接入。
_register("specialized.mainWeaponControl", {
    initOrder = 10,
    commandTickOrder = 10,
    isActive = function(phase)
        return phase ~= "commandTick"
            or server.shipRuntimeGetDriverPlayerId(
                server.shipContextGetBody()
            ) > 0
    end,
    init = function()
        server.mainWeaponControlInit()
    end,
    commandTick = function(dt)
        server.mainWeaponControlTick(dt)
    end,
    clearCommands = function()
        server.mainWeaponRequestSetFireRequested(false)
        server.mainWeaponRequestSetToggleRequested(false)
    end,
})

_register("specialized.chargedSpinal", {
    initOrder = 20,
    rebuildResetOrder = 10,
    rebuildInitOrder = 10,
    simulationTickOrder = 10,
    deactivateOrder = 10,
    isActive = function(phase)
        return phase ~= "simulationTick"
            or (
                server.weaponGroupUsesController("chargedSpinal")
                and server.xSlotStateNeedsTick()
            )
    end,
    init = function(shipType)
        server.xSlotStateInit(shipType)
    end,
    rebuildReset = function()
        server.xSlotStateResetRuntime()
    end,
    rebuildInit = function(shipType)
        server.xSlotStateInit(shipType)
    end,
    simulationTick = function(dt)
        server.xSlotControlTick(dt)
    end,
    deactivate = function()
        server.xSlotStateSetHoldRequested(false)
        server.xSlotStateSetRequestFire(false)
        server.xSlotStateResetRuntime()
    end,
    clearCommands = function()
        server.xSlotStateSetHoldRequested(false)
        server.xSlotStateSetRequestFire(false)
        server.xSlotStateSetReleaseRequested(false)
    end,
})

_register("specialized.chargedSpinalRenderState", {
    initOrder = 30,
    init = function()
        server.xSlotRenderStateInit()
    end,
})

_register("specialized.chargedSpinalMuzzleLight", {
    initOrder = 40,
    rebuildResetOrder = 80,
    simulationTickOrder = 20,
    deactivateOrder = 20,
    isActive = function(phase)
        return phase ~= "simulationTick"
            or (
                server.weaponGroupUsesController("chargedSpinal")
                and server.xSlotStateNeedsTick()
            )
    end,
    init = function()
        server.tachyonMuzzleLightInit()
    end,
    rebuildReset = function()
        server.tachyonMuzzleLightStop("tachyonLance")
    end,
    simulationTick = function(dt)
        server.tachyonMuzzleLightTick(dt)
    end,
    deactivate = function()
        server.tachyonMuzzleLightStop("tachyonLance")
    end,
})

_register("specialized.kineticArtillery", {
    initOrder = 50,
    rebuildResetOrder = 20,
    rebuildInitOrder = 20,
    simulationTickOrder = 30,
    deactivateOrder = 30,
    isActive = function(phase)
        return phase ~= "simulationTick"
            or (
                server.weaponGroupUsesController("kineticArtillery")
                and server.lSlotStateNeedsTick()
            )
    end,
    init = function(shipType)
        server.lSlotStateInit(shipType)
    end,
    rebuildReset = function()
        server.lSlotStateResetRuntime()
    end,
    rebuildInit = function(shipType)
        server.lSlotStateInit(shipType)
    end,
    simulationTick = function(dt)
        server.lSlotControlTick(dt)
    end,
    deactivate = function()
        server.lSlotStateSetRequestFire(false)
        server.lSlotStateResetRuntime()
        server.lSlotStatePushHudReset(true)
    end,
    clearCommands = function()
        server.lSlotStateSetRequestFire(false)
    end,
})

_register("specialized.guidedProjectile", {
    initOrder = 60,
    rebuildResetOrder = 60,
    simulationTickOrder = 60,
    updateOrder = 10,
    postUpdateOrder = 10,
    deactivateOrder = 60,
    isActive = function(phase)
        if phase == "init" or phase == "rebuildReset" or phase == "deactivate" then
            return true
        end
        return #(((server.guidedProjectileRuntimeState or {}).activeProjectiles) or {}) > 0
    end,
    init = function()
        server.guidedProjectileRuntimeInit()
    end,
    rebuildReset = function()
        server.guidedProjectileRuntimeInit()
    end,
    simulationTick = function(dt)
        server.guidedProjectileRuntimeTick(dt)
    end,
    update = function(dt)
        server.guidedProjectileMovementUpdate(dt)
    end,
    postUpdate = function()
        server.guidedProjectileColliderPostUpdate()
    end,
    deactivate = function()
        server.guidedProjectileRuntimeInit()
    end,
})

_register("specialized.guidedSalvo", {
    initOrder = 70,
    rebuildResetOrder = 30,
    rebuildInitOrder = 30,
    simulationTickOrder = 40,
    deactivateOrder = 40,
    isActive = function(phase)
        return phase ~= "simulationTick"
            or (
                server.weaponGroupUsesController("guidedSalvo")
                and server.guidedSlotGroupNeedsTick("mSlot")
            )
    end,
    init = function(shipType)
        server.mSlotControlInit(shipType)
    end,
    rebuildReset = function()
        server.mSlotControlResetRuntime()
    end,
    rebuildInit = function(shipType)
        server.mSlotControlInit(shipType)
    end,
    simulationTick = function(dt)
        server.mSlotControlTick(dt)
    end,
    deactivate = function()
        server.mSlotControlResetRuntime()
    end,
    clearCommands = function()
        server.guidedSlotGroupClearRequest("mSlot")
    end,
})

_register("specialized.torpedoSalvo", {
    initOrder = 80,
    rebuildResetOrder = 40,
    rebuildInitOrder = 40,
    simulationTickOrder = 50,
    deactivateOrder = 50,
    isActive = function(phase)
        return phase ~= "simulationTick"
            or (
                server.weaponGroupUsesController("torpedoSalvo")
                and server.guidedSlotGroupNeedsTick("gSlot")
            )
    end,
    init = function(shipType)
        server.gSlotControlInit(shipType)
    end,
    rebuildReset = function()
        server.gSlotControlResetRuntime()
    end,
    rebuildInit = function(shipType)
        server.gSlotControlInit(shipType)
    end,
    simulationTick = function(dt)
        server.gSlotControlTick(dt)
    end,
    deactivate = function()
        server.gSlotControlResetRuntime()
    end,
    clearCommands = function()
        server.guidedSlotGroupClearRequest("gSlot")
    end,
})

_register("specialized.strikeCraft", {
    initOrder = 90,
    rebuildResetOrder = 50,
    rebuildInitOrder = 50,
    simulationTickOrder = 70,
    deactivateOrder = 70,
    isActive = function(phase)
        return phase ~= "simulationTick"
            or (
                server.weaponGroupUsesController("strikeCraft")
                and server.hSlotStateNeedsTick()
            )
    end,
    init = function(shipType)
        server.hSlotStateInit(shipType)
    end,
    rebuildReset = function()
        server.hSlotStateResetRuntime()
    end,
    rebuildInit = function(shipType)
        server.hSlotStateInit(shipType)
    end,
    simulationTick = function(dt)
        server.hSlotControlTick(dt)
    end,
    deactivate = function()
        server.hSlotStateResetRuntime()
    end,
    clearCommands = function()
        server.hSlotControlSetFireRequested(false)
    end,
})

_register("weapon.group", {
    initOrder = 100,
    rebuildInitOrder = 60,
    commandTickOrder = 20,
    deactivateOrder = 5,
    isActive = function(phase)
        return phase ~= "commandTick" or server.weaponGroupNeedsTick()
    end,
    init = function(shipType)
        server.weaponGroupInit(shipType)
    end,
    rebuildInit = function(shipType)
        server.weaponGroupInit(shipType)
    end,
    commandTick = function(dt)
        server.weaponGroupTick(dt)
    end,
    deactivate = function()
        server.weaponGroupClearFireHeld()
        server.weaponGroupReset()
    end,
    clearCommands = function()
        server.weaponGroupClearFireHeld()
    end,
})

_register("weapon.projectileManager", {
    rebuildResetOrder = 70,
    simulationTickOrder = 80,
    deactivateOrder = 80,
    isActive = function(phase)
        if phase == "rebuildReset" or phase == "deactivate" then return true end
        return #(((server.projectileManagerState or {}).active) or {}) > 0
    end,
    rebuildReset = function()
        server.projectileManagerReset()
    end,
    simulationTick = function(dt)
        server.projectileManagerTick(dt)
    end,
    deactivate = function()
        server.projectileManagerReset()
    end,
})

local function _registerController(controllerType, controller)
    local ok, err = server.weaponControllerRegister(controllerType, controller)
    if not ok then
        error("weapon controller registration failed: " .. tostring(err))
    end
end

_registerController("chargedSpinal", {
    ownsHud = true,
    ownsHold = true,
    requestFire = function()
        server.xSlotStateSetRequestFire(true)
        return true
    end,
    setHeld = function(context, held)
        server.xSlotStateSetHoldRequested(held)
        if not held then
            server.xSlotStateSetReleaseRequested(true)
        end
        return true, nil
    end,
})

_registerController("kineticArtillery", {
    ownsHud = true,
    requestFire = function()
        server.lSlotStateSetRequestFire(true)
        return true
    end,
    onSelected = function()
        server.lSlotStatePushHud(true)
    end,
})

_registerController("guidedSalvo", {
    ownsHud = true,
    requestFire = function(context)
        local request = context.request or {}
        return server.mSlotControlSetFireRequest(
            request.shipBodyId,
            request.targetVehicleId,
            request.targetBodyId
        )
    end,
})

_registerController("strikeCraft", {
    ownsHud = true,
    requestFire = function(context)
        server.hSlotLastFireRequest = context.request or {}
        server.hSlotControlSetFireRequested(true)
        return true
    end,
})
