---@diagnostic disable: undefined-global

#include "runtime_context.lua"
#include "state/runtime_state.lua"
#include "state/runtime_state_api.lua"
#include "registry/ship_registry.lua"
#include "components/interceptor_runtime_v1.lua"
#include "components/ship_components.lua"
#include "lifecycle/ship_cloak.lua"
#include "network/request_authorizer.lua"
#include "network/control_snapshot_endpoint.lua"
#include "lifecycle/ship_destructibility.lua"
#include "lifecycle/player_protection.lua"
#include "bootstrap/ship_init.lua"
#include "damage/ship_damage.lua"
#include "damage/external_damage.lua"
#include "movement/body_mass_upward_move.lua"
#include "movement/body_directional_move.lua"
#include "movement/body_move_state_receive.lua"
#include "movement/body_velocity_quadratic_damping.lua"
#include "movement/body_combat_speed_limit.lua"
#include "movement/ship_attitude_controller.lua"
#include "movement/ship_roll_stabilizer.lua"
#include "lifecycle/ship_death_explosion.lua"
#include "lifecycle/ship_hp_recovery.lua"

server = server or {}

server.shipServerLifecycleState = server.shipServerLifecycleState or {
    destroyedFinalized = false,
}

local function _shipServerIsPlayerControlled()
    return shipDefinitionIsPlayerControlled(
        server.shipContextGetDefinition() or {}
    )
end

function server.shipServerIsDestroyed()
    local body = server.shipContextGetBody()
    return body ~= 0
        and server.registryShipExists ~= nil
        and server.registryShipExists(body)
        and server.registryShipIsBodyDead ~= nil
        and server.registryShipIsBodyDead(body)
end

function server.shipServerFinalizeDestroyed()
    local state = server.shipServerLifecycleState
    if state.destroyedFinalized then return end
    local body = server.shipContextGetBody()
    server.shipDeathExplosionTick(0.0)
    state.destroyedFinalized = true
    if server.cm2TelemetryRecord ~= nil then
        server.cm2TelemetryRecord("ship_cleanup", {
            body_id = math.floor(tonumber(body) or 0),
            destroyed = true,
            runtime_deactivated = true,
        })
    end
end

function server.shipServerInit(shipType, bodyTag)
    server.shipServerLifecycleState.destroyedFinalized = false
    server.shipInitInit(shipType, bodyTag)
    local body = server.shipContextGetBody()
    server.runtimeStateInit(body, shipType, shipType)
    if _shipServerIsPlayerControlled() then
        if server.slotLoadoutInit ~= nil then
            server.slotLoadoutInit(shipType)
        end
        local applied, applyError = server.shipComponentApplyDefault(shipType)
        if not applied then
            DebugPrint("[shipComponents] default profile failed: " .. tostring(applyError or "unknown"))
            local definition = server.shipContextGetDefinition() or {}
            local fallbackLoadout, fallbackConfiguration =
                shipComponentDefaultLoadout(definition)
            local fallbackState = server.shipSlotLoadoutGetState(shipType) or {}
            local fallbackProfile = shipComponentResolveProfile(
                definition,
                fallbackLoadout,
                fallbackConfiguration,
                fallbackState.loadout
            )
            server.shipRuntimeSetComponentProfile(body, fallbackProfile)
            server.shipComponentProfile = fallbackProfile
            server.registryShipSetProtectionProfile(
                body,
                (fallbackProfile or {}).protection,
                true
            )
        end
        server.shipCloakInit()
    end
    return body
end

function server.shipServerTick(dt)
    if server.shipServerIsDestroyed() then
        server.shipServerFinalizeDestroyed()
        return
    end
    server.runtimeStateTick(dt)
    if _shipServerIsPlayerControlled() then
        server.shipPlayerProtectionTick()
    end
    server.shipExternalDamageTick(dt)
    if server.shipServerIsDestroyed() then
        server.shipServerFinalizeDestroyed()
        return
    end
    server.shipHpRecoveryTick(dt)
    server.shipDeathExplosionTick(dt)
    if _shipServerIsPlayerControlled() then
        server.shipCloakTick(dt)
        server.bodyMoveStateReceiveTick(dt)
        server.bodyMassUpwardMoveTick(dt)
        server.bodyDirectionalMoveTick(dt)
        server.bodyVelocityQuadraticDampingTick(dt)
        server.bodyCombatSpeedLimitTick(dt)
    end
end

function server.shipServerUpdate(dt)
    if server.shipServerIsDestroyed() then return end
    if not _shipServerIsPlayerControlled() then return end
    server.shipAttitudeControllerUpdate(dt)
    server.shipRollStabilizerUpdate(dt)
end

function server.shipServerPostUpdate()
    if server.shipServerIsDestroyed() then return end
    if not _shipServerIsPlayerControlled() then return end
    server.shipPlayerProtectionPostUpdate()
end
