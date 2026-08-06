---@diagnostic disable: undefined-global

client = client or {}

local function _paths(weaponType, stem, count)
    local result = {}
    for i = 1, count do
        result[i] = string.format(
            "MOD/sound/weapons/%s/%s_%02d.ogg",
            weaponType,
            stem,
            i
        )
    end
    return result
end

local function _one(weaponType, name)
    return { string.format("MOD/sound/weapons/%s/%s.ogg", weaponType, name) }
end

local function _direct(path)
    return { "MOD/sound/" .. path }
end

local function _append(first, second)
    local result = {}
    for i = 1, #(first or {}) do result[#result + 1] = first[i] end
    for i = 1, #(second or {}) do result[#result + 1] = second[i] end
    return result
end

local function _laserProfile(weaponType)
    return {
        fireNear = _paths(weaponType, "laser_fire", 6),
        fireFar = _paths(weaponType, "distance_laser_fire", 6),
        hitNear = _one(weaponType, "laser_hit_01"),
        hitFar = _paths(weaponType, "distance_laser_hit", 4),
    }
end

local function _genericLaserProfile()
    return {
        fireNear = {
            "MOD/sound/laser_fire_01.ogg",
            "MOD/sound/laser_fire_02.ogg",
            "MOD/sound/laser_fire_03.ogg",
        },
        fireFar = {
            "MOD/sound/laser_fire_01.ogg",
            "MOD/sound/laser_fire_02.ogg",
            "MOD/sound/laser_fire_03.ogg",
        },
        hitNear = _direct("laser_hit_01.ogg"),
        hitFar = _direct("laser_hit_01.ogg"),
    }
end

local function _plasmaProfile(weaponType)
    return {
        fireNear = _paths(weaponType, "plasma_fire", 4),
        fireFar = _paths(weaponType, "distance_plasma_fire", 4),
        hitNear = _one(weaponType, "plasma_hit_01"),
        hitFar = _one(weaponType, "distance_plasma_hit_01"),
    }
end

local function _massDriverProfile(weaponType)
    return {
        fireNear = _one(weaponType, "mass_driver_fire_01"),
        fireFar = _one(weaponType, "distance_mass_driver_fire_01"),
        hitNear = _one(weaponType, "mass_driver_hit_01"),
        hitFar = _one(weaponType, "distance_mass_driver_hit_01"),
    }
end

