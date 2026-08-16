#version 2

---@diagnostic disable: undefined-global

server = server or {}

local ROOT = "StellarisShips/testing/scenario/"
local LUA_REVISION = "scenario-controller-v2"

function server.init()
    -- Scenario-level presentation mode is an opt-in test configuration. Clear
    -- the replicated value first so a later legacy reload cannot inherit it.
    SetString(ROOT .. "presentationRuntime", "", true)
    local requestedPresentationRuntime = tostring(
        GetStringParam("presentationRuntime", "") or ""
    )
    if requestedPresentationRuntime == "legacy"
        or requestedPresentationRuntime == "event-v1" then
        SetString(ROOT .. "presentationRuntime", requestedPresentationRuntime, true)
    end
    SetString(ROOT .. "id", GetStringParam("scenario", "unknown"), true)
    SetString(ROOT .. "xmlRevision", GetStringParam("revision", "unversioned"), true)
    SetString(ROOT .. "luaRevision", LUA_REVISION, true)
    SetBool(ROOT .. "ready", true, true)
end

function server.destroy()
    SetBool(ROOT .. "ready", false, true)
end
