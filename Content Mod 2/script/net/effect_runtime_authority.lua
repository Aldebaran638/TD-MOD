---@diagnostic disable: undefined-global

-- Init-time authority gate. It makes legacy/event-v1 mutually exclusive for
-- a context and gives cutover/rollback one auditable switch.
cm2EffectRuntimeAuthority = cm2EffectRuntimeAuthority or {}
local authority = cm2EffectRuntimeAuthority

authority.state = authority.state or {
    initialized = false,
    mode = "legacy",
    legacyDispatchEnabled = true,
    candidateDispatchEnabled = false,
    dualPlaybackRejected = 0,
    legacyAdapterCalls = 0,
    candidateCalls = 0,
}

function authority.init()
    local state = authority.state
    if state.initialized then return state end
    local selected = (GetStringParam ~= nil and GetStringParam("effectRuntime", "legacy")) or "legacy"
    selected = tostring(selected or "legacy")
    if selected ~= "legacy" and selected ~= "event-v1" then selected = "legacy" end
    state.mode = selected
    state.legacyDispatchEnabled = selected == "legacy"
    state.candidateDispatchEnabled = selected == "event-v1"
    state.dualPlaybackRejected = 0
    state.legacyAdapterCalls = 0
    state.candidateCalls = 0
    state.initialized = true
    return state
end

function authority.isLegacy()
    return authority.init().mode == "legacy"
end

function authority.isEventV1()
    return authority.init().mode == "event-v1"
end

function authority.recordLegacyAdapterCall()
    local state = authority.init()
    if not state.legacyDispatchEnabled then
        state.dualPlaybackRejected = state.dualPlaybackRejected + 1
        return false
    end
    state.legacyAdapterCalls = state.legacyAdapterCalls + 1
    return true
end

function authority.recordCandidateCall()
    local state = authority.init()
    if not state.candidateDispatchEnabled then
        state.dualPlaybackRejected = state.dualPlaybackRejected + 1
        return false
    end
    state.candidateCalls = state.candidateCalls + 1
    return true
end

function authority.getReport()
    local state = authority.init()
    return {
        mode = state.mode,
        legacyDispatchEnabled = state.legacyDispatchEnabled,
        candidateDispatchEnabled = state.candidateDispatchEnabled,
        dualPlaybackRejected = state.dualPlaybackRejected,
        legacyAdapterCalls = state.legacyAdapterCalls,
        candidateCalls = state.candidateCalls,
    }
end