client.weaponSoundCatalog = {
    laser = _genericLaserProfile(),
    perditionBeam = {
        windupNear = {
            "MOD/sound/perdition_beam_windup_01.ogg",
            "MOD/sound/perdition_beam_windup_02.ogg",
        },
        windupFar = {
            "MOD/sound/perdition_beam_windup_01.ogg",
            "MOD/sound/perdition_beam_windup_02.ogg",
        },
        fireNear = {
            "MOD/sound/perdition_beam_fire_01.ogg",
            "MOD/sound/perdition_beam_fire_02.ogg",
            "MOD/sound/perdition_beam_fire_03.ogg",
        },
        fireFar = {
            "MOD/sound/distance_perdition_beam_fire_01.ogg",
            "MOD/sound/distance_perdition_beam_fire_02.ogg",
            "MOD/sound/distance_perdition_beam_fire_03.ogg",
        },
        hitNear = _direct("perdition_beam_hit_01.ogg"),
        hitFar = _direct("distance_perdition_beam_hit_01.ogg"),
    },
    tachyonLance = {
        windupNear = _one("tachyonLance", "tachyon_lance_windup_01"),
        windupFar = _one("tachyonLance", "distance_tachyon_lance_windup_01"),
        fireNear = _paths("tachyonLance", "tachyon_lance_fire", 3),
        fireFar = _paths("tachyonLance", "distance_tachyon_lance_fire", 3),
        hitNear = _append(
            _paths("tachyonLance", "tachyon_lance_hit", 2),
            _one("tachyonLance", "tachyon_lance_hit_03wav")
        ),
        hitFar = _paths("tachyonLance", "distance_tachyon_lance_hit", 3),
    },
    focusedArcEmitter = {
        windupNear = _one("focusedArcEmitter", "arc_emitter_windup_01"),
        windupFar = _one("focusedArcEmitter", "distance_arc_emitter_windup_01"),
        fireNear = _paths("focusedArcEmitter", "xl_arc_emitter_fire", 4),
        fireFar = _paths("focusedArcEmitter", "distance_xl_arc_emitter_fire", 4),
        hitNear = {},
        hitFar = {},
    },
    gigaCannon = {
        fireNear = _paths("gigaCannon", "adv_kinectic_fire", 3),
        fireFar = _one("gigaCannon", "distance_adv_kinectic_fire_01"),
        hitNear = _one("gigaCannon", "adv_kinectic_hit_01"),
        hitFar = _one("gigaCannon", "distance_adv_kinectic_hit_01"),
    },
    largeGammaLaser = _laserProfile("largeGammaLaser"),
    mediumGammaLaser = _laserProfile("mediumGammaLaser"),
    largePlasmaCannon = _plasmaProfile("largePlasmaCannon"),
    mediumPlasmaCannon = _plasmaProfile("mediumPlasmaCannon"),
    largeGaussCannon = _massDriverProfile("largeGaussCannon"),
    mediumGaussCannon = _massDriverProfile("mediumGaussCannon"),
    kineticArtillery = {
        fireNear = _one("kineticArtillery", "kinectic_artillery_fire_01"),
        fireFar = _one("kineticArtillery", "distance_kinectic_artillery_fire_01"),
        hitNear = _one("kineticArtillery", "kinectic_artillery_hit_01"),
        hitFar = _one("kineticArtillery", "distance_kinectic_artillery_hit_01"),
    },
    largeStormfireAutocannon = {
        fireNear = _one("largeStormfireAutocannon", "auto_cannon_fire_large_01"),
        fireFar = _one("largeStormfireAutocannon", "distance_auto_cannon_fire_large_01"),
        hitNear = _one("largeStormfireAutocannon", "auto_cannon_hit_large"),
        hitFar = _one("largeStormfireAutocannon", "distance_auto_cannon_hit_large"),
    },
    mediumStormfireAutocannon = {
        fireNear = _one("mediumStormfireAutocannon", "auto_cannon_fire_medium_01"),
        fireFar = _one("mediumStormfireAutocannon", "distance_auto_cannon_fire_medium_01"),
        hitNear = _one("mediumStormfireAutocannon", "auto_cannon_hit_medium"),
        hitFar = _one("mediumStormfireAutocannon", "distance_auto_cannon_hit_medium"),
    },
    phaseDisruptor = {
        fireNear = _paths("phaseDisruptor", "disruptor_fire", 3),
        fireFar = _paths("phaseDisruptor", "distance_disruptor_fire", 3),
        hitNear = _paths("phaseDisruptor", "disruptor_hit", 6),
        hitFar = _paths("phaseDisruptor", "distance_disruptor_hit", 6),
    },
    swarmerMissile = {
        fireNear = _paths("swarmerMissile", "swarmer_missile_fire", 3),
        fireFar = _one("swarmerMissile", "distance_swarmer_missile_fire_01"),
        hitNear = _one("swarmerMissile", "swarmer_missile_hit_01"),
        hitFar = _one("swarmerMissile", "distance_swarmer_missile_hit_01"),
    },
    devastatorTorpedoes = {
        fireNear = _paths("devastatorTorpedoes", "torpedo_fire", 3),
        fireFar = _paths("devastatorTorpedoes", "distance_torpedo_fire", 3),
        hitNear = _one("devastatorTorpedoes", "torpedo_hit_01"),
        hitFar = _one("devastatorTorpedoes", "distance_torpedo_hit_01"),
    },
    neutronLauncher = {
        fireNear = _paths("neutronLauncher", "energy_torpedo_fire", 3),
        fireFar = _paths("neutronLauncher", "distance_energy_torpedo_fire", 3),
        hitNear = _one("neutronLauncher", "energy_torpedo_hit_01"),
        hitFar = _one("neutronLauncher", "distance_energy_torpedo_hit_01"),
    },
    gammaStrikeCraft = _laserProfile("gammaStrikeCraft"),
}
