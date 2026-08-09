---@diagnostic disable: undefined-global
client = client or {}
client.weaponFxResources = client.weaponFxResources or { soft = 0, ring = 0 }
function client.weaponFxResourcesInit()
    client.weaponFxResources.soft = LoadSprite("MOD/gfx/weapons/tachyon_lance/beam_soft.png")
    client.weaponFxResources.ring = LoadSprite("MOD/gfx/weapons/projectiles/impact_glow.png")
end
