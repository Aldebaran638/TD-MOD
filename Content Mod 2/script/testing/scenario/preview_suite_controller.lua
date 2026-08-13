#version 2

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: undefined-field

-- Disposable Teardown host for Preview Suite v1.  The preview candidate stays
-- engine-free; this host translates its deterministic diagnostics into a real
-- in-game UI and production-budgeted visual surface.

client = client or {}

#include "../../weapon/client/presentation/visual/runtime/shared/effect_budget.lua"
#include "../../weapon/client/presentation/presentation_budget.lua"
#include "../../weapon/client/presentation/effect_player.lua"
#include "../../world/adapter/synthetic_world_adapter_v1.lua"
#include "../../world/adapter/preview_suite_v1.lua"

local ROOT = "StellarisShips/testing/previewSuite/"
local EFFECT_ID = "content.effects.focused-arc-impact"
local WEAPON_ID = "content.weapons.arc-emitter-1"
local SHIP_ID = "content.ships.gamma-strike-craft"
local FIXED_SEED = 424242
local MODES = { "EFFECT LAB", "WEAPON RANGE", "SHIP DOCK" }

local state = {
    ready = false,
    mode = 1,
    replay = 0,
    clock = 0,
    flash = 0,
    action = "initializing",
    errorText = "",
    effectNear = nil,
    effectFar = nil,
    range = nil,
    dock = nil,
    diagnostics = nil,
}

local definitions = {
    [EFFECT_ID] = {
        id = EFFECT_ID,
        kind = "effect",
        effect = "focused-arc-impact",
        budget = { priority = "critical", particles = 24, lights = 1, lines = 16 },
    },
    [WEAPON_ID] = {
        id = WEAPON_ID,
        kind = "weapon",
        damageMin = 6,
        damageMax = 16,
        projectile = "focused-arc",
        effect = EFFECT_ID,
    },
    [SHIP_ID] = {
        id = SHIP_ID,
        kind = "ship",
        vox = { path = "MOD/vox/gammaStrikeCraftTest.vox", scale = 1.0, canonicalAxes = true },
        entityGraph = { id = "ship:gamma.graph", bodies = 1, shapes = 1, joints = 0 },
        anchors = { "engine.left", "engine.right", "muzzle.left", "muzzle.right", "camera.pilot" },
        mounts = { "mount.primary", "mount.secondary" },
        turrets = { { id = "turret.hero", mode = "logical", yaw = { -70, 70 }, pitch = { -10, 45 } } },
    },
}

local compiler = {
    version = "cm2.runtime-compiler/1",
    compile = function(definition)
        if type(definition) ~= "table" or type(definition.id) ~= "string" then return nil, "invalid definition" end
        return definition
    end,
}

local catalog = {
    hash = "cm2.preview-live-catalog/1",
    snapshot = { frozen = true, ids = { EFFECT_ID, WEAPON_ID, SHIP_ID } },
    lookup = function(id) return definitions[tostring(id or "")] end,
}

local function publishStatus()
    SetBool(ROOT .. "ready", state.ready)
    SetInt(ROOT .. "mode", state.mode)
    SetInt(ROOT .. "replay", state.replay)
    SetString(ROOT .. "modeName", MODES[state.mode])
    SetString(ROOT .. "action", state.action)
    SetString(ROOT .. "error", state.errorText)
end

local function runEffectLab()
    local near, nearError = cm2PreviewSuiteV1.runEffectLab(EFFECT_ID, { distance = "near", duration = 0.25 })
    local far, farError = cm2PreviewSuiteV1.runEffectLab(EFFECT_ID, { distance = "far", duration = 0.25 })
    if near == nil or far == nil then return false, nearError or farError or "Effect Lab failed" end
    state.effectNear = near
    state.effectFar = far
    state.flash = 1.0
    state.action = "S2 replay: EffectPlayer near LOD0 + far LOD1"
    return true
end

local function rangeTargets()
    return {
        { type = "shield", moving = false, budget = "normal", missThreshold = 0.0 },
        { type = "body", moving = true, budget = "normal", missThreshold = 0.0 },
        { type = "environment", moving = false, budget = "degraded", missThreshold = 0.0 },
        { type = "body", moving = false, budget = "rejected", missThreshold = 1.0 },
    }
end

local function runWeaponRange()
    local result, errorText = cm2PreviewSuiteV1.runWeaponRange(WEAPON_ID, rangeTargets(), {
        seed = FIXED_SEED,
        muzzle = { 0.0, 2.0, 5.0 },
    })
    if result == nil then return false, errorText or "Weapon Range failed" end
    state.range = result
    state.flash = 1.0
    state.action = "S2 replay: 4 deterministic shots / budget 2+1+1"
    return true
end

