-- Server-side intensity controller for the XML tachyon muzzle point light.
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.tachyonMuzzleLightConfig = server.tachyonMuzzleLightConfig or {
    weaponType = "tachyonLance",
    lightTag = "tachyonMuzzleLight",
    chargeDuration = 0.50,
    chargeStartIntensity = 5.0,
    chargeEndIntensity = 50.0,
    launchPeakIntensity = 100.0,
    launchFlashDuration = 0.03,
    launchFadeDuration = 0.10,
}

server.tachyonMuzzleLightState = server.tachyonMuzzleLightState or {
    light = 0,
    phase = "idle",
    age = 0.0,
}

local function _tachyonLightSmoothStep(value)
    local t = math.max(0.0, math.min(1.0, value))
    return t * t * (3.0 - 2.0 * t)
end

local function _tachyonLightSetIntensity(intensity)
    local light = math.floor(server.tachyonMuzzleLightState.light or 0)
    if light ~= 0 and IsHandleValid(light) then
        SetLightIntensity(light, math.max(0.0, intensity))
    end
end

function server.tachyonMuzzleLightInit()
    local config = server.tachyonMuzzleLightConfig
    local state = server.tachyonMuzzleLightState
    state.light = FindLight(config.lightTag or "tachyonMuzzleLight", false)
    state.phase = "idle"
    state.age = 0.0
    _tachyonLightSetIntensity(0.0)
end

function server.tachyonMuzzleLightBeginCharge(weaponType)
    local config = server.tachyonMuzzleLightConfig
    local state = server.tachyonMuzzleLightState
    if tostring(weaponType or "") == tostring(config.weaponType or "tachyonLance")
        and state.phase ~= "charging" then
        state.phase = "charging"
        state.age = 0.0
    end
end

function server.tachyonMuzzleLightTrigger(weaponType)
    local config = server.tachyonMuzzleLightConfig
    if tostring(weaponType or "") == tostring(config.weaponType or "tachyonLance") then
        server.tachyonMuzzleLightState.phase = "launch"
        server.tachyonMuzzleLightState.age = 0.0
    end
end

function server.tachyonMuzzleLightStop(weaponType)
    local config = server.tachyonMuzzleLightConfig
    if tostring(weaponType or "") == tostring(config.weaponType or "tachyonLance") then
        server.tachyonMuzzleLightState.phase = "idle"
        server.tachyonMuzzleLightState.age = 0.0
        _tachyonLightSetIntensity(0.0)
    end
end

function server.tachyonMuzzleLightTick(dt)
    local config = server.tachyonMuzzleLightConfig
    local state = server.tachyonMuzzleLightState
    state.age = state.age + math.max(0.0, tonumber(dt) or 0.0)

    if state.phase == "charging" then
        local duration = math.max(0.001, tonumber(config.chargeDuration) or 0.50)
        local t = math.max(0.0, math.min(1.0, state.age / duration))
        local accelerated = t * t
        local startIntensity = tonumber(config.chargeStartIntensity) or 5.0
        local endIntensity = tonumber(config.chargeEndIntensity) or 50.0
        _tachyonLightSetIntensity(startIntensity + (endIntensity - startIntensity) * accelerated)
        return
    end

    if state.phase == "launch" then
        local peak = tonumber(config.launchPeakIntensity) or 100.0
        local flashDuration = math.max(0.0, tonumber(config.launchFlashDuration) or 0.03)
        local fadeDuration = math.max(0.001, tonumber(config.launchFadeDuration) or 0.10)
        if state.age <= flashDuration then
            _tachyonLightSetIntensity(peak)
            return
        end

        local fade = (state.age - flashDuration) / fadeDuration
        if fade < 1.0 then
            _tachyonLightSetIntensity(peak * (1.0 - _tachyonLightSmoothStep(fade)))
            return
        end
        state.phase = "idle"
        state.age = 0.0
    end

    _tachyonLightSetIntensity(0.0)
end
