---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.shipHealthBarConfig = client.shipHealthBarConfig or {
    width = 560,
    height = 20,
    bottomOffset = 90,
    segmentGap = 0,

    smoothDownSpeed = 7.5,
    smoothUpSpeed = 3.0,

    gridStepHP = 1000,

    bgColor = {0.08, 0.08, 0.1, 0.75},
    borderColor = {1.0, 1.0, 1.0, 0.65},
    gridColor = {1.0, 1.0, 1.0, 0.25},

    bodyColor = {0.95, 0.28, 0.24, 0.95},
    armorColor = {0.95, 0.72, 0.22, 0.95},
    shieldColor = {0.22, 0.85, 1.0, 0.95},
}

client.shipHealthBarState = client.shipHealthBarState or {
    active = false,
    shipBody = 0,

    maxBody = 0,
    maxArmor = 0,
    maxShield = 0,

    targetBody = 0,
    targetArmor = 0,
    targetShield = 0,

    displayBody = 0,
    displayArmor = 0,
    displayShield = 0,
}

local function _clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function _smoothToward(curr, target, upSpeed, downSpeed, dt)
    local speed = (target < curr) and downSpeed or upSpeed
    local k = math.min(1.0, speed * (dt or 0))
    return curr + (target - curr) * k
end

local function _resolveControlledShipBody()
    local veh = GetPlayerVehicle()
    if veh == nil or veh == 0 then
        local localPlayerId = GetLocalPlayer()
        if localPlayerId ~= nil and localPlayerId ~= 0 then
            veh = GetPlayerVehicle(localPlayerId)
        end
    end

    if veh == nil or veh == 0 then
        return 0
    end

    local body = GetVehicleBody(veh)
    if body == nil or body == 0 then
        return 0
    end

    local scriptBody = client.shipBody or 0
    if scriptBody == 0 or body ~= scriptBody then
        return 0
    end

    if client.registryShipExists ~= nil and (not client.registryShipExists(body)) then
        return 0
    end

    return body
end

function client.shipHealthBarTick(dt)
    local cfg = client.shipHealthBarConfig
    local state = client.shipHealthBarState

    local body = _resolveControlledShipBody()
    if body == 0 then
        state.active = false
        state.shipBody = 0
        return
    end

    local currShield, currArmor, currBody = client.registryShipGetHP(body)
    local maxShield, maxArmor, maxBody = client.registryShipGetMaxHP(body)
    if currShield == nil or currArmor == nil or currBody == nil or maxShield == nil or maxArmor == nil or maxBody == nil then
        state.active = false
        state.shipBody = 0
        return
    end

    state.active = true

    if maxBody == nil or maxBody <= 0 then
        maxBody = currBody
    end
    if maxBody < 0 then
        maxBody = 0
    end

    if maxArmor == nil or maxArmor <= 0 then
        maxArmor = currArmor
    end
    if maxArmor < 0 then
        maxArmor = 0
    end

    if maxShield == nil or maxShield <= 0 then
        maxShield = currShield
    end
    if maxShield < 0 then
        maxShield = 0
    end

    local bodyHP = _clamp(currBody, 0, maxBody)
    local armorHP = _clamp(currArmor, 0, maxArmor)
    local shieldHP = _clamp(currShield, 0, maxShield)

    if state.shipBody ~= body then
        state.shipBody = body

        state.maxBody = maxBody
        state.maxArmor = maxArmor
        state.maxShield = maxShield

        state.targetBody = bodyHP
        state.targetArmor = armorHP
        state.targetShield = shieldHP

        state.displayBody = bodyHP
        state.displayArmor = armorHP
        state.displayShield = shieldHP
        return
    end

    state.maxBody = maxBody
    state.maxArmor = maxArmor
    state.maxShield = maxShield

    state.targetBody = bodyHP
    state.targetArmor = armorHP
    state.targetShield = shieldHP

    state.displayBody = _smoothToward(state.displayBody, state.targetBody, cfg.smoothUpSpeed, cfg.smoothDownSpeed, dt)
    state.displayArmor = _smoothToward(state.displayArmor, state.targetArmor, cfg.smoothUpSpeed, cfg.smoothDownSpeed, dt)
    state.displayShield = _smoothToward(state.displayShield, state.targetShield, cfg.smoothUpSpeed, cfg.smoothDownSpeed, dt)
end

function client.shipHealthBarDraw()
    local cfg = client.shipHealthBarConfig
    local state = client.shipHealthBarState

    if not state.active then
        return
    end

    local maxBody = state.maxBody or 0
    local maxArmor = state.maxArmor or 0
    local maxShield = state.maxShield or 0
    local maxTotal = maxBody + maxArmor + maxShield
    if maxTotal <= 0 then
        return
    end

    local barW = cfg.width
    local barH = cfg.height

    local x = UiCenter() - barW * 0.5
    local y = UiHeight() - cfg.bottomOffset

    local bodyW = barW * (maxBody / maxTotal)
    local armorW = barW * (maxArmor / maxTotal)
    local shieldW = barW * (maxShield / maxTotal)

    local bodyFillW = (maxBody > 0) and (bodyW * _clamp(state.displayBody / maxBody, 0, 1)) or 0
    local armorFillW = (maxArmor > 0) and (armorW * _clamp(state.displayArmor / maxArmor, 0, 1)) or 0
    local shieldFillW = (maxShield > 0) and (shieldW * _clamp(state.displayShield / maxShield, 0, 1)) or 0

    UiPush()
        UiAlign("left top")

        UiColor(cfg.bgColor[1], cfg.bgColor[2], cfg.bgColor[3], cfg.bgColor[4])
        UiTranslate(x, y)
        UiRect(barW, barH)

        UiTranslate(0, 0)
        UiColor(cfg.bodyColor[1], cfg.bodyColor[2], cfg.bodyColor[3], cfg.bodyColor[4])
        UiRect(bodyFillW, barH)

        UiTranslate(bodyW + cfg.segmentGap, 0)
        UiColor(cfg.armorColor[1], cfg.armorColor[2], cfg.armorColor[3], cfg.armorColor[4])
        UiRect(armorFillW, barH)

        UiTranslate(armorW + cfg.segmentGap, 0)
        UiColor(cfg.shieldColor[1], cfg.shieldColor[2], cfg.shieldColor[3], cfg.shieldColor[4])
        UiRect(shieldFillW, barH)

        UiTranslate(-(bodyW + armorW), 0)
        UiColor(cfg.gridColor[1], cfg.gridColor[2], cfg.gridColor[3], cfg.gridColor[4])
        local step = math.max(1, math.floor(cfg.gridStepHP or 1000))
        local hp = step
        while hp < maxTotal do
            local gx = barW * (hp / maxTotal)
            UiPush()
                UiTranslate(gx, 0)
                UiRect(1, barH)
            UiPop()
            hp = hp + step
        end

        UiColor(cfg.borderColor[1], cfg.borderColor[2], cfg.borderColor[3], cfg.borderColor[4])
        UiPush()
            UiTranslate(bodyW, 0)
            UiRect(2, barH)
        UiPop()
        UiPush()
            UiTranslate(bodyW + armorW, 0)
            UiRect(2, barH)
        UiPop()

        UiRectOutline(barW, barH, 2)
    UiPop()
end
