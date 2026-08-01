---@diagnostic disable: undefined-global

#include "runtime_context.lua"
#include "state/runtime_state.lua"
#include "state/runtime_state_api.lua"
#include "registry/ship_registry.lua"
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
    server.shipDeathExplosionTick(0.0)
    state.destroyedFinalized = true
end

function server.shipServerInit(shipType)
    server.shipServerLifecycleState.destroyedFinalized = false
    server.shipInitInit(shipType)
    local body = server.shipContextGetBody()
    server.runtimeStateInit(body, shipType, shipType)
    -- Weapon slot state is not part of the shared ship bootstrap.  Interceptor
    -- scripts intentionally omit the weapon bootstrap, so keep component and
    -- HP initialization usable for those entities as well.
    if server.slotLoadoutInit ~= nil then
        server.slotLoadoutInit(shipType)
    end
    local applied, applyError = server.shipComponentApplyDefault(shipType)
    if not applied then
        DebugPrint("[shipComponents] default profile failed: " .. tostring(applyError or "unknown"))
        -- Keep the physical protection contract alive even when an old local
        -- loadout has an invalid power balance; the configuration UI can fix
        -- the loadout on the next bind.
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
    return body
end

function server.shipServerTick(dt)
    if server.shipServerIsDestroyed() then
        server.shipServerFinalizeDestroyed()
        return
    end
    server.runtimeStateTick(dt)
    server.shipPlayerProtectionTick()
    server.shipExternalDamageTick(dt)
    if server.shipServerIsDestroyed() then
        server.shipServerFinalizeDestroyed()
        return
    end
    server.shipHpRecoveryTick(dt)
    server.shipCloakTick(dt)
    server.shipDeathExplosionTick(dt)
    server.bodyMoveStateReceiveTick(dt)
    server.bodyMassUpwardMoveTick(dt)
    server.bodyDirectionalMoveTick(dt)
    server.bodyVelocityQuadraticDampingTick(dt)
    server.bodyCombatSpeedLimitTick(dt)
end

function server.shipServerUpdate(dt)
    if server.shipServerIsDestroyed() then return end
    server.shipAttitudeControllerUpdate(dt)
    server.shipRollStabilizerUpdate(dt)
end

function server.shipServerPostUpdate()
    if server.shipServerIsDestroyed() then return end
    server.shipPlayerProtectionPostUpdate()
end