local function runShipDock()
    if state.dock ~= nil and state.dock.spawned then
        local disposed, disposeError = cm2PreviewSuiteV1.disposeShipDock(state.dock.instanceId)
        if not disposed then return false, disposeError or "Ship Dock dispose failed" end
        local staleAccepted = cm2PreviewSuiteV1.disposeShipDock(state.dock.instanceId)
        if staleAccepted then return false, "stale Ship Dock dispose was accepted" end
    end
    local result, errorText = cm2PreviewSuiteV1.spawnShipDock(SHIP_ID, {
        instanceId = "preview:ship-dock",
        camera = { mode = "orbit", distance = 12.0 },
        engineMarkers = { "engine.left", "engine.right", "muzzle.left", "muzzle.right", "camera.pilot" },
    })
    if result == nil then return false, errorText or "Ship Dock spawn failed" end
    state.dock = result
    state.flash = 0.7
    state.action = "S5 replay: VOX + graph + anchor/mount/turret lifecycle"
    return true
end

local function replayCurrent()
    state.replay = state.replay + 1
    local ok, errorText
    if state.mode == 1 then ok, errorText = runEffectLab()
    elseif state.mode == 2 then ok, errorText = runWeaponRange()
    else ok, errorText = runShipDock() end
    if not ok then state.errorText = tostring(errorText or "preview replay failed") else state.errorText = "" end
    state.diagnostics = cm2PreviewSuiteV1.exportDiagnostics({ screenshot = true, recording = true })
    publishStatus()
end

local function selectMode(mode)
    state.mode = math.max(1, math.min(3, math.floor(tonumber(mode) or 1)))
    replayCurrent()
end

local function drawMarker(position, color, size)
    local s = tonumber(size) or 0.25
    client.presentationBudget.line(VecAdd(position, Vec(-s, 0, 0)), VecAdd(position, Vec(s, 0, 0)), color[1], color[2], color[3], 1, { priority = "critical" })
    client.presentationBudget.line(VecAdd(position, Vec(0, -s, 0)), VecAdd(position, Vec(0, s, 0)), color[1], color[2], color[3], 1, { priority = "critical" })
    client.presentationBudget.line(VecAdd(position, Vec(0, 0, -s)), VecAdd(position, Vec(0, 0, s)), color[1], color[2], color[3], 1, { priority = "critical" })
end

function client.init()
    cm2SyntheticWorldAdapterV1.init("preview-suite-live", "preview-suite-live", {
        effectLab = true, weaponRange = true, shipDock = true,
    }, "preview")
    local ok, result = cm2PreviewSuiteV1.init({
        compiler = compiler,
        catalog = catalog,
        worldEntityAdapter = cm2SyntheticWorldAdapterV1,
        effectPlayer = client.effectPlayer,
        presentationBudget = client.presentationBudget,
    }, { generation = 1, seed = FIXED_SEED })
    if not ok then
        state.errorText = tostring(result or "Preview Suite init failed")
        publishStatus()
        return
    end
    state.ready = true
    runEffectLab()
    runWeaponRange()
    runShipDock()
    state.mode = 1
    state.action = "S0 replay: live Preview Suite ready"
    state.diagnostics = cm2PreviewSuiteV1.exportDiagnostics({ screenshot = true, recording = true })
    publishStatus()
end

function client.tick(dt)
    local delta = math.max(0.0, tonumber(dt) or 0.0)
    state.clock = state.clock + delta
    state.flash = math.max(0.0, state.flash - delta)
    cm2SyntheticWorldAdapterV1.tick(delta)
    client.presentationBudget.beginFrame(delta)
    SetCameraTransform(Transform(Vec(0, 7.5, 19), QuatLookAt(Vec(0, 7.5, 19), Vec(0, 1.5, -2))))

    if InputPressed("1") then selectMode(1)
    elseif InputPressed("2") then selectMode(2)
    elseif InputPressed("3") then selectMode(3)
    elseif InputPressed("space") or InputPressed("lmb") then replayCurrent() end

    if state.flash > 0 and math.floor(state.clock * 30) % 3 == 0 then
        local origin = state.mode == 1 and Vec(-5, 2.2, -2) or Vec(0, 2.0, 5)
        client.presentationBudget.spawnParticle(origin, Vec(0, 0.4, 0), 0.45, { priority = "critical", count = 1 })
    end
end

