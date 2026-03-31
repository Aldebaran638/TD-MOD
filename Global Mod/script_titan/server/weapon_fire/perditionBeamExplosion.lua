---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.perditionBeamExplosions = server.perditionBeamExplosions or {}

local function _resolveWeaponSettings(weaponType)
    local defs = weaponData or {}
    local resolvedWeaponType = weaponType or "perditionBeam"
    return defs[resolvedWeaponType] or defs.perditionBeam or {}
end

function server.perditionBeamExplosionInit()
    server.perditionBeamExplosions = {}
end

function server.perditionBeamExplosionStart(centerPos, weaponSettings)
    local settings = weaponSettings or _resolveWeaponSettings("perditionBeam")
    
    local explosion = {
        center = centerPos or Vec(0, 0, 0),
        age = 0.0,
        currentWave = 0,
        waveCount = tonumber(settings.explosionWaves) or 10,
        waveInterval = tonumber(settings.explosionWaveInterval) or 0.1,
        explosionRadius = tonumber(settings.explosionRadius) or 4.0,
        explosionStrength = tonumber(settings.explosionStrength) or 1.0,
        firstWaveCount = tonumber(settings.explosionFirstWaveCount) or 6,
        waveRadiusIncrement = tonumber(settings.explosionWaveRadiusIncrement) or 2.0,
        waveCountIncrement = tonumber(settings.explosionWaveCountIncrement) or 3,
        heightLayers = tonumber(settings.explosionHeightLayers) or 5,
        heightSpacing = tonumber(settings.explosionHeightSpacing) or 20.0,
    }
    
    Explosion(explosion.center, explosion.explosionRadius, explosion.explosionStrength)
    
    table.insert(server.perditionBeamExplosions, explosion)
end

function server.perditionBeamExplosionTick(dt)
    local explosions = server.perditionBeamExplosions or {}
    local i = #explosions
    
    while i >= 1 do
        local explosion = explosions[i]
        explosion.age = explosion.age + dt
        
        local expectedWave = math.floor(explosion.age / explosion.waveInterval) + 1
        if expectedWave > explosion.waveCount then
            expectedWave = explosion.waveCount
        end
        
        while explosion.currentWave < expectedWave do
            explosion.currentWave = explosion.currentWave + 1
            
            local waveIndex = explosion.currentWave
            local waveRadius = explosion.waveRadiusIncrement * waveIndex
            local explosionCount = explosion.firstWaveCount + (explosion.waveCountIncrement * (waveIndex - 1))
            
            for layer = 0, explosion.heightLayers - 1 do
                local layerHeight = explosion.center[2] + (layer * explosion.heightSpacing)
                
                for j = 1, explosionCount do
                    local angle = (j / explosionCount) * math.pi * 2.0
                    local offsetX = math.cos(angle) * waveRadius
                    local offsetZ = math.sin(angle) * waveRadius
                    
                    local explosionPos = Vec(
                        explosion.center[1] + offsetX,
                        layerHeight,
                        explosion.center[3] + offsetZ
                    )
                    
                    Explosion(explosionPos, explosion.explosionRadius, explosion.explosionStrength * 0.5)
                end
            end
        end
        
        if explosion.currentWave >= explosion.waveCount then
            table.remove(explosions, i)
        end
        
        i = i - 1
    end
end

function server.perditionBeamExplosionClear()
    server.perditionBeamExplosions = {}
end
