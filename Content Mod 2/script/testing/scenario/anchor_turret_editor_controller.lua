#version 2

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: undefined-field

-- Disposable live host for the Step 8.5 source editor contract. The included
-- adapter owns parent-local edits and source patches. This host owns only the
-- read-only VOX preview, real-input mapping and objective visual diagnostics.

client = client or {}

#include "../../world/adapter/anchor_turret_editor_v1.lua"

local ROOT = "StellarisShips/testing/anchorTurretEditor/"
local LUA_REVISION = "anchor-turret-editor-lua-v1"
local VOX_HASH = "c52e69f18a71f54f1259d90570a9d6d9bc917e4d26aa4cfbd2242ad69c06788f"
local MANIFEST_HASH = "009135e9ba3cf5a9c1b57222ec712de910584973933ca1edee1f0afa01448e18"
local CHANNELS = { "ANCHOR", "MOUNT", "TURRET", "GRAPH / BUDGET" }
local MOUNT_MODES = { "fixed", "logical", "visual", "joint" }

local ASSET_MANIFEST = {
    readOnly = true,
    manifestHash = MANIFEST_HASH,
    voxPath = "MOD/vox/gammaStrikeCraftTest.vox",
    voxHash = VOX_HASH,
    metersPerVoxel = 0.1,
    logicalSizeVoxels = { 45, 12, 51 },
    sourceToVox = "logical(x,y,z) -> vox(x,maxZ-1-z,y)",
    voxToTeardown = "vox(x,y,z) -> logical(x,z,maxZ-1-y)",
}

local GRAPH = {
    definitionId = "gamma-editor-graph",
    nodes = {
        { nodeId = "root", partId = "root", kind = "body", parentId = "", localTransform = { position = { 10, 2, -4 }, scale = { 2, 2, 2 }, mirror = { 1, 1, 1 } } },
        { nodeId = "wing", partId = "wing", kind = "part", parentId = "root", localTransform = { position = { 1, 0, 0 }, scale = { 1, 2, 1 }, mirror = { -1, 1, 1 } } },
        { nodeId = "nozzle", partId = "nozzle", kind = "engine", parentId = "wing", localTransform = { position = { 0, 0, -2 }, scale = { 0.5, 0.5, 1 }, mirror = { 1, 1, -1 } } },
    },
}

local BUDGETS = {
    fixed = { body = 1, shape = 1, joint = 0 },
    logical = { body = 1, shape = 1, joint = 0 },
    visual = { body = 0, shape = 0, joint = 0 },
    joint = { body = 2, shape = 2, joint = 1 },
}

local state = {
    ready = false,
    channel = 1,
    mode = 2,
    shape = 0,
    boundsMin = nil,
    boundsMax = nil,
    boundsCenter = Vec(0, 2, 0),
    status = "INITIALIZING READ-ONLY VOX",
    diagnostic = "waiting for shape bounds",
    lastAction = "load AssetManifest + EntityGraph",
    rejected = 0,
    arc = nil,
    liveIds = { anchor = false, mount = false, turret = false },
}

local function vecText(value)
    local source = type(value) == "table" and value or { 0, 0, 0 }
    return string.format("[%.2f, %.2f, %.2f]", tonumber(source[1]) or 0, tonumber(source[2]) or 0, tonumber(source[3]) or 0)
end

