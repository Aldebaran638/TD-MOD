#version 2

---@diagnostic disable: undefined-global

-- This controller owns only the disposable scene camera and HUD. The level
-- script has a separate Lua context from main.lua, so registry reads here
-- would be misleading. CM2_TEST_V1 in the main Runtime remains the sole
-- authority for live registration, HP, transforms, velocity and cleanup.

local ROOT = "StellarisShips/testing/vehicleComponentCatalog/"
local CANDIDATE_HASH = "c9ac30aefa68a83b1f24acc6537e52b7b4d82ffcb06802dceafe17c4f37d4d29"

local function publishStaticMetadata()
    SetBool(ROOT .. "ready", true)
    SetString(ROOT .. "candidateHash", CANDIDATE_HASH)
    SetString(ROOT .. "ownership", "candidate-active / generated-v1 promoted")
    SetString(ROOT .. "coordinateFrame", "parent-local; +X right, +Y up, -Z forward; meter")
    SetInt(ROOT .. "vehicleCount", 5)
    SetInt(ROOT .. "mountCount", 32)
    SetInt(ROOT .. "componentCount", 26)
    SetInt(ROOT .. "interceptorCount", 3)
end

local function label(value, size, r, g, b)
    UiFont("regular.ttf", size)
    UiColor(r or 1, g or 1, b or 1, 1)
    UiText(tostring(value))
    UiTranslate(0, size + 6)
end

function client.init()
    publishStaticMetadata()
end

function client.tick(_dt)
    publishStaticMetadata()
    SetCameraTransform(Transform(Vec(0, 76, 58), QuatLookAt(Vec(0, 76, 58), Vec(0, 60, -18))))
end

function client.destroy()
    SetBool(ROOT .. "ready", false)
end

function client.draw()
    UiPush()
    UiTranslate(28, 28)
    UiColor(0.01, 0.02, 0.045, 0.94)
    UiRect(560, 238)
    UiTranslate(18, 16)
    label("CM2 VEHICLE CATALOG V1", 25, 0.25, 0.82, 1.0)
    label("FIVE PRODUCTION ENTRYPOINTS", 16, 0.78, 0.86, 0.98)
    label("live registration: CM2_TEST_V1 telemetry", 17, 0.45, 1.0, 0.62)
    label("mounts 32  components 26  interceptors 3", 16, 0.78, 0.86, 0.98)
    label("authority: GENERATED V1 ACTIVE  |  legacy: INIT-ONLY", 16, 0.35, 1.0, 0.62)
    label("coordinate frame: parent-local  +X / +Y / -Z", 15, 0.78, 0.86, 0.98)
    label("telemetry snapshot is authoritative", 17, 0.35, 1.0, 0.35)
    UiPop()
end