function client.render()
    if not state.ready then return end
    if state.mode == 1 then
        local origin = Vec(-5, 2.2, 2)
        local target = Vec(-5, 2.2, -7)
        local pulse = 0.55 + 0.35 * math.sin(state.clock * 7)
        client.presentationBudget.line(origin, target, 0.25, 0.75, 1.0, 1.0, { priority = "critical" })
        client.presentationBudget.pointLight(target, 0.15, 0.65, 1.0, 4.0 + pulse * 4.0, 12.0, { priority = "critical" })
        drawMarker(origin, { 0.2, 0.8, 1.0 }, 0.45)
        drawMarker(target, { 1.0, 0.4, 0.1 }, 0.55 + pulse * 0.2)
    elseif state.mode == 2 then
        local muzzle = Vec(0, 2.0, 5)
        local moving = math.sin(state.clock * 0.8) * 2.0
        local targets = { Vec(-5, 2.0, -6), Vec(moving, 3.0, -8), Vec(4.5, 1.0, -5), Vec(6, 4.5, -10) }
        local colors = { { 0.2, 0.7, 1.0 }, { 0.2, 1.0, 0.4 }, { 1.0, 0.75, 0.15 }, { 1.0, 0.15, 0.12 } }
        for index, target in ipairs(targets) do
            local color = colors[index]
            client.presentationBudget.line(muzzle, target, color[1], color[2], color[3], index == 4 and 0.25 or 0.9, { priority = index == 4 and "ambient" or "critical" })
            drawMarker(target, color, index == 2 and 0.55 or 0.35)
        end
        drawMarker(muzzle, { 1.0, 1.0, 1.0 }, 0.45)
    else
        local anchors = {
            { Vec(3.3, 1.6, 2.3), { 0.15, 0.65, 1.0 } },
            { Vec(4.7, 1.6, 2.3), { 0.15, 0.65, 1.0 } },
            { Vec(3.4, 2.0, -2.3), { 1.0, 0.2, 0.12 } },
            { Vec(4.6, 2.0, -2.3), { 1.0, 0.2, 0.12 } },
            { Vec(4.0, 2.8, 0.3), { 0.8, 0.35, 1.0 } },
        }
        for _, marker in ipairs(anchors) do drawMarker(marker[1], marker[2], 0.42) end
        client.presentationBudget.line(Vec(2.5, 0.7, 0), Vec(5.5, 0.7, 0), 0.2, 1.0, 0.5, 0.8, { priority = "critical" })
        client.presentationBudget.line(Vec(4.0, 0.7, -2), Vec(4.0, 0.7, 2), 0.2, 1.0, 0.5, 0.8, { priority = "critical" })
    end
end

local function label(text, size, r, g, b, a)
    UiFont("regular.ttf", size)
    UiColor(r or 1, g or 1, b or 1, a or 1)
    UiText(tostring(text))
    UiTranslate(0, size + 8)
end

function client.draw()
    UiPush()
    UiTranslate(30, 28)
    UiColor(0.015, 0.025, 0.05, 0.9)
    UiRect(590, 330)
    UiTranslate(20, 18)
    label("CM2 PREVIEW SUITE V1", 27, 0.25, 0.78, 1.0, 1.0)
    label("[1] EFFECT LAB   [2] WEAPON RANGE   [3] SHIP DOCK", 17, 0.8, 0.88, 0.98, 1.0)
    label("ACTIVE: " .. MODES[state.mode] .. "    SPACE/LMB: replay", 20, 1.0, 0.82, 0.25, 1.0)
    label("fixed seed: " .. tostring(FIXED_SEED) .. "    replay: " .. tostring(state.replay), 16, 0.7, 0.78, 0.9, 1.0)
    label(state.action, 16, 0.35, 1.0, 0.55, 1.0)
    if state.mode == 1 then
        label("EffectPlayer: production   LOD: near=0 far=1", 16, 0.78, 0.86, 1.0, 1.0)
        label("PresentationBudget: particles + light + lines", 16, 0.78, 0.86, 1.0, 1.0)
    elseif state.mode == 2 and state.range ~= nil then
        label("shots: " .. state.range.shots .. "  hits: " .. state.range.hits .. "  damage: " .. state.range.damage, 16, 0.78, 0.86, 1.0, 1.0)
        label("budget: accepted=2 degraded=1 rejected=1", 16, 0.78, 0.86, 1.0, 1.0)
    elseif state.mode == 3 and state.dock ~= nil then
        label("VOX scale=1  canonical axes  graph=ship:gamma.graph", 16, 0.78, 0.86, 1.0, 1.0)
        label("anchors=5  mounts=2  turrets=1  camera=orbit", 16, 0.78, 0.86, 1.0, 1.0)
    end
    local unchanged = state.diagnostics ~= nil and state.diagnostics.runtimeCatalogUnchanged
    label("runtime catalog unchanged: " .. tostring(unchanged), 16, unchanged and 0.3 or 1.0, unchanged and 1.0 or 0.2, 0.45, 1.0)
    if state.errorText ~= "" then label("ERROR: " .. state.errorText, 16, 1.0, 0.15, 0.1, 1.0) end
    UiPop()
end

function client.destroy()
    cm2PreviewSuiteV1.dispose()
    cm2SyntheticWorldAdapterV1.dispose("preview-level-destroy")
    client.effectPlayer.sceneReload()
    state.ready = false
    publishStatus()
end