local function publishStatus()
    local patch = cm2AnchorTurretEditorV1.sourcePatch()
    SetBool(ROOT .. "ready", state.ready)
    SetString(ROOT .. "luaRevision", LUA_REVISION)
    SetString(ROOT .. "channel", CHANNELS[state.channel])
    SetString(ROOT .. "mode", MOUNT_MODES[state.mode])
    SetString(ROOT .. "status", state.status)
    SetString(ROOT .. "diagnostic", state.diagnostic)
    SetInt(ROOT .. "patches", patch and #patch.patches or 0)
    SetInt(ROOT .. "rejected", state.rejected)
end

local function requireEdit(ok, errorText, successText)
    if not ok then
        state.rejected = state.rejected + 1
        state.status = "BUILD BLOCKED BEFORE SOURCE PATCH"
        state.diagnostic = tostring(errorText or "editor operation rejected")
        publishStatus()
        return false
    end
    state.status = successText
    state.diagnostic = "parent-local patch appended / generated mutation=false"
    publishStatus()
    return true
end

local function initialAnchor(id, parentId, kind, position)
    return cm2AnchorTurretEditorV1.addAnchor({
        id = id,
        parentPartId = parentId,
        kind = kind,
        localTransform = { position = position, rotation = { 0, 0, 0 } },
    })
end

local function initializeEditor()
    local ok, errorText = cm2AnchorTurretEditorV1.init(ASSET_MANIFEST, GRAPH, {
        sourceRevision = 2,
        viewSpace = "local",
        mode = "logical",
        budgets = BUDGETS,
        budgetLimits = { body = 2, shape = 8, joint = 4 },
    })
    if not ok then return false, errorText end
    local operations = {
        { initialAnchor("root.camera", "root", "camera", { 0, 1.1, 0.5 }) },
        { initialAnchor("wing.muzzle.left", "wing", "muzzle", { -0.7, 0.2, -2.65 }) },
        { initialAnchor("wing.muzzle.right", "wing", "muzzle", { 0.7, 0.2, -2.65 }) },
        { initialAnchor("nozzle.engine", "nozzle", "engine", { 0, -0.1, 2.65 }) },
        { cm2AnchorTurretEditorV1.addMount({ id = "mount.primary", parentPartId = "wing", slotType = "x", localTransform = { position = { -1.35, 0.25, -0.35 } } }) },
        { cm2AnchorTurretEditorV1.addMount({ id = "mount.secondary", parentPartId = "wing", slotType = "x", localTransform = { position = { 1.35, 0.25, -0.35 } } }) },
        { cm2AnchorTurretEditorV1.addTurret({ id = "turret.hero", basePartId = "wing", baseAnchorId = "wing.muzzle.left", mode = "logical", yaw = { axis = { 0, 1, 0 }, min = -70, max = 70, speed = 120 }, pitch = { axis = { 1, 0, 0 }, min = -25, max = 35, speed = 90 }, idle = { yaw = 0, pitch = 0 }, arcPreview = { samples = 7, stepDeg = 20 } }) },
        { cm2AnchorTurretEditorV1.orderMuzzles("primary", { "wing.muzzle.left", "wing.muzzle.right" }) },
    }
    for _, operation in ipairs(operations) do if operation[1] ~= true then return false, operation[2] end end
    state.arc = cm2AnchorTurretEditorV1.previewArc("turret.hero")
    return true
end

local function addLiveAnchor()
    local ok, errorText = cm2AnchorTurretEditorV1.addAnchor({
        id = "wing.sensor.live",
        parentPartId = "wing",
        kind = "sensor",
        localTransform = { position = { 1.1, 0.75, 0.4 }, rotation = { 0, 0, 0 } },
    })
    if requireEdit(ok, errorText, "ANCHOR CREATED FROM REAL INPUT") then state.liveIds.anchor = true end
end

local function moveLiveAnchor()
    local id = state.liveIds.anchor and "wing.sensor.live" or "wing.muzzle.left"
    local snapshot = cm2AnchorTurretEditorV1.snapshot()
    local anchor = snapshot.anchors[id]
    local current = anchor and anchor.localTransform and anchor.localTransform.position or { -0.7, 0.2, -2.65 }
    local position = { (tonumber(current[1]) or 0) + 0.2, tonumber(current[2]) or 0, tonumber(current[3]) or 0 }
    local ok, errorText = cm2AnchorTurretEditorV1.moveAnchor(id, { position = position, rotation = { 0, 0, 0 } })
    requireEdit(ok, errorText, "ANCHOR MOVED +0.20 m LOCAL X")
end

local function mirrorLiveAnchor()
    local id = state.liveIds.anchor and "wing.sensor.live" or "wing.muzzle.left"
    local ok, errorText = cm2AnchorTurretEditorV1.mirrorAnchor(id, "X")
    requireEdit(ok, errorText, "ANCHOR MIRRORED ACROSS LOCAL X")
end

local function addLiveMount()
    local ok, errorText = cm2AnchorTurretEditorV1.addMount({
        id = "mount.live",
        parentPartId = "wing",
        slotType = "x",
        localTransform = { position = { 0, 0.55, -0.4 } },
    })
    if requireEdit(ok, errorText, "MOUNT CREATED FROM REAL INPUT") then state.liveIds.mount = true end
end

local function addLiveTurret()
    local ok, errorText = cm2AnchorTurretEditorV1.addTurret({
        id = "turret.live",
        basePartId = "root",
        baseAnchorId = "root.camera",
        mode = MOUNT_MODES[state.mode],
        yaw = { axis = { 0, 1, 0 }, min = -45, max = 45, speed = 90 },
        pitch = { axis = { 1, 0, 0 }, min = -15, max = 30, speed = 60 },
        idle = { yaw = 0, pitch = 0 },
        arcPreview = { samples = 7, stepDeg = 15 },
    })
    if requireEdit(ok, errorText, "TURRET BASE + YAW/PITCH AXES CREATED") then state.liveIds.turret = true end
end

local function validateEditor()
    local ok, errors = cm2AnchorTurretEditorV1.validate()
    if ok then
        state.status = "SOURCE PATCH VALIDATED / BUILD READY"
        state.diagnostic = "graph valid / budgets <= Runtime limits"
    else
        state.status = "BUILD BLOCKED BEFORE SOURCE PATCH"
        state.diagnostic = table.concat(errors or { "validation failed" }, ", ")
    end
    publishStatus()
end

local function injectDuplicate()
    local ok, errorText = cm2AnchorTurretEditorV1.addAnchor({ id = "wing.muzzle.left", parentPartId = "wing", kind = "muzzle", localTransform = { position = { 0, 0, 0 } } })
    requireEdit(ok, errorText, "unexpected duplicate acceptance")
end

local function toggleView()
    local snapshot = cm2AnchorTurretEditorV1.snapshot()
    local requested = snapshot.viewSpace == "local" and "world" or "local"
    local ok, errorText = cm2AnchorTurretEditorV1.setViewSpace(requested)
    requireEdit(ok, errorText, string.upper(requested) .. " TRANSFORM VIEW")
end

local function selectMode(delta)
    state.mode = ((state.mode - 1 + delta) % #MOUNT_MODES) + 1
    local ok, errorText = cm2AnchorTurretEditorV1.setMode(MOUNT_MODES[state.mode])
    requireEdit(ok, errorText, "MOUNT MODE: " .. string.upper(MOUNT_MODES[state.mode]))
end

local function updateBounds()
    if state.shape == 0 then state.shape = FindShape("cm2AnchorEditorVox", true) end
    if state.shape ~= 0 then
        state.boundsMin, state.boundsMax = GetShapeBounds(state.shape)
        state.boundsCenter = VecLerp(state.boundsMin, state.boundsMax, 0.5)
    end
end

local function marker(position, r, g, b, size)
    local s = tonumber(size) or 0.24
    DrawLine(VecAdd(position, Vec(-s, 0, 0)), VecAdd(position, Vec(s, 0, 0)), r, g, b, 1)
    DrawLine(VecAdd(position, Vec(0, -s, 0)), VecAdd(position, Vec(0, s, 0)), r, g, b, 1)
    DrawLine(VecAdd(position, Vec(0, 0, -s)), VecAdd(position, Vec(0, 0, s)), r, g, b, 1)
end

local function anchorPosition(id, fallback)
    local snapshot = cm2AnchorTurretEditorV1.snapshot()
    local anchor = snapshot.anchors[id]
    local position = anchor and anchor.localTransform and anchor.localTransform.position or fallback
    return VecAdd(state.boundsCenter, Vec(tonumber(position[1]) or 0, tonumber(position[2]) or 0, tonumber(position[3]) or 0))
end

local function drawArc(center)
    local points = state.arc or {}
    local previous = nil
    for _, sample in ipairs(points) do
        local radians = math.rad(tonumber(sample.yaw) or 0)
        local point = VecAdd(center, Vec(math.sin(radians) * 2.0, 0.25, -math.cos(radians) * 2.0))
        marker(point, 0.95, 0.35, 1.0, 0.12)
        if previous ~= nil then DrawLine(previous, point, 0.8, 0.25, 1.0, 0.8) end
        previous = point
    end
end

local function text(value, size, r, g, b, a)
    UiFont("regular.ttf", size)
    UiColor(r or 1, g or 1, b or 1, a or 1)
    UiText(tostring(value))
    UiTranslate(0, size + 7)
end

function client.init()
    local ok, errorText = initializeEditor()
    if not ok then
        state.status = "EDITOR INIT BLOCKED"
        state.diagnostic = tostring(errorText or "unknown init error")
        publishStatus()
        return
    end
    state.ready = true
    state.status = "READ-ONLY VOX + SOURCE GRAPH READY"
    state.diagnostic = "right-handed Y-up / forward -Z / 0.1 m per voxel"
    state.lastAction = "AssetManifest and VOX hash matched"
    updateBounds()
    publishStatus()
end

function client.tick(dt)
    SetCameraTransform(Transform(Vec(0, 8, 18), QuatLookAt(Vec(0, 8, 18), Vec(0, 2, 0))))
    updateBounds()
    if InputPressed("leftarrow") then state.channel = state.channel == 1 and #CHANNELS or state.channel - 1; state.status = "CHANNEL: " .. CHANNELS[state.channel]; publishStatus()
    elseif InputPressed("rightarrow") then state.channel = state.channel == #CHANNELS and 1 or state.channel + 1; state.status = "CHANNEL: " .. CHANNELS[state.channel]; publishStatus()
    elseif InputPressed("a") then addLiveAnchor()
    elseif InputPressed("space") then moveLiveAnchor()
    elseif InputPressed("m") then mirrorLiveAnchor()
    elseif InputPressed("k") then addLiveMount()
    elseif InputPressed("home") then addLiveTurret()
    elseif InputPressed("end") then toggleView()
    elseif InputPressed("uparrow") then selectMode(1)
    elseif InputPressed("downarrow") then selectMode(-1)
    elseif InputPressed("delete") then injectDuplicate()
    elseif InputPressed("return") then validateEditor() end
end

function client.render()
    if not state.ready or state.shape == 0 then return end
    local center = state.boundsCenter
    -- Canonical axes: right +X red, up +Y green, forward -Z blue.
    DrawLine(center, VecAdd(center, Vec(3.2, 0, 0)), 1, 0.15, 0.12, 1)
    DrawLine(center, VecAdd(center, Vec(0, 3.2, 0)), 0.2, 1, 0.35, 1)
    DrawLine(center, VecAdd(center, Vec(0, 0, -3.2)), 0.2, 0.55, 1, 1)

    marker(anchorPosition("wing.muzzle.left", { -0.7, 0.2, -2.65 }), 1, 0.2, 0.1, 0.34)
    marker(anchorPosition("wing.muzzle.right", { 0.7, 0.2, -2.65 }), 1, 0.2, 0.1, 0.34)
    marker(anchorPosition("nozzle.engine", { 0, -0.1, 2.65 }), 0.1, 0.7, 1, 0.34)
    marker(anchorPosition("root.camera", { 0, 1.1, 0.5 }), 1, 0.8, 0.1, 0.34)
    if state.liveIds.anchor then marker(anchorPosition("wing.sensor.live", { 1.1, 0.75, 0.4 }), 0.1, 1, 0.65, 0.42) end

    marker(VecAdd(center, Vec(-1.35, 0.25, -0.35)), 1, 0.75, 0.12, 0.3)
    marker(VecAdd(center, Vec(1.35, 0.25, -0.35)), 1, 0.75, 0.12, 0.3)
    if state.liveIds.mount then marker(VecAdd(center, Vec(0, 0.55, -0.4)), 1, 1, 0.2, 0.45) end

    local turretCenter = VecAdd(center, Vec(-0.7, 0.65, -1.3))
    marker(turretCenter, 0.9, 0.25, 1, 0.48)
    DrawLine(turretCenter, VecAdd(turretCenter, Vec(0, 1.4, 0)), 0.25, 1, 0.35, 1)
    DrawLine(turretCenter, VecAdd(turretCenter, Vec(1.4, 0, 0)), 1, 0.2, 0.12, 1)
    drawArc(turretCenter)
end

function client.draw()
    local snapshot = cm2AnchorTurretEditorV1.snapshot()
    local patch = cm2AnchorTurretEditorV1.sourcePatch()
    local budget = cm2AnchorTurretEditorV1.getBudget(MOUNT_MODES[state.mode])
    local anchorCount, mountCount, turretCount = 0, 0, 0
    for _ in pairs(snapshot.anchors or {}) do anchorCount = anchorCount + 1 end
    for _ in pairs(snapshot.mounts or {}) do mountCount = mountCount + 1 end
    for _ in pairs(snapshot.turrets or {}) do turretCount = turretCount + 1 end

    UiPush()
    UiTranslate(30, 74)
    UiColor(0.012, 0.022, 0.045, 0.94)
    UiRect(590, 505)
    UiTranslate(20, 18)
    text("CM2 VOX / ANCHOR / MOUNT / TURRET EDITOR", 24, 0.3, 0.82, 1, 1)
    text(LUA_REVISION .. "  |  read-only asset", 15, 0.72, 0.82, 0.94, 1)
    text("ACTIVE: " .. CHANNELS[state.channel] .. "  /  " .. string.upper(snapshot.viewSpace), 19, 1, 0.82, 0.24, 1)
    text("VOX 45 x 12 x 51  @ 0.1 m   SHA c52e69f...788f", 15, 0.76, 0.86, 0.96, 1)
    text("AXES  +X RIGHT / +Y UP / -Z FORWARD", 15, 1, 0.55, 0.3, 1)
    text("root world " .. vecText({ 10, 2, -4 }) .. " scale [2,2,2]", 15, 0.75, 0.84, 0.94, 1)
    text("wing local [1,0,0] -> world [12,2,-4] mirror [-1,1,1]", 15, 0.75, 0.84, 0.94, 1)
    text("anchors=" .. anchorCount .. "  mounts=" .. mountCount .. "  turrets=" .. turretCount .. "  arc=7", 16, 0.45, 1, 0.62, 1)
    text("mode=" .. MOUNT_MODES[state.mode] .. "  budget B/S/J=" .. budget.body .. "/" .. budget.shape .. "/" .. budget.joint .. "  limits 2/8/4", 15, 0.78, 0.88, 1, 1)
    text("source patches=" .. #patch.patches .. "  generated mutation=" .. tostring(patch.generatedArtifactMutation), 15, 0.45, 1, 0.62, 1)
    text("STATUS: " .. state.status, 15, state.status:find("BLOCKED") and 1 or 0.38, state.status:find("BLOCKED") and 0.25 or 1, 0.42, 1)
    text(state.diagnostic .. "  /  rejects=" .. state.rejected, 14, 0.8, 0.85, 0.94, 1)
    text("A add anchor  SPACE move  M mirror  K add mount  HOME add turret", 14, 0.8, 0.88, 1, 1)
    text("END local/world  UP/DOWN mode  DEL duplicate gate  ENTER validate", 14, 0.8, 0.88, 1, 1)
    UiPop()
end

function client.destroy()
    cm2AnchorTurretEditorV1.dispose()
    state.ready = false
    publishStatus()
end
