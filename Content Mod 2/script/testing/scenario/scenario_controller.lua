#version 2

---@diagnostic disable: undefined-global

server = server or {}

local ROOT = "StellarisShips/testing/scenario/"
local LUA_REVISION = "scenario-controller-v2"

function server.init()
    SetString(ROOT .. "id", GetStringParam("scenario", "unknown"), true)
    SetString(ROOT .. "xmlRevision", GetStringParam("revision", "unversioned"), true)
    SetString(ROOT .. "luaRevision", LUA_REVISION, true)
    SetBool(ROOT .. "ready", true, true)
end

function server.destroy()
    SetBool(ROOT .. "ready", false, true)
end
