---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.missileLaunchFxConfig = client.missileLaunchFxConfig or {
    particleCount = 80,
    particleRadius = 0.8,
    particleLife = 0.2,
    emissive = 80.0,
    color = { 0.2, 0.5, 1.0, 1.0 },
    innerRadius = 0.3,
    outerRadius = 2.5,
}

client.missileLaunchFxState = client.missileLaunchFxState or {
    effects = {},
}

function client.spawnMissileLaunchFx(x, y, z)
    local cfg = client.missileLaunchFxConfig
    table.insert(client.missileLaunchFxState.effects, {
        position = Vec(x or 0, y or 0, z or 0),
        life = cfg.particleLife,
        maxLife = cfg.particleLife,
    })
end

function client.missileLaunchFxTick(dt)
    local effects = client.missileLaunchFxState.effects
    local cfg = client.missileLaunchFxConfig
    local i = #effects
    while i >= 1 do
        local effect = effects[i]
        effect.life = effect.life - dt
        
        if effect.life > 0 then
            local progress = effect.life / effect.maxLife
            local radius = cfg.innerRadius + (cfg.outerRadius - cfg.innerRadius) * (1 - progress)
            
            ParticleReset()
            ParticleColor(cfg.color[1], cfg.color[2], cfg.color[3], cfg.color[1], cfg.color[2], cfg.color[3])
            ParticleRadius(cfg.particleRadius, 0.0, "easeout")
            ParticleAlpha(1.0, 0.0)
            ParticleGravity(0.0)
            ParticleDrag(0.1)
            ParticleEmissive(cfg.emissive, 0.0)
            ParticleCollide(0.0)
            
            for j = 1, cfg.particleCount do
                local angle1 = math.random() * math.pi * 2
                local angle2 = math.acos(2 * math.random() - 1)
                local x = math.sin(angle2) * math.cos(angle1)
                local y = math.sin(angle2) * math.sin(angle1)
                local z = math.cos(angle2)
                local dir = Vec(x, y, z)
                local pos = VecAdd(effect.position, VecScale(dir, radius))
                local vel = VecScale(dir, 2.0)
                SpawnParticle(pos, vel, cfg.particleLife)
            end
        else
            table.remove(effects, i)
        end
        
        i = i - 1
    end
end