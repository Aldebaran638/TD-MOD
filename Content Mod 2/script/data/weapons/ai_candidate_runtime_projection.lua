---@diagnostic disable: undefined-global

-- Human-approved Step 10.2 projection.  This is deliberately a Runtime
-- fixture adapter, not an AI write path: normal ship scripts never activate it.
-- The four parameter checks bind the projection to one accepted, reviewed
-- candidate and keep it disposable and rollback-safe.

local projection = {
    candidateId = "pulse",
    weaponType = "cm2.ai.weapon:pulse",
    candidateHash = "b7080a17d0199833e0140cfbb1c20d648e1f3d2d51894f25ea3b403f80efb92b",
    finalBuildHash = "e20eeef9197937db461605c41ee9cff284474f86a15ee42614518efdbba728cf",
    promptHash = "dcbe5b3bacd206004cc67822c5c94d206bb66805463f3617a682682b5fee9362",
    modelVersion = "fixture-intent-parser/1.0.0",
    toolVersion = "cm2.ai-weapon-assistant/1.0.0",
    parserVersion = "cm2.weapon-intent/1.0.0",
    validatorVersion = "cm2.schema-validator/1.0.0",
    humanApprovalToken = "step-10.2-pulse-runtime-v1",
    disposableScope = "disposable-test-scenario",
    behavior = "ray",
    fireRateHz = 4.0,
    damage = 18.0,
    speedMps = 600.0,
    effectType = "beam",
    effectPriority = 55,
    assetLocalId = "pulse",
    slotType = "M",
    effectProfile = "gammaBeam",
    muzzleProfile = "gammaMedium",
    impactProfile = "gammaMedium",
    soundProfile = "mediumGammaLaser",
    mountProfile = "mLaser",
    maxRange = 1800.0,
    powerUse = 360.0,
}

local function _param(name)
    if GetStringParam == nil then return "" end
    return tostring(GetStringParam(name, "") or "")
end

local active = _param("cm2_ai_candidate") == projection.candidateId
    and _param("cm2_ai_candidate_hash") == projection.candidateHash
    and _param("cm2_ai_final_build_hash") == projection.finalBuildHash
    and _param("cm2_ai_human_approval") == projection.humanApprovalToken
    and _param("cm2_ai_projection_scope") == projection.disposableScope

local function _defineProjection()
    if weaponData[projection.weaponType] ~= nil then return true end
    weaponDefineRay({
        weaponType = projection.weaponType,
        displayName = "AI Pulse Candidate (Disposable)",
        englishName = "AI Pulse Candidate (Disposable)",
        slotTypes = { projection.slotType },
        behaviorType = "raycast",
        fxProfile = projection.effectProfile,
        muzzleFxProfile = projection.muzzleProfile,
        impactFxProfile = projection.impactProfile,
        soundProfileId = projection.soundProfile,
        damageMin = projection.damage,
        damageMax = projection.damage,
        powerUse = projection.powerUse,
        cooldown = 1.0 / projection.fireRateHz,
        maxRange = projection.maxRange,
        shieldFix = 1.0,
        armorFix = 1.0,
        bodyFix = 1.0,
        targetingMode = "forward",
        closeRangeFocus = true,
        closeRangeFocusRange = 220.0,
        mountProfile = projection.mountProfile,
        salvoProfile = { groupSize = 1, sequence = "sequential", interval = 0.25 },
        -- Keep the candidate's ray deterministic while the visual assertion
        -- uses the real rear-freelook camera to expose the beam in profile.
        aimControlMode = "fixed",
        aimLimitDeg = 70.0,
        aimPitchOffsetDeg = 6.0,
        officialComponentId = "CM2_AI_PULSE_CANDIDATE_V1",
        catalogTier = 0,
        runtimeReady = true,
        aiCandidate = true,
        aiCandidateHash = projection.candidateHash,
        aiFinalBuildHash = projection.finalBuildHash,
        aiProjectionScope = projection.disposableScope,
    })
    if weaponCatalogRegisterRuntimeDefinition ~= nil then
        local registered, registerError = weaponCatalogRegisterRuntimeDefinition(projection.weaponType)
        if not registered then error("AI candidate catalog registration failed: " .. tostring(registerError or "unknown")) end
    end
    return true
end

if active then _defineProjection() end

cm2AiWeaponRuntimeProjection = {
    active = function() return active end,
    activateForScenario = function(scenarioId)
        if tostring(scenarioId or "") ~= "ai_weapon_candidate_preview" then return false end
        if not active then
            active = true
            _defineProjection()
        end
        return active
    end,
    weaponType = function() return projection.weaponType end,
    getReport = function()
        return {
            candidate_id = projection.candidateId,
            weapon_type = projection.weaponType,
            candidate_hash = projection.candidateHash,
            final_build_hash = projection.finalBuildHash,
            prompt_hash = projection.promptHash,
            model_version = projection.modelVersion,
            tool_version = projection.toolVersion,
            parser_version = projection.parserVersion,
            validator_version = projection.validatorVersion,
            human_approval = true,
            automatic_publish = false,
            scope = projection.disposableScope,
            behavior = projection.behavior,
            fire_rate_hz = projection.fireRateHz,
            damage = projection.damage,
            speed_mps = projection.speedMps,
            effect_type = projection.effectType,
            effect_priority = projection.effectPriority,
            slot_type = projection.slotType,
            existing_effect_profile = projection.effectProfile,
            existing_muzzle_profile = projection.muzzleProfile,
            existing_impact_profile = projection.impactProfile,
            existing_sound_profile = projection.soundProfile,
            runtime_catalog_write = active,
            generated_write = false,
            core_write = false,
            lua_write = false,
            network_write = false,
        }
    end,
}
