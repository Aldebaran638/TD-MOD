#version 2
#include "script/include/common.lua"

#include "script/data/components/component_catalog.lua"
#include "script/data/ships/ship_catalog.lua"
#include "script/data/weapons/weapon_catalog.lua"
#include "script/weapon/client/config_ui/local_weapon_config.lua"
#include "script/weapon/client/config_ui/weapon_config_ui.lua"

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}
server = server or {}

local _starfield = {
    sprite = 0,
    stars = {},
}

local function _starValue(index, salt)
    local value = math.sin(index * 12.9898 + salt * 78.233) * 43758.5453
    return value - math.floor(value)
end

local function _buildStarfield()
    _starfield.stars = {}
    -- A deterministic shell avoids flicker and keeps every multiplayer client aligned.
    for index = 1, 180 do
        local azimuth = _starValue(index, 1) * math.pi * 2.0
        local elevation = (_starValue(index, 2) * 2.0 - 1.0) * 0.72
        local radial = 245.0 + _starValue(index, 3) * 55.0
        local horizontal = math.cos(elevation) * radial
        _starfield.stars[index] = {
            x = math.cos(azimuth) * horizontal,
            y = 42.0 + math.sin(elevation) * radial,
            z = math.sin(azimuth) * horizontal,
            size = 0.035 + _starValue(index, 4) * 0.075,
            tint = 0.68 + _starValue(index, 5) * 0.32,
            alpha = 0.42 + _starValue(index, 6) * 0.48,
        }
    end
end

function server.init()
    SetEnvironmentDefault()
    SetEnvironmentProperty("skybox", "cloudy.dds")
    SetEnvironmentProperty("skyboxbrightness", 0.018)
    SetEnvironmentProperty("fogColor", 0.008, 0.012, 0.024)
    SetEnvironmentProperty("fogParams", 80, 420, 0.94, 1.2)
    SetEnvironmentProperty("exposure", 0.85, 5)
    SetEnvironmentProperty("nightlight", true)
    SetEnvironmentProperty("ambience", "outdoor/night.ogg")
    SetPostProcessingDefault()
    SetPostProcessingProperty("gamma", 0.9)
    SetPostProcessingProperty("bloom", 1.25)
end

function client.init()
    SetBool("level.stellarisships.weaponconfig.contenthost", true)
    client.weaponConfigUiSetOpen(false)
    _starfield.sprite = LoadSprite("MOD/gfx/weapons/projectiles/impact_glow.png")
    _buildStarfield()
end

function client.tick(dt)
    client.weaponConfigUiTick(dt)
end

function client.draw()
    if math.floor(_starfield.sprite or 0) ~= 0 then
        local camera = GetCameraTransform()
        for _, star in ipairs(_starfield.stars) do
            local position = Vec(camera.pos[1] + star.x, camera.pos[2] + star.y, camera.pos[3] + star.z)
            local transform = Transform(position, QuatLookAt(position, camera.pos))
            DrawSprite(
                _starfield.sprite,
                transform,
                star.size,
                star.size,
                star.tint,
                star.tint * 0.96,
                1.0,
                star.alpha,
                true,
                true,
                false
            )
        end
    end
    client.weaponConfigUiDraw()
end
