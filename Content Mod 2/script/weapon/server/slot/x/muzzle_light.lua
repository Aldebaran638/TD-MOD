-- Server-side intensity controller for the XML tachyon muzzle point light.
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.tachyonMuzzleLightConfig = server.tachyonMuzzleLightConfig or {}
local _tachyonLightConfig = server.tachyonMuzzleLightConfig
_tachyonLightConfig.weaponType = "tachyonLance"
_tachyonLightConfig.weaponTypes = _tachyonLightConfig.weaponTypes or {}
_tachyonLightConfig.weaponTypes.tachyonLance = true
_tachyonLightConfig.weaponTypes.focusedArcEmitter = true
_tachyonLightConfig.weaponTypes.particleLance = true
_tachyonLightConfig.weaponTypes.arcEmitter = true
_tachyonLightConfig.lightTag = _tachyonLightConfig.lightTag or "tachyonMuzzleLight"
_tachyonLightConfig.arcLeftLightTag = _tachyonLightConfig.arcLeftLightTag or "arcMuzzleLightLeft"
_tachyonLightConfig.arcRightLightTag = _tachyonLightConfig.arcRightLightTag or "arcMuzzleLightRight"
_tachyonLightConfig.chargeDuration = _tachyonLightConfig.chargeDuration or 0.50
_tachyonLightConfig.chargeStartIntensity = _tachyonLightConfig.chargeStartIntensity or 5.0
_tachyonLightConfig.chargeEndIntensity = _tachyonLightConfig.chargeEndIntensity or 50.0
_tachyonLightConfig.launchPeakIntensity = _tachyonLightConfig.launchPeakIntensity or 100.0
_tachyonLightConfig.launchFlashDuration = _tachyonLightConfig.launchFlashDuration or 0.03
_tachyonLightConfig.launchFadeDuration = _tachyonLightConfig.launchFadeDuration or 0.10
_tachyonLightConfig.arcChargeStartIntensity = _tachyonLightConfig.arcChargeStartIntensity or 0.0
_tachyonLightConfig.arcCenterChargeEndIntensity = _tachyonLightConfig.arcCenterChargeEndIntensity or 50.0
_tachyonLightConfig.arcSideChargeEndIntensity = _tachyonLightConfig.arcSideChargeEndIntensity or 0.65
_tachyonLightConfig.arcCenterOverloadPeak = _tachyonLightConfig.arcCenterOverloadPeak or 50.0
_tachyonLightConfig.arcSideOverloadPeak = _tachyonLightConfig.arcSideOverloadPeak or 0.65

server.tachyonMuzzleLightState = server.tachyonMuzzleLightState or {
    centerLight = 0,
    leftLight = 0,
    rightLight = 0,
    phase = "idle",
    age = 0.0,
    weaponType = "tachyonLance",
}

local function _tachyonLightSmoothStep(value)
    local t = math.max(0.0, math.min(1.0, value))
    return t * t * (3.0 - 2.0 * t)
end

local function _tachyonLightResolveHandle(handleKey, tag)
    local state = server.tachyonMuzzleLightState
    local light = math.floor(tonumber(state[handleKey]) or 0)
    if light == 0 or not IsHandleValid(light) then
        light = FindLight(tag, false)
        state[handleKey] = light or 0
    end
    return light
end

local function _tachyonLightSetHandleIntensity(handleKey, tag, intensity)
    local light = _tachyonLightResolveHandle(handleKey, tag)
    if light ~= 0 and IsHandleValid(light) then
        SetLightIntensity(light, math.max(0.0, intensity))
    end
end

local function _tachyonLightSetIntensities(centerIntensity, leftIntensity, rightIntensity)
    local config = server.tachyonMuzzleLightConfig
    _tachyonLightSetHandleIntensity(
        "centerLight",
        config.lightTag or "tachyonMuzzleLight",
        centerIntensity
    )
    _tachyonLightSetHandleIntensity(
        "leftLight",
        config.arcLeftLightTag or "arcMuzzleLightLeft",
        leftIntensity
    )
    _tachyonLightSetHandleIntensity(
        "rightLight",
        config.arcRightLightTag or "arcMuzzleLightRight",
        rightIntensity
    )
