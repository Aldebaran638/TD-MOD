---@diagnostic disable: undefined-global

#include "../../../weapon/client/config_ui/local_weapon_config.lua"
#include "runtime_context.lua"
#include "config/weapon_configuration_binding.lua"
#include "registry/ship_registry.lua"
#include "../../../net/client_input_snapshot.lua"
#include "state/ship_runtime_state.lua"
#include "state/ship_runtime_state_api.lua"
#include "input/body_move_input.lua"
#include "camera/ship_camera.lua"
#include "hud/ship_roll_error.lua"
#include "hud/ship_health_bar.lua"
#include "hud/ship_help_overlay.lua"
#include "hud/native_vehicle_hud.lua"
#include "hud/ship_sensor_hud.lua"
#include "hud/ship_cloak.lua"
#include "effects/ship_destroyed_fx.lua"
#include "effects/engine_thruster_fx.lua"

client = client or {}

function client.shipClientInit(shipType)
    local context = client.shipContextInit(shipType, "stellarisShip")
    client.shipCameraApplyProfile()
    client.shipRuntimeStateInit()
    client.shipControlSnapshotInit(context.bodyId)
    client.engineThrusterFxInit()
    client.weaponConfigurationBindingInit(context.shipType, context.bodyId)
    client.shipSensorHudInit()
end

function client.shipClientBeforeWeaponTick(dt)
    client.weaponConfigurationBindingTick(dt)
end

function client.shipClientAfterWeaponTick(dt)
    client.bodyMoveInputTick(dt)
    client.shipDestroyedFxTick(dt)
    client.engineThrusterFxTick(dt)
    client.shipControlSnapshotTick(dt)
    client.shipHealthBarTick(dt)
    client.shipHelpOverlayTick(dt)
    client.shipSensorHudTick(dt)
    client.shipCloakInputTick()
end

function client.shipClientRender()
    client.shipCameraTick(0)
    client.shipRollErrorTick(0)
end

function client.shipClientRenderEffects()
    client.engineThrusterFxRender()
end

function client.shipClientDrawHealth()
    client.shipHealthBarDraw()
end

function client.shipClientDrawHelp()
    client.shipHelpOverlayDraw()
end

function client.shipClientDrawSensors()
    client.shipSensorHudDraw()
    client.shipCloakDraw()
end

function client.shipClientSuppressNativeHud()
    client.nativeVehicleHudSuppressDraw()
end
