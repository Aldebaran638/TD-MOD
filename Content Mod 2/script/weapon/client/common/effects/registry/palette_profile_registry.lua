---@diagnostic disable: undefined-global

client = client or {}
client.weaponFxPalettes = client.weaponFxPalettes or {}

function client.weaponFxPaletteRegister(profileId, values)
    local id = tostring(profileId or "")
    if id == "" or type(values) ~= "table" then error("invalid weapon palette registration") end
    client.weaponFxPalettes[id] = values
end

function client.weaponFxGetPalette(profileId)
    local palettes = client.weaponFxPalettes or {}
    return palettes[tostring(profileId or "")] or palettes.default
end

client.weaponFxPaletteRegister("default", {
    chargeColor = { 0.96, 1.00, 1.00, 0.16, 0.45, 1.00 },
    beamOuterColor = { 0.08, 0.35, 1.00 },
    beamCoreColor = { 0.30, 1.10, 1.80 },
    muzzleColor = { 0.35, 0.70, 1.00 },
    impactColor = { 0.35, 0.70, 1.00 },
    intensityScale = 1.0,
})

client.weaponFxPaletteRegister("particleLance", {
    chargeColor = { 1.00, 0.18, 0.04, 0.45, 0.03, 0.01 },
    beamOuterColor = { 0.95, 0.03, 0.01 },
    beamCoreColor = { 1.80, 0.42, 0.12 },
    muzzleColor = { 1.00, 0.32, 0.08 },
    impactColor = { 1.00, 0.20, 0.05 },
    intensityScale = 1.0,
})