end

local function _tachyonLightSetColor(weaponType)
    local config = server.tachyonMuzzleLightConfig
    local center = _tachyonLightResolveHandle(
        "centerLight",
        config.lightTag or "tachyonMuzzleLight"
    )
    local left = _tachyonLightResolveHandle(
        "leftLight",
        config.arcLeftLightTag or "arcMuzzleLightLeft"
    )
    local right = _tachyonLightResolveHandle(
        "rightLight",
        config.arcRightLightTag or "arcMuzzleLightRight"
    )
    local requested = tostring(weaponType or "")
    local isArc = requested == "focusedArcEmitter" or requested == "arcEmitter"
    local isParticle = requested == "particleLance"
    if center ~= 0 and IsHandleValid(center) then
        if isParticle then
            SetLightColor(center, 1.0, 0.12, 0.03)
        elseif isArc then
            SetLightColor(center, 0.72, 0.22, 1.0)
        else
            SetLightColor(center, 0.45, 0.85, 1.0)
        end
    end
    if left ~= 0 and IsHandleValid(left) then
        SetLightColor(left, 0.52, 0.10, 1.0)
    end
    if right ~= 0 and IsHandleValid(right) then
        SetLightColor(right, 0.52, 0.10, 1.0)
    end
end

local function _tachyonLightSupportsWeapon(weaponType)
    local config = server.tachyonMuzzleLightConfig
    local requested = tostring(weaponType or "")
    return requested == tostring(config.weaponType or "tachyonLance")
        or (config.weaponTypes or {})[requested] == true
end

function server.tachyonMuzzleLightInit()
    local config = server.tachyonMuzzleLightConfig
    local state = server.tachyonMuzzleLightState
    state.centerLight = FindLight(config.lightTag or "tachyonMuzzleLight", false)
    state.leftLight = FindLight(config.arcLeftLightTag or "arcMuzzleLightLeft", false)
    state.rightLight = FindLight(config.arcRightLightTag or "arcMuzzleLightRight", false)
    state.phase = "idle"
    state.age = 0.0
    state.weaponType = "tachyonLance"
    _tachyonLightSetColor("tachyonLance")
    _tachyonLightSetIntensities(0.0, 0.0, 0.0)
end

function server.tachyonMuzzleLightBeginCharge(weaponType)
    local config = server.tachyonMuzzleLightConfig
    local state = server.tachyonMuzzleLightState
    if _tachyonLightSupportsWeapon(weaponType) then
        _tachyonLightSetColor(weaponType)
        state.weaponType = tostring(weaponType or "tachyonLance")
        if state.phase ~= "charging" then
            state.phase = "charging"
            state.age = 0.0
        end
    end
end

function server.tachyonMuzzleLightTrigger(weaponType)
    local config = server.tachyonMuzzleLightConfig
    if _tachyonLightSupportsWeapon(weaponType) then
        _tachyonLightSetColor(weaponType)
        server.tachyonMuzzleLightState.weaponType = tostring(weaponType or "tachyonLance")
        server.tachyonMuzzleLightState.phase = "launch"
        server.tachyonMuzzleLightState.age = 0.0
    end
end

function server.tachyonMuzzleLightStop(weaponType)
    local config = server.tachyonMuzzleLightConfig
    if _tachyonLightSupportsWeapon(weaponType) then
        server.tachyonMuzzleLightState.phase = "idle"
        server.tachyonMuzzleLightState.age = 0.0
        _tachyonLightSetIntensities(0.0, 0.0, 0.0)
    end
end

local function _tachyonLightOverloadWave(age, phase)
    local slow = 0.5 + 0.5 * math.sin(age * 13.0 + phase)
    local fast = 0.5 + 0.5 * math.sin(age * 31.0 + phase * 1.73)
    local spike = math.pow(math.max(0.0, math.sin(age * 47.0 + phase * 2.31)), 8.0)
    return math.max(0.0, math.min(1.0, slow * 0.34 + fast * 0.24 + spike * 0.76))
