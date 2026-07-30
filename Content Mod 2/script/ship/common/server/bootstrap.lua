---@diagnostic disable: undefined-global

#include "runtime_context.lua"
#include "state/runtime_state.lua"
#include "state/runtime_state_api.lua"
#include "registry/ship_registry.lua"
#include "network/request_authorizer.lua"
#include "network/control_snapshot_endpoint.lua"
#include "lifecycle/ship_destructibility.lua"
#include "bootstrap/ship_init.lua"
#include "damage/ship_damage.lua"
#include "damage/external_damage.lua"
#include "movement/body_mass_upward_move.lua"
#include "movement/body_directional_move.lua"
#include "movement/body_move_state_receive.lua"
#include "movement/body_velocity_quadratic_damping.lua"
#include "movement/ship_attitude_controller.lua"
#include "movement/ship_roll_stabilizer.lua"
#include "lifecycle/ship_death_explosion.lua"
#include "lifecycle/ship_hp_recovery.lua"

server = server or {}

function server.shipServerInit(shipType)
    server.shipInitInit(shipType)
    local body = server.shipContextGetBody()
    server.runtimeStateInit(body, shipType, shipType)
    return body
end

function server.shipServerTick(dt)
    server.runtimeStateTick(dt)
    server.shipExternalDamageTick(dt)
    server.shipHpRecoveryTick(dt)
    server.shipDeathExplosionTick(dt)
    server.bodyMoveStateReceiveTick(dt)
    server.bodyMassUpwardMoveTick(dt)
    server.bodyDirectionalMoveTick(dt)
    server.bodyVelocityQuadraticDampingTick(dt)
end

function server.shipServerUpdate(dt)
    server.shipAttitudeControllerUpdate(dt)
    server.shipRollStabilizerUpdate(dt)
end
