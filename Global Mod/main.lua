#version 2
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

--This script will run on all levels when mod is active.
--Modding documentation: http://teardowngame.com/modding
--API reference: http://teardowngame.com/modding/api.html

#include "client/client.lua"
-- #include "server/bodyDriverSync.lua"
-- #include "server/registry/shipRegistryRequest.lua"

function server.init()
end

function server.tick(dt)
    -- server.bodyDriverSyncTick(dt)
    -- -- 预留给 ServerCall 的服务端 registry 请求入口（函数由客户端主动调用）
end

function server.update(dt)
end

function client.init()
end

function client.tick(dt)
    DebugWatch("client.clientTick",-11111)
    client.clientTick(dt)
end

function client.draw()
    client.clientDraw()
end

function client.update(dt)
end
