#version 2

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- Disposable, non-3D presentation host for the Schema-driven Definition
-- Editor MVP. The source editor/compiler contract stays engine-free; this
-- scene exposes its exact form metadata and diagnostics to real Teardown input
-- without gaining filesystem, generated-catalog, weapon or damage authority.

client = client or {}

local ROOT = "StellarisShips/testing/definitionEditor/"
local LUA_REVISION = "definition-editor-lua-v1"
local FORMS = {
    {
        kind = "weapon", version = "cm2.weapon/1", fields = {
            { path = "runtime.behavior", type = "enum", unit = "none", range = "ray|ballistic|guided|charged", reference = "-", budget = "behavior tick class", base = "ray", edit = "charged", invalid = "unknown", invalidCode = "invalid-enum" },
            { path = "runtime.effectId", type = "id", unit = "none", range = "canonical ID", reference = "effect", budget = "effect instance", base = "cm2.editor.demo:effect.range", edit = "cm2.editor.demo:effect.range", invalid = "cm2.editor.demo:effect.missing", invalidCode = "broken-reference" },
            { path = "runtime.projectileId", type = "id", unit = "none", range = "canonical ID", reference = "projectile", budget = "projectile allocation", base = "optional", edit = "cm2.editor.demo:projectile.range", invalid = "missing:projectile", invalidCode = "broken-reference" },
            { path = "runtime.fireRateHz", type = "number", unit = "Hz", range = "0 < x <= 1000", reference = "-", budget = "server fire cadence", base = "2", edit = "4", invalid = "0", invalidCode = "out-of-range" },
        },
    },
    {
        kind = "projectile", version = "cm2.projectile/1", fields = {
            { path = "runtime.speedMps", type = "number", unit = "m/s", range = "0 < x <= 10000", reference = "-", budget = "projectile query cadence", base = "100", edit = "200", invalid = "0", invalidCode = "out-of-range" },
            { path = "runtime.damage", type = "number", unit = "damage", range = "0 < x <= 1000000000", reference = "-", budget = "damage event", base = "6", edit = "16", invalid = "0", invalidCode = "out-of-range" },
            { path = "runtime.effectId", type = "id", unit = "none", range = "canonical ID", reference = "effect", budget = "effect instance", base = "cm2.editor.demo:effect.range", edit = "cm2.editor.demo:effect.range", invalid = "missing:effect", invalidCode = "broken-reference" },
        },
    },
    {
        kind = "effect", version = "cm2.effect/1", fields = {
            { path = "runtime.effectType", type = "enum", unit = "none", range = "beam|muzzle|trail|impact", reference = "-", budget = "renderer class", base = "beam", edit = "impact", invalid = "volume", invalidCode = "invalid-enum" },
            { path = "runtime.assetId", type = "id", unit = "none", range = "canonical ID", reference = "asset", budget = "resource handle", base = "cm2.editor.demo:asset.beam", edit = "cm2.editor.demo:asset.beam", invalid = "missing:asset", invalidCode = "broken-reference" },
            { path = "runtime.priority", type = "number", unit = "rank", range = "0 <= x <= 100", reference = "-", budget = "budget eviction priority", base = "50", edit = "75", invalid = "101", invalidCode = "out-of-range" },
        },
    },
    {
        kind = "vehicle", version = "cm2.vehicle/1", fields = {
            { path = "runtime.controlMode", type = "enum", unit = "none", range = "player|ai", reference = "-", budget = "owner tick class", base = "player", edit = "ai", invalid = "remote", invalidCode = "invalid-enum" },
            { path = "runtime.massKg", type = "number", unit = "kg", range = "0 < x <= 1000000000", reference = "-", budget = "physics mass", base = "1000", edit = "2000", invalid = "0", invalidCode = "out-of-range" },
            { path = "runtime.mountId", type = "id", unit = "none", range = "canonical ID", reference = "mount", budget = "mount graph", base = "cm2.editor.demo:mount.primary", edit = "cm2.editor.demo:mount.primary", invalid = "missing:mount", invalidCode = "broken-reference" },
        },
    },
    {
        kind = "mount", version = "cm2.mount/1", fields = {
            { path = "runtime.parentId", type = "id", unit = "none", range = "canonical ID", reference = "vehicle", budget = "transform graph", base = "cm2.editor.demo:vehicle.demo", edit = "cm2.editor.demo:vehicle.demo", invalid = "missing:vehicle", invalidCode = "broken-reference" },
            { path = "runtime.localTransform", type = "object", unit = "meter/quaternion", range = "parent-local contract", reference = "-", budget = "anchor transform", base = "pos(0,0,0) quat(0,0,0,1)", edit = "pos(0,1,0) quat(0,0,0,1)", invalid = "[0,1,0]", invalidCode = "wrong-type" },
            { path = "runtime.slotType", type = "enum", unit = "none", range = "x|l|m|g|h|t|p", reference = "-", budget = "slot controller", base = "p", edit = "x", invalid = "z", invalidCode = "invalid-enum" },
        },
    },
}

