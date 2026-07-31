---@diagnostic disable: undefined-global

client = client or {}

client.pointDefenseFxState = client.pointDefenseFxState or { traces = {} }

function client.pointDefenseFxInit()
    client.pointDefenseFxState = { traces = {} }
end

function client.spawnPointDefenseFx(role, sx, sy, sz, ex, ey, ez, duration)
    local state = client.pointDefenseFxState or { traces = {} }
    client.pointDefenseFxState = state
    state.traces[#state.traces + 1] = {
        role = tostring(role or "missile"),
        startPosition = Vec(sx or 0, sy or 0, sz or 0),
        endPosition = Vec(ex or 0, ey or 0, ez or 0),
        life = math.max(0.03, tonumber(duration) or 0.08),
        age = 0.0,
    }
end

function client.pointDefenseFxTick(dt)
    local traces = (client.pointDefenseFxState or {}).traces or {}
    for index = #traces, 1, -1 do
        local trace = traces[index]
        trace.age = (tonumber(trace.age) or 0.0) + math.max(0.0, tonumber(dt) or 0.0)
        if trace.age >= (tonumber(trace.life) or 0.08) then
            table.remove(traces, index)
        end
    end
end

function client.pointDefenseFxRender()
    for _, trace in ipairs((client.pointDefenseFxState or {}).traces or {}) do
        local life = math.max(0.01, tonumber(trace.life) or 0.08)
        local progress = math.max(0.0, math.min(1.0, (trace.age or 0.0) / life))
        local alpha = 1.0 - progress
        if trace.role == "flak" then
            local head = VecLerp(trace.startPosition, trace.endPosition, progress)
            local tail = VecLerp(
                trace.startPosition,
                trace.endPosition,
                math.max(0.0, progress - 0.10)
            )
            DrawLine(tail, head, 1.0, 0.78, 0.22, alpha)
        else
            DrawLine(
                trace.startPosition,
                trace.endPosition,
                0.32,
                0.88,
                1.0,
                alpha
            )
        end
    end
end
