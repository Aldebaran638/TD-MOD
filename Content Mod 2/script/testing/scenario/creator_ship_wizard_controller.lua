#version 2

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- Disposable Step 8.6 live host. The actual artifacts are emitted by the
-- headless builder; this host verifies navigation, fail-closed validation,
-- manual editing/backtracking and the two generated Preview surfaces.

client = client or {}

#include "../../world/adapter/creator_ship_wizard_v1.lua"

local ROOT = "StellarisShips/testing/creatorShipWizard/"
local LUA_REVISION = "creator-ship-wizard-lua-v1"
local SOURCE_HASH = "1b760576732c0323fae67294d228d69b5d82d09eaa250c66f11de2f3e45df331"
local BUILD_HASH = "ead7332e378e18bff5f6d7dbf8d28042040da5ce30f6c95654e32c4efafa66a8"
local PACKAGE_HASH = "910a0fdc5db75679df3565553ec139f503c53bd64dd0f82a37d05cb49b443b23"

local BUNDLE = {
    source = {
        assetPresent = true,
        voxPath = "MOD/vox/gammaStrikeCraftTest.vox",
        importReportPass = true,
        manifestHash = "009135e9ba3cf5a9c1b57222ec712de910584973933ca1edee1f0afa01448e18",
        orientationConfirmed = true,
        up = "+Y",
        forward = "-Z",
        metersPerVoxel = 0.1,
        bodyCount = 1,
        shapeCount = 1,
        jointCount = 0,
        massKg = 1200,
        health = 500,
        shield = 250,
        armor = 100,
        anchors = { ["engine.left"] = true, ["engine.right"] = true, ["muzzle.left"] = true, ["muzzle.right"] = true, ["camera.pilot"] = true },
        anchorsInBounds = true,
        primary = "content.weapons.arc-emitter-1",
        secondary = "content.weapons.focused-arc",
    },
    hashes = { sourceHash = SOURCE_HASH, buildHash = BUILD_HASH, packageHash = PACKAGE_HASH },
}

local state = { ready = false, shape = 0, center = Vec(0, 2, 0), lastAction = "initializing", pulse = 0, toolDown = false }

local function publish()
    local snapshot = cm2CreatorShipWizardV1.snapshot()
    SetBool(ROOT .. "ready", snapshot.ready == true)
    SetString(ROOT .. "luaRevision", LUA_REVISION)
    SetString(ROOT .. "step", snapshot.current and snapshot.current.id or "none")
    SetString(ROOT .. "diagnostic", snapshot.diagnostic and snapshot.diagnostic.code or "none")
    SetInt(ROOT .. "rejected", snapshot.rejected or 0)
    SetInt(ROOT .. "manualEdits", snapshot.manualEdits or 0)
    SetBool(ROOT .. "buildValidated", snapshot.buildValidated == true)
    SetBool(ROOT .. "packageReady", snapshot.packageReady == true)
    SetInt(ROOT .. "previewShots", snapshot.previewShots or 0)
end

local function invoke(action, success)
    local ok, errorText = action()
    state.lastAction = ok and success or ("BLOCKED: " .. tostring(errorText))
    publish()
end

local function updateShape()
    if state.shape == 0 then state.shape = FindShape("cm2CreatorWizardVox", true) end
    if state.shape ~= 0 then
        local minimum, maximum = GetShapeBounds(state.shape)
        state.center = VecLerp(minimum, maximum, 0.5)
    end
end

local function marker(position, r, g, b, size)
    local radius = size or 0.25
    DrawLine(VecAdd(position, Vec(-radius, 0, 0)), VecAdd(position, Vec(radius, 0, 0)), r, g, b, 1)
    DrawLine(VecAdd(position, Vec(0, -radius, 0)), VecAdd(position, Vec(0, radius, 0)), r, g, b, 1)
    DrawLine(VecAdd(position, Vec(0, 0, -radius)), VecAdd(position, Vec(0, 0, radius)), r, g, b, 1)
end

local function text(value, size, r, g, b, a)
    UiFont("regular.ttf", size)
    UiColor(r or 1, g or 1, b or 1, a or 1)
    UiText(tostring(value))
    UiTranslate(0, size + 6)
end