end

function server.tachyonMuzzleLightTick(dt)
    local config = server.tachyonMuzzleLightConfig
    local state = server.tachyonMuzzleLightState
    state.age = state.age + math.max(0.0, tonumber(dt) or 0.0)

    if state.phase == "charging" then
        local duration = math.max(0.001, tonumber(config.chargeDuration) or 0.50)
        local t = math.max(0.0, math.min(1.0, state.age / duration))
        local accelerated = t * t
        if tostring(state.weaponType or "") == "focusedArcEmitter" then
            local startIntensity = tonumber(config.arcChargeStartIntensity) or 0.0
            local centerEnd = tonumber(config.arcCenterChargeEndIntensity) or 1.70
            local sideEnd = tonumber(config.arcSideChargeEndIntensity) or 0.65
            if t < 1.0 then
                local visibleRamp = _tachyonLightSmoothStep(t)
                local center = startIntensity + (centerEnd - startIntensity) * visibleRamp
                local side = startIntensity + (sideEnd - startIntensity) * visibleRamp
                _tachyonLightSetIntensities(center, side * 0.96, side)
                return
            end

            local centerPeak = tonumber(config.arcCenterOverloadPeak) or 1.70
            local sidePeak = tonumber(config.arcSideOverloadPeak) or 0.65
            local centerWave = _tachyonLightOverloadWave(state.age, 0.0)
            local leftWave = _tachyonLightOverloadWave(state.age, 2.1)
            local rightWave = _tachyonLightOverloadWave(state.age, 4.7)
            _tachyonLightSetIntensities(
                centerPeak * (0.04 + 0.96 * centerWave),
                sidePeak * (0.03 + 0.97 * leftWave),
                sidePeak * (0.03 + 0.97 * rightWave)
            )
            return
        end

        local startIntensity = tonumber(config.chargeStartIntensity) or 5.0
        local endIntensity = tonumber(config.chargeEndIntensity) or 50.0
        _tachyonLightSetIntensities(
            startIntensity + (endIntensity - startIntensity) * accelerated,
            0.0,
            0.0
        )
        return
    end

    if state.phase == "launch" then
        local peak = tonumber(config.launchPeakIntensity) or 100.0
        local isArc = tostring(state.weaponType or "") == "focusedArcEmitter"
        local sidePeak = isArc and (tonumber(config.arcSideOverloadPeak) or 0.65) or 0.0
        if isArc then
            peak = tonumber(config.arcCenterOverloadPeak) or 1.70
        end
        local flashDuration = math.max(0.0, tonumber(config.launchFlashDuration) or 0.03)
        local fadeDuration = math.max(0.001, tonumber(config.launchFadeDuration) or 0.10)
        if state.age <= flashDuration then
            _tachyonLightSetIntensities(peak, sidePeak, sidePeak)
            return
        end

        local fade = (state.age - flashDuration) / fadeDuration
        if fade < 1.0 then
            local fadeScale = 1.0 - _tachyonLightSmoothStep(fade)
            _tachyonLightSetIntensities(
                peak * fadeScale,
                sidePeak * fadeScale,
                sidePeak * fadeScale
            )
            return
        end
        state.phase = "idle"
        state.age = 0.0
    end

    _tachyonLightSetIntensities(0.0, 0.0, 0.0)
end

local ok, err = server.chargedRayVisualRegister("tachyon", {
    defaultWeaponType = "tachyonLance",
    init = server.tachyonMuzzleLightInit,
    beginCharge = server.tachyonMuzzleLightBeginCharge,
    trigger = server.tachyonMuzzleLightTrigger,
    stop = server.tachyonMuzzleLightStop,
    tick = server.tachyonMuzzleLightTick,
})
if not ok then error("charged-ray visual registration failed: " .. tostring(err)) end
