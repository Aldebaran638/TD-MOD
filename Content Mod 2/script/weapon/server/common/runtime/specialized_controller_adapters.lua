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
            or server.mainWeaponControlHasPendingRequests()
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

-- Compatibility component retained for the runtime contract. Current kinetic
-- artillery uses the generic group runtime, so this stays inactive unless a
-- future weapon explicitly opts into the legacy controller.
_register("specialized.kineticArtillery", {
    isActive = function()
        return server.weaponGroupUsesController("kineticArtillery")
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
                and server.guidedSlotGroupNeedsAnyTick()
            )
    end,
    init = function(shipType)
        server.mSlotControlInit(shipType)
    end,
    rebuildReset = function()
        server.guidedSlotGroupResetAll()
    end,
    rebuildInit = function(shipType)
        server.mSlotControlInit(shipType)
    end,
    simulationTick = function(dt)
        server.guidedSlotGroupTickAll(dt)
    end,
    deactivate = function()
        server.guidedSlotGroupResetAll()
    end,
    clearCommands = function()
        for mode in pairs(server.guidedSlotGroupStateByMode or {}) do
            server.guidedSlotGroupClearRequest(mode)
        end
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

_register("specialized.pointDefense", {
    initOrder = 95,
    rebuildResetOrder = 55,
    rebuildInitOrder = 55,
    simulationTickOrder = 75,
    deactivateOrder = 75,
    isActive = function(phase)
        return phase == "init" or phase == "rebuildReset"
            or phase == "rebuildInit" or phase == "deactivate"
            or server.pointDefenseNeedsTick()
    end,
    init = function(shipType)
        server.pointDefenseInit(shipType)
    end,
    rebuildReset = function()
        server.pointDefenseReset()
    end,
    rebuildInit = function(shipType)
        server.pointDefenseInit(shipType)
    end,
    simulationTick = function(dt)
        server.pointDefenseTick(dt)
    end,
    deactivate = function()
        server.pointDefenseReset()
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

-- chargedRay is a capability marker.  Its lifecycle is owned by the generic
-- weapon-group runtime so X and T groups share one charge/release path.
_registerController("chargedRay", {
    delegatesToWeaponGroup = true,
    requestFire = function()
        return false, "chargedRay is handled by weapon-group runtime"
    end,
})

_register("specialized.chargedRayVisual", {
    initOrder = 30,
    rebuildResetOrder = 80,
    simulationTickOrder = 20,
    deactivateOrder = 20,
    isActive = function(phase)
        return phase ~= "simulationTick"
            or server.weaponGroupUsesWeaponClass("chargedRay")
    end,
    init = function()
        if server.xSlotRenderStateInit ~= nil then server.xSlotRenderStateInit() end
        server.chargedRayVisualInit()
    end,
    rebuildReset = function()
        server.chargedRayVisualStopAll()
    end,
    simulationTick = function(dt)
        server.chargedRayVisualTick(dt)
    end,
    deactivate = function()
        server.chargedRayVisualStopAll()
    end,
})

_registerController("guidedSalvo", {
    ownsHud = true,
    requestFire = function(context)
        local request = context.request or {}
        server.guidedSlotGroupEnsure(
            context.groupId,
            ((context.state or {}).mountCollection),
            server.shipContextGetType()
        )
        return server.guidedSlotGroupSetFireRequest(
            context.groupId,
            request.shipBodyId,
            request.targetVehicleId,
            request.targetBodyId
        )
    end,
})

_registerController("strikeCraft", {
    ownsHud = true,
    requestFire = function(context)
        local request = context.request or {}
        request.groupId = context.groupId
        server.hSlotLastFireRequest = request
        server.hSlotControlSetFireRequested(true)
        return true
    end,
})