function client.init()
    local ok, errorText = cm2CreatorShipWizardV1.init(BUNDLE)
    state.ready = ok
    state.lastAction = ok and "source-only Wizard ready" or tostring(errorText)
    updateShape()
    publish()
end

function client.tick(dt)
    SetCameraTransform(Transform(Vec(0, 8, 18), QuatLookAt(Vec(0, 8, 18), Vec(0, 2, 0))))
    updateShape()
    state.pulse = math.max(0, state.pulse - (tonumber(dt) or 0))
    local toolDown = InputDown("lmb") or InputDown("usetool")
    if toolDown and not state.toolDown then
        local ok, errorText = cm2CreatorShipWizardV1.previewFire()
        if ok then state.pulse = 0.35; state.lastAction = "LMB synthetic range presentation" else state.lastAction = "BLOCKED: " .. tostring(errorText) end
        publish()
    elseif InputPressed("rightarrow") then invoke(cm2CreatorShipWizardV1.next, "NEXT")
    elseif InputPressed("leftarrow") then invoke(cm2CreatorShipWizardV1.back, "BACK / source edits retained")
    elseif InputPressed("delete") then invoke(cm2CreatorShipWizardV1.injectInvalid, "invalid fixture injected")
    elseif InputPressed("space") then
        local snapshot = cm2CreatorShipWizardV1.snapshot()
        if snapshot.step == 10 then
            local ok, errorText = cm2CreatorShipWizardV1.previewFire()
            if ok then state.pulse = 0.35; state.lastAction = "SPACE synthetic range presentation" else state.lastAction = "BLOCKED: " .. tostring(errorText) end
            publish()
        else
            invoke(cm2CreatorShipWizardV1.repairOrEdit, "manual edit / repair")
        end
    elseif InputPressed("return") then
        local snapshot = cm2CreatorShipWizardV1.snapshot()
        if snapshot.step == 8 then invoke(cm2CreatorShipWizardV1.validateBuild, "VALIDATE + BUILD PASS")
        else invoke(cm2CreatorShipWizardV1.package, "PACKAGE READY") end
    end
    state.toolDown = toolDown
end

function client.render()
    if not state.ready or state.shape == 0 then return end
    local snapshot = cm2CreatorShipWizardV1.snapshot()
    local center = state.center
    DrawLine(center, VecAdd(center, Vec(3.2, 0, 0)), 1, 0.15, 0.12, 1)
    DrawLine(center, VecAdd(center, Vec(0, 3.2, 0)), 0.2, 1, 0.35, 1)
    DrawLine(center, VecAdd(center, Vec(0, 0, -3.2)), 0.2, 0.55, 1, 1)
    for _, anchor in ipairs({
        { -1.4, 0, 2.2, 0.1, 0.65, 1 }, { 1.4, 0, 2.2, 0.1, 0.65, 1 },
        { -1.3, 0, -2.2, 1, 0.25, 0.12 }, { 1.3, 0, -2.2, 1, 0.25, 0.12 },
        { 0, 0.45, 0.3, 1, 0.85, 0.12 },
    }) do marker(VecAdd(center, Vec(anchor[1], anchor[2], anchor[3])), anchor[4], anchor[5], anchor[6], 0.3) end

    if snapshot.step == 9 then
        local dock = VecAdd(center, Vec(0, -1.2, 0))
        DrawLine(VecAdd(dock, Vec(-4.5, 0, -3.5)), VecAdd(dock, Vec(4.5, 0, -3.5)), 0.15, 0.8, 1, 1)
        DrawLine(VecAdd(dock, Vec(4.5, 0, -3.5)), VecAdd(dock, Vec(4.5, 0, 3.5)), 0.15, 0.8, 1, 1)
        DrawLine(VecAdd(dock, Vec(4.5, 0, 3.5)), VecAdd(dock, Vec(-4.5, 0, 3.5)), 0.15, 0.8, 1, 1)
        DrawLine(VecAdd(dock, Vec(-4.5, 0, 3.5)), VecAdd(dock, Vec(-4.5, 0, -3.5)), 0.15, 0.8, 1, 1)
    elseif snapshot.step == 10 then
        local muzzle = VecAdd(center, Vec(-1.3, 0, -2.2))
        local target = VecAdd(center, Vec(-1.3, 0, -8.5))
        marker(target, 1, 0.2, 0.15, 0.7)
        DrawLine(VecAdd(target, Vec(-1.4, 0, 0)), VecAdd(target, Vec(1.4, 0, 0)), 1, 0.2, 0.15, 1)
        if state.pulse > 0 then DrawLine(muzzle, target, 0.25, 0.85, 1, 1) end
    end