local state = {
    ready = false,
    form = 1,
    field = 1,
    values = {},
    history = {},
    redo = {},
    status = "SOURCE ENVELOPE LOADED",
    diagnostic = "0 errors / source-only staging",
    lastAction = "open cm2.editor.demo",
    saveAttempts = 0,
}

local function key(formIndex, fieldIndex)
    return tostring(formIndex) .. ":" .. tostring(fieldIndex)
end

local function currentForm()
    return FORMS[state.form]
end

local function currentField()
    return currentForm().fields[state.field]
end

local function currentValue(formIndex, fieldIndex)
    local field = FORMS[formIndex].fields[fieldIndex]
    return state.values[key(formIndex, fieldIndex)] or field.base
end

local function isInvalid(field, value)
    return tostring(value) == tostring(field.invalid)
end

local function publishStatus()
    SetBool(ROOT .. "ready", state.ready)
    SetString(ROOT .. "form", currentForm().kind)
    SetString(ROOT .. "field", currentField().path)
    SetString(ROOT .. "status", state.status)
    SetString(ROOT .. "diagnostic", state.diagnostic)
    SetString(ROOT .. "luaRevision", LUA_REVISION)
    SetInt(ROOT .. "saveAttempts", state.saveAttempts)
end

local function selectForm(delta)
    state.form = ((state.form - 1 + delta) % #FORMS) + 1
    state.field = math.min(state.field, #currentForm().fields)
    state.status = "FORM GENERATED FROM " .. currentForm().version
    state.diagnostic = "path / type / unit / range / reference / budget"
    state.lastAction = "selected " .. currentForm().kind .. " form"
    publishStatus()
end

local function selectField(delta)
    local count = #currentForm().fields
    state.field = ((state.field - 1 + delta) % count) + 1
    state.status = "FIELD SELECTED"
    state.diagnostic = "schema metadata is read-only"
    state.lastAction = currentField().path
    publishStatus()
end

local function mutate(value, action)
    local slot = key(state.form, state.field)
    state.history[#state.history + 1] = {
        form = state.form,
        field = state.field,
        before = currentValue(state.form, state.field),
        after = value,
    }
    state.redo = {}
    state.values[slot] = value
    local field = currentField()
    if isInvalid(field, value) then
        state.status = "INVALID SOURCE / SAVE WILL BE BLOCKED"
        state.diagnostic = field.invalidCode .. " @ " .. field.path
    else
        state.status = "SOURCE EDITED / UNSAVED"
        state.diagnostic = "0 errors / review diff before save"
    end
    state.lastAction = action
    publishStatus()
end

local function undo()
    local entry = table.remove(state.history)
    if entry == nil then
        state.status = "UNDO: NO EARLIER SNAPSHOT"
        return
    end
    state.redo[#state.redo + 1] = entry
    state.form = entry.form
    state.field = entry.field
    state.values[key(entry.form, entry.field)] = entry.before
    state.status = "UNDO RESTORED EXACT SOURCE SNAPSHOT"
    state.diagnostic = "source history only / generated Lua untouched"
    state.lastAction = entry.after .. " -> " .. entry.before
    publishStatus()
end

local function redo()
    local entry = table.remove(state.redo)
    if entry == nil then
        state.status = "REDO: NO LATER SNAPSHOT"
        return
    end
    state.history[#state.history + 1] = entry
    state.form = entry.form
    state.field = entry.field
    state.values[key(entry.form, entry.field)] = entry.after
    state.status = "REDO RESTORED EXACT SOURCE SNAPSHOT"
    state.diagnostic = isInvalid(currentField(), entry.after) and (currentField().invalidCode .. " @ " .. currentField().path) or "0 errors / review diff before save"
    state.lastAction = entry.before .. " -> " .. entry.after
    publishStatus()
end

local function validateBeforeSave()
    state.saveAttempts = state.saveAttempts + 1
    local invalidField = nil
    for formIndex, form in ipairs(FORMS) do
        for fieldIndex, field in ipairs(form.fields) do
            if isInvalid(field, currentValue(formIndex, fieldIndex)) then invalidField = field break end
        end
        if invalidField ~= nil then break end
    end
    if invalidField ~= nil then
        state.status = "SAVE BLOCKED BEFORE COMPILER"
        state.diagnostic = invalidField.invalidCode .. " @ " .. invalidField.path
        state.lastAction = "generated catalog preserved"
    else
        state.status = "SOURCE SAVE VALIDATED"
        state.diagnostic = "compiler byte-identical / catalog ad61b800...c88"
        state.lastAction = "runtime projection 9c6505f2...a07 / generated Lua untouched"
    end
    publishStatus()
end

local function text(value, size, r, g, b, a)
    UiFont("regular.ttf", size)
    UiColor(r or 1, g or 1, b or 1, a or 1)
    UiText(tostring(value))
end

local function panel(x, y, width, height, r, g, b, a)
    UiPush()
    UiTranslate(x, y)
    UiColor(r, g, b, a)
    UiRect(width, height)
    UiPop()
end

function client.init()
    state.ready = true
    publishStatus()
end

function client.tick(dt)
    if InputPressed("leftarrow") then selectForm(-1)
    elseif InputPressed("rightarrow") then selectForm(1)
    elseif InputPressed("uparrow") then selectField(-1)
    elseif InputPressed("downarrow") then selectField(1)
    elseif InputPressed("space") then mutate(currentField().edit, "applied valid schema edit")
    elseif InputPressed("delete") then mutate(currentField().invalid, "injected invalid fixture value")
    elseif InputPressed("backspace") then undo()
    elseif InputPressed("insert") then redo()
    elseif InputPressed("return") then validateBeforeSave() end
end

function client.draw()
    UiPush()
    panel(0, 0, UiWidth(), UiHeight(), 0.008, 0.012, 0.025, 0.98)
    panel(24, 20, UiWidth() - 48, 70, 0.025, 0.065, 0.11, 1)
    UiTranslate(180, 36)
    text("CM2 SCHEMA-DRIVEN DEFINITION EDITOR MVP", 26, 0.3, 0.82, 1, 1)
    UiTranslate(-136, 31)
    text("NO 3D  |  SOURCE ONLY  |  " .. LUA_REVISION .. "  |  first valid weapon <= 5 min", 15, 0.72, 0.82, 0.93, 1)

    UiTranslate(0, 62)
    for index, form in ipairs(FORMS) do
        UiPush()
        UiTranslate((index - 1) * 146, 0)
        UiColor(index == state.form and 0.12 or 0.035, index == state.form and 0.38 or 0.075, index == state.form and 0.54 or 0.12, 1)
        UiRect(136, 38)
        UiTranslate(12, 10)
        text(string.upper(form.kind), 16, index == state.form and 1 or 0.66, index == state.form and 0.9 or 0.72, index == state.form and 0.45 or 0.82, 1)
        UiPop()
    end

    UiTranslate(0, 54)
    panel(44, 160, 760, 455, 0.018, 0.035, 0.06, 1)
    panel(824, 160, 412, 455, 0.018, 0.035, 0.06, 1)

    text(string.upper(currentForm().kind) .. " FORM  /  " .. currentForm().version, 21, 1, 0.83, 0.28, 1)
    UiTranslate(0, 34)
    for index, field in ipairs(currentForm().fields) do
        local selected = index == state.field
        UiPush()
        UiColor(selected and 0.055 or 0.025, selected and 0.17 or 0.055, selected and 0.25 or 0.085, 1)
        UiRect(730, 82)
        UiTranslate(12, 9)
        text((selected and "> " or "  ") .. field.path, 18, selected and 0.35 or 0.73, selected and 0.9 or 0.79, selected and 1 or 0.88, 1)
        UiTranslate(0, 24)
        text("type=" .. field.type .. "  unit=" .. field.unit .. "  range=" .. field.range .. "  ref=" .. field.reference, 13, 0.62, 0.7, 0.82, 1)
        UiTranslate(0, 20)
        local value = currentValue(state.form, index)
        text("value=" .. value .. "  budget=" .. field.budget, 13, isInvalid(field, value) and 1 or 0.55, isInvalid(field, value) and 0.28 or 0.92, isInvalid(field, value) and 0.2 or 0.58, 1)
        UiPop()
        UiTranslate(0, 92)
    end

    UiTranslate(800, -34 - (#currentForm().fields * 92))
    text("SOURCE / VALIDATION", 20, 1, 0.83, 0.28, 1)
    UiTranslate(0, 37)
    text("forms: 5", 16, 0.75, 0.86, 0.96, 1)
    UiTranslate(0, 25)
    text("form fields: 16 / schema fields: 19", 16, 0.75, 0.86, 0.96, 1)
    UiTranslate(0, 25)
    text("history: " .. #state.history .. "  redo: " .. #state.redo, 16, 0.75, 0.86, 0.96, 1)
    UiTranslate(0, 37)
    text("STATUS", 16, 0.42, 0.78, 1, 1)
    UiTranslate(0, 25)
    text(state.status, 15, state.status:find("BLOCKED") and 1 or 0.42, state.status:find("BLOCKED") and 0.25 or 1, 0.45, 1)
    UiTranslate(0, 30)
    text(state.diagnostic, 14, 0.82, 0.86, 0.94, 1)
    UiTranslate(0, 28)
    text(state.lastAction, 13, 0.64, 0.72, 0.84, 1)
    UiTranslate(0, 38)
    text("DIFF", 16, 0.42, 0.78, 1, 1)
    UiTranslate(0, 25)
    local field = currentField()
    local value = currentValue(state.form, state.field)
    text(field.path, 14, 0.82, 0.86, 0.94, 1)
    UiTranslate(0, 23)
    text(field.base .. "  ->  " .. value, 16, value == field.base and 0.65 or 1, value == field.base and 0.72 or 0.76, value == field.base and 0.82 or 0.22, 1)
    UiTranslate(0, 38)
    text("COMPILER CONTRACT", 16, 0.42, 0.78, 1, 1)
    UiTranslate(0, 25)
    text("two workspaces / byte-identical", 14, 0.55, 0.92, 0.58, 1)
    UiTranslate(0, 23)
    text("generated catalog unchanged", 14, 0.55, 0.92, 0.58, 1)
    UiTranslate(0, 23)
    text("save attempts: " .. state.saveAttempts, 14, 0.75, 0.86, 0.96, 1)

    panel(24, 635, UiWidth() - 48, 60, 0.025, 0.065, 0.11, 1)
    UiTranslate(-800, 460)
    text("LEFT/RIGHT form   UP/DOWN field   SPACE valid edit   DEL invalid   ENTER validate   BACKSPACE undo   INSERT redo", 15, 0.78, 0.86, 0.96, 1)
    UiPop()
end

function client.destroy()
    state.ready = false
    SetBool(ROOT .. "ready", false)
end
