---@diagnostic disable: undefined-global

-- The registry is intentionally visual-only.  It maps data profile names to
-- reusable client implementations; it does not alter server weapon behavior.
client = client or {}
client.weaponFxProfiles = client.weaponFxProfiles or {}

function client.weaponFxRegister(phase, profileId, implementation)
    local phaseId = tostring(phase or "")
    local id = tostring(profileId or "")
    if phaseId == "" or id == "" or type(implementation) ~= "table" then
        error("invalid weapon effect profile registration")
    end
    client.weaponFxProfiles[phaseId] = client.weaponFxProfiles[phaseId] or {}
    local current = client.weaponFxProfiles[phaseId][id] or {}
    for key, value in pairs(implementation) do current[key] = value end
    client.weaponFxProfiles[phaseId][id] = current
end

function client.weaponFxResolve(phase, profileId)
    local profiles = (client.weaponFxProfiles or {})[tostring(phase or "")] or {}
    return profiles[tostring(profileId or "")] or profiles.default
end
