#version 2

---@diagnostic disable: undefined-field

-- Source-only workflow model for Creator Ship Wizard v1. It orders already
-- verified creator tools; it is not a second compiler and never registers a
-- Runtime vehicle or writes the generated catalog.

cm2CreatorShipWizardV1 = cm2CreatorShipWizardV1 or {}

local STEPS = {
    { id = "select-vox", title = "Select VOX" },
    { id = "import-report", title = "Import Report" },
    { id = "confirm-scale-forward-up", title = "Scale / Forward / Up" },
    { id = "single-body-template", title = "Single-body Template" },
    { id = "configure-hp-flight-camera-engine", title = "HP / Flight / Camera / Engine" },
    { id = "set-effect-anchors", title = "Effect Anchors / Mounts" },
    { id = "choose-loadout", title = "Loadout" },
    { id = "validate-build", title = "Validate / Build" },
    { id = "ship-dock", title = "Ship Dock" },
    { id = "weapon-range", title = "Weapon Range" },
}

local state = nil

local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do result[copy(key, seen)] = copy(item, seen) end
    return result
end

local function audit(action, detail)
    state.audit[#state.audit + 1] = { sequence = #state.audit + 1, step = state.step, action = action, detail = tostring(detail or "") }
    if #state.audit > 24 then table.remove(state.audit, 1) end
end

local function block(code, fieldPath, resource)
    state.diagnostic = { code = code, fieldPath = fieldPath, resource = resource }
    state.rejected = state.rejected + 1
    audit("blocked", code)
    return false, code
end

local function validateStep(index)
    local source = state.source
    if index == 1 and not source.assetPresent then return block("asset-missing", "asset.vox", source.voxPath) end
    if index == 2 and not source.importReportPass then return block("import-report-stale", "asset.importReport", source.manifestHash) end
    if index == 3 and not source.orientationConfirmed then return block("orientation-confirm-required", "asset.orientation", "up/forward") end
    if index == 4 and (source.bodyCount > 2 or source.shapeCount > 8 or source.jointCount > 4) then return block("template-budget", "template", "B2/S8/J4") end
    if index == 5 and (source.massKg <= 0 or source.health <= 0) then return block("range", "ship.body.massKg", tostring(source.massKg)) end
    if index == 6 then
        for _, id in ipairs({ "engine.left", "engine.right", "muzzle.left", "muzzle.right", "camera.pilot" }) do
            if not source.anchors[id] then return block("anchor-reference", "ship.anchors", id) end
        end
        if not source.anchorsInBounds then return block("anchor-bounds", "ship.anchors", "VOX AABB") end
    end
    if index == 7 and (source.primary == "" or source.secondary == "") then return block("loadout-reference", "ship.loadout", "weapon definition") end
    if index >= 8 and not state.buildValidated then return block("build-required", "wizard.validate-build", "ENTER") end
    state.diagnostic = { code = "ok", fieldPath = STEPS[index].id, resource = "source-only" }
    return true
end

function cm2CreatorShipWizardV1.init(bundle)
    if type(bundle) ~= "table" or type(bundle.source) ~= "table" then return false, "wizard bundle is required" end
    state = {
        step = 1,
        source = copy(bundle.source),
        hashes = copy(bundle.hashes or {}),
        buildValidated = false,
        packageReady = false,
        previewShots = 0,
        rejected = 0,
        manualEdits = 0,
        diagnostic = { code = "ready", fieldPath = "wizard", resource = "source-only" },
        audit = {},
    }
    audit("init", "source and staging hashes loaded")
    return true
end

function cm2CreatorShipWizardV1.next()
    if not state then return false, "wizard is not initialized" end
    local ok, errorText = validateStep(state.step)
    if not ok then return false, errorText end
    if state.step >= #STEPS then return block("last-step", "wizard.step", STEPS[state.step].id) end
    state.step = state.step + 1
    audit("next", STEPS[state.step].id)
    return true
end

function cm2CreatorShipWizardV1.back()
    if not state then return false, "wizard is not initialized" end
    if state.step <= 1 then return block("first-step", "wizard.step", STEPS[state.step].id) end
    state.step = state.step - 1
    audit("back", STEPS[state.step].id)
    return true
end

function cm2CreatorShipWizardV1.injectInvalid()
    if not state then return false, "wizard is not initialized" end
    if state.step == 1 then state.source.assetPresent = false
    elseif state.step == 3 then state.source.orientationConfirmed = false
    elseif state.step == 5 then state.source.massKg = 0
    elseif state.step == 6 then state.source.anchors["engine.left"] = false
    else return block("no-invalid-fixture", "wizard.step", STEPS[state.step].id) end
    state.buildValidated = false
    state.packageReady = false
    audit("inject-invalid", STEPS[state.step].id)
    return validateStep(state.step)
end

function cm2CreatorShipWizardV1.repairOrEdit()
    if not state then return false, "wizard is not initialized" end
    if state.step == 1 then state.source.assetPresent = true
    elseif state.step == 3 then state.source.orientationConfirmed = true
    elseif state.step == 5 then state.source.massKg = 1400
    elseif state.step == 6 then state.source.anchors["engine.left"] = true
    else state.source.health = state.source.health + 25 end
    state.manualEdits = state.manualEdits + 1
    state.buildValidated = false
    state.packageReady = false
    audit("manual-edit", STEPS[state.step].id)
    return validateStep(state.step)
end

function cm2CreatorShipWizardV1.validateBuild()
    if not state then return false, "wizard is not initialized" end
    if state.step ~= 8 then return block("wrong-build-step", "wizard.step", STEPS[state.step].id) end
    for index = 1, 7 do
        local ok, errorText = validateStep(index)
        if not ok then return false, errorText end
    end
    state.buildValidated = true
    state.diagnostic = { code = "build-pass", fieldPath = "staging.package", resource = state.hashes.packageHash or "" }
    audit("validate-build", state.hashes.buildHash or "")
    return true
end

function cm2CreatorShipWizardV1.package()
    if not state then return false, "wizard is not initialized" end
    if state.step ~= 10 or not state.buildValidated then return block("package-not-ready", "wizard.step", STEPS[state.step].id) end
    state.packageReady = true
    audit("package", state.hashes.packageHash or "")
    return true
end

function cm2CreatorShipWizardV1.previewFire()
    if not state then return false, "wizard is not initialized" end
    if state.step ~= 10 or not state.buildValidated then return block("weapon-range-not-ready", "wizard.step", STEPS[state.step].id) end
    state.previewShots = state.previewShots + 1
    audit("preview-fire", "synthetic presentation only")
    return true
end

function cm2CreatorShipWizardV1.snapshot()
    if not state then return { ready = false, steps = copy(STEPS) } end
    local result = copy(state)
    result.ready = true
    result.steps = copy(STEPS)
    result.current = copy(STEPS[state.step])
    return result
end

function cm2CreatorShipWizardV1.dispose()
    if state then audit("dispose", "no Runtime catalog mutation") end
    state = nil
end