end

function client.draw()
    local snapshot = cm2CreatorShipWizardV1.snapshot()
    if not snapshot.ready then return end
    local diagnostic = snapshot.diagnostic or {}
    local diagnosticPass = diagnostic.code == "ok" or diagnostic.code == "build-pass"

    UiPush()
    UiTranslate(24, 66)
    UiColor(0.01, 0.02, 0.045, 0.95)
    UiRect(610, 720)
    UiTranslate(18, 16)
    text("CM2 CREATOR SHIP WIZARD MVP", 25, 0.3, 0.82, 1, 1)
    text(LUA_REVISION .. "  |  source-only staging", 14, 0.7, 0.82, 0.94, 1)
    for index, step in ipairs(snapshot.steps) do
        local active = index == snapshot.step
        local complete = index < snapshot.step
        text(string.format("%s %02d  %s", active and ">" or (complete and "+" or "-"), index, step.title), 15, active and 1 or (complete and 0.4 or 0.65), active and 0.82 or (complete and 1 or 0.72), active and 0.24 or (complete and 0.55 or 0.82), 1)
    end
    UiPop()

    UiPush()
    UiTranslate(1290, 66)
    UiColor(0.01, 0.02, 0.045, 0.95)
    UiRect(600, 610)
    UiTranslate(18, 16)
    text(string.format("STEP %02d / 10", snapshot.step), 24, 1, 0.82, 0.24, 1)
    text(snapshot.current.title, 22, 0.3, 0.85, 1, 1)
    text("Gamma VOX 45 x 12 x 51 @ 0.1 m", 15, 0.76, 0.86, 0.96, 1)
    text("orientation +Y UP / -Z FORWARD", 15, 1, 0.58, 0.3, 1)
    text("mass=" .. snapshot.source.massKg .. " kg  HP/S/A=" .. snapshot.source.health .. "/" .. snapshot.source.shield .. "/" .. snapshot.source.armor, 15, 0.76, 0.86, 0.96, 1)
    text("template budget B/S/J 1/1/0 <= 2/8/4", 15, 0.45, 1, 0.62, 1)
    text("anchors 5 / mounts 2 / loadout 2", 15, 0.45, 1, 0.62, 1)
    text("DIAGNOSTIC: " .. tostring(diagnostic.code), 16, diagnosticPass and 0.35 or 1, diagnosticPass and 1 or 0.3, 0.35, 1)
    text(tostring(diagnostic.fieldPath) .. " / " .. tostring(diagnostic.resource), 14, 0.82, 0.86, 0.94, 1)
    text("LAST: " .. state.lastAction, 14, 0.82, 0.86, 0.94, 1)
    text("rejected=" .. snapshot.rejected .. "  manual edits=" .. snapshot.manualEdits, 15, 0.82, 0.86, 0.94, 1)
    text("build=" .. tostring(snapshot.buildValidated) .. "  package=" .. tostring(snapshot.packageReady), 15, 0.45, 1, 0.62, 1)
    text("source " .. string.sub(SOURCE_HASH, 1, 12) .. "...", 14, 0.65, 0.75, 0.9, 1)
    text("build  " .. string.sub(BUILD_HASH, 1, 12) .. "...", 14, 0.65, 0.75, 0.9, 1)
    text("package " .. string.sub(PACKAGE_HASH, 1, 12) .. "...", 14, 0.65, 0.75, 0.9, 1)
    text("RIGHT next  LEFT back  DEL invalid", 14, 0.82, 0.9, 1, 1)
    text("SPACE manual edit/repair  ENTER build/package", 14, 0.82, 0.9, 1, 1)
    if snapshot.step == 10 then text("SPACE plays synthetic Weapon Range presentation", 14, 0.3, 0.85, 1, 1) end
    UiPop()
end

function client.destroy()
    cm2CreatorShipWizardV1.dispose()
    state.ready = false
    publish()
end
