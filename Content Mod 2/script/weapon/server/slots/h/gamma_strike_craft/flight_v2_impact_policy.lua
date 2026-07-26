---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

-- H-slot beams still create a physical impact explosion against terrain,
-- ordinary vehicles and other non-Stellaris targets. Registered/tagged
-- Stellaris ships receive registry damage and visual impact effects only.
local function _hSlotV2ImpactIsStellarisShip(hitBody, hitShape)
    local body = math.floor(hitBody or 0)
    local shape = math.floor(hitShape or 0)
    if body ~= 0 and server.registryShipExists ~= nil
        and server.registryShipExists(body) then
        return true
    end
    if HasTag ~= nil then
        if body ~= 0 and HasTag(body, "stellarisShip") then return true end
        if shape ~= 0 and HasTag(shape, "stellarisShip") then return true end
    end
    return false
end

function server.hSlotV2FireBeam(shipBody, craft, targetCenter, config)
    server.hSlotV2BumpCounter(shipBody, "beam_fire")
    local origin = VecAdd(
        craft.pos or targetCenter,
        VecScale(
            craft.forward or Vec(0, 0, -1),
            math.max(0.1, tonumber(config.muzzleForwardOffset) or 1.2)
        )
    )
    local direction = server.hSlotV2Normalize(
        VecSub(targetCenter, origin), craft.forward or Vec(0, 0, -1)
    )
    local maxRange = math.max(1.0, tonumber(config.maxRange) or 160.0)

    QueryRequire("physical")
    QueryRejectBody(shipBody)
    QueryRejectBody(craft.bodyId)
    local hit, distance, _, shape = QueryRaycast(origin, direction, maxRange, 0.05)
    local endPosition = hit
        and VecAdd(origin, VecScale(direction, distance))
        or VecAdd(origin, VecScale(direction, maxRange))
    local hitBody = hit and shape ~= nil and shape ~= 0 and GetShapeBody(shape) or 0
    local hitStellarisShip = hit and _hSlotV2ImpactIsStellarisShip(hitBody, shape)

    if hitStellarisShip and server.registryShipExists(hitBody) then
        local registeredTargetCenter = server.hSlotV2GetBodyCenter(hitBody)
        local shieldRadius = server.hSlotV2ResolveTargetShieldRadius(
            hitBody, server.defaultShipType or "enigmaticCruiser"
        )
        if registeredTargetCenter ~= nil then
            local entryDistance = server.hSlotV2RaySphereEntry(
                origin, direction, registeredTargetCenter, shieldRadius
            )
            if entryDistance ~= nil and entryDistance <= maxRange then
                endPosition = VecAdd(origin, VecScale(direction, entryDistance))
            end
        end
    end

    local didHitShield = false
    if hit then
        didHitShield = server.hSlotV2ApplyBeamDamage(
            endPosition, hitBody, craft.weaponType or "gammaStrikeCraft"
        )

        -- Explosion is intentionally restricted to non-Stellaris impacts.
        if not hitStellarisShip then
            local explosionSize = math.max(
                0.0, tonumber(config.beamImpactExplosionSize) or 0.0
            )
            local minimumDistance = math.max(
                0.0, tonumber(config.beamImpactExplosionMinDistance) or 0.0
            )
            if explosionSize > 0.0
                and VecLength(VecSub(endPosition, origin)) >= minimumDistance then
                local impulse = math.max(
                    0.0, tonumber(config.beamImpactExplosionImpulse) or 0.0
                )
                if impulse > 0.0 then
                    Explosion(endPosition, explosionSize, impulse)
                else
                    Explosion(endPosition, explosionSize)
                end
            end
        end

        ClientCall(
            0, "client.playWeaponSound",
            craft.weaponType or "gammaStrikeCraft", "hit",
            endPosition[1], endPosition[2], endPosition[3]
        )
    end

    ClientCall(0, "client.playHSlotGammaFireSound", origin[1], origin[2], origin[3])
    ClientCall(
        0, "client.spawnHSlotBeamFx",
        origin[1], origin[2], origin[3],
        endPosition[1], endPosition[2], endPosition[3],
        didHitShield and 1 or 0,
        config.beamLife or 0.08,
        config.beamWidth or 0.16
    )
    if didHitShield and hitBody ~= 0 then
        ClientCall(
            0, "client.playProjectileShieldImpactFx", hitBody,
            endPosition[1], endPosition[2], endPosition[3]
        )
    end
end
