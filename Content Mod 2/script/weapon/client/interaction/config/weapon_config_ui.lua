---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}
client.weaponConfigUiState = client.weaponConfigUiState or {
    open = false,
    pending = false,
    dirty = false,
    shipType = "",
    configurationId = "",
    loadout = {},
    componentLoadout = {},
    message = "",
    selectedSlot = "",
    selectedDefenseType = "",
    selectedDefenseIndex = 0,
    framePickerOpen = false,
    weaponCategory = "all",
    weaponSearch = "",
    weaponSearchFocused = false,
    weaponScroll = 0,
    componentScroll = 0,
    centerScroll = 0,
    summaryScroll = 0,
    detailsOpen = false,
    language = "en",
    hoveredComponent = nil,
}
client.weaponConfigUiState.language = client.weaponConfigUiState.language or "en"

local _panelWidth = 1280
local _panelHeight = 940
local _leftWidth = 272
local _rightWidth = 286
local _contentGap = 18
-- The footer is anchored to the panel origin, below the content transform.
local _contentTop = 88
local _footerHeight = 92
local _footerY = _panelHeight - _footerHeight - 14
local _mainHeight = _footerY - _contentTop - 14
local _slotOrder = { "T", "X", "L", "L2", "G", "M", "H", "P" }
local _localized

local _slotLabels = {
    T = { zh = "泰坦武器", en = "T-SLOT", color = { 0.95, 0.22, 0.18 } },
    X = { zh = "轴基武器", en = "X-SLOT", color = { 0.62, 0.30, 0.96 } },
    L = { zh = "大型武器", en = "L-SLOT", color = { 0.32, 0.72, 0.92 } },
    L2 = { zh = "大型武器", en = "L2", color = { 0.26, 0.58, 0.82 } },
    G = { zh = "制导武器", en = "G-SLOT", color = { 0.22, 0.45, 1.00 } },
    M = { zh = "中型武器", en = "M-SLOT", color = { 0.96, 0.55, 0.18 } },
    H = { zh = "舰载机", en = "H-SLOT", color = { 0.94, 0.78, 0.18 } },
    P = { zh = "自动防御", en = "P-SLOT AUTO", color = { 0.34, 0.88, 0.62 } },
}

local _frameLabels = {
    battleline_2x2l4m = { zh = "炮击框架", en = "ARTILLERY FRAME" },
    torpedo_2x4g4m = { zh = "雷击框架", en = "TORPEDO FRAME" },
}

local _shipLabels = {
    enigmaticCruiser = { zh = "神秘战列巡洋舰", en = "ENIGMA BATTLECRUISER" },
}

local _componentSlotLabels = {
    largeUtility = { zh = "L 防护槽", en = "LARGE UTILITY", mark = "L" },
    auxiliary = { zh = "A 辅助槽", en = "AUXILIARY", mark = "A" },
    thruster = { zh = "推进器槽", en = "THRUSTER", mark = "T" },
    sensor = { zh = "传感器槽", en = "SENSOR", mark = "S" },
    reactor = { zh = "反应堆槽", en = "REACTOR", mark = "R" },
}

local function _shipDefinition()
    return (shipTypeRegistryData or {})[client.weaponConfigUiState.shipType] or {}
end

local function _groupDisplaySlot(group)
    local entry = group or {}
    local key = shipDefinitionGetGroupLoadoutKey(entry.groupId, entry.slotType)
    if key == "" then key = string.upper(tostring(entry.slotType or "?")) end
    if not key:match("%d+$") then key = key .. "1" end
    return key
end

local function _canonicalLoadout(source)
    local selected = source or {}

    local function pick(groupId, slotType)
        local value = tostring(selected[groupId] or "")
        if value ~= "" then return value end
        return tostring(selected[slotType] or "")
    end

    local largeSecond = pick("lSlot2", "L2")
    if largeSecond == "" then largeSecond = pick("lSlot", "L") end
    return {
        T = pick("tSlot", "T"),
        X = pick("xSlot", "X"),
        L = pick("lSlot", "L"),
        L2 = largeSecond,
        M = pick("mSlot", "M"),
        G = pick("gSlot", "G"),
        H = pick("hSlot", "H"),
        P = pick("pSlot", "P"),
    }
end

local function _componentProfile(configuration)
    local state = client.weaponConfigUiState
    return shipComponentResolveProfile(
        _shipDefinition(),
        state.componentLoadout,
        configuration,
        _canonicalLoadout(state.loadout)
    )
end

local function _uiRegistryKey()
    return client.weaponLocalConfigUiOpenKey()
end

local function _shipLabel()
    local state = client.weaponConfigUiState
    local known = _shipLabels[state.shipType]
    if known ~= nil then return known end
    return {
        zh = tostring(_shipDefinition().displayName or state.shipType),
        en = tostring(_shipDefinition().englishName or state.shipType),
    }
end

local function _frameLabel(configuration)
    local id = tostring((configuration or {}).configurationId or "")
    local known = _frameLabels[id]
    if known ~= nil then return known end
    return {
        zh = tostring((configuration or {}).label or id),
        en = string.upper(id),
    }
end

local function _toggleFramePicker()
    local state = client.weaponConfigUiState
    state.framePickerOpen = not state.framePickerOpen
    if state.framePickerOpen then
        state.selectedSlot = ""
        state.selectedDefenseType = ""
        state.selectedDefenseIndex = 0
    end
end

local function _configurableShipTypes()
    local result = {}
    for shipType, definition in pairs(shipTypeRegistryData or {}) do
        if shipDefinitionIsPlayerConfigurable(definition)
            and #(definition.slotConfigurations or {}) > 0 then
            result[#result + 1] = tostring(shipType)
        end
    end
    table.sort(result)
    return result
end

local function _findConfiguration(configurationId)
    for _, configuration in ipairs(_shipDefinition().slotConfigurations or {}) do
        if tostring(configuration.configurationId or "") ==
            tostring(configurationId or "") then
            return configuration
        end
        for _, alias in ipairs(configuration.legacyConfigurationIds or {}) do
            if tostring(alias or "") == tostring(configurationId or "") then
                return configuration
            end
        end
    end
    return nil
end

local function _copyLoadout(source)
    local result = {}
    for key, value in pairs(source or {}) do
        result[key] = tostring(value or "")
    end
    return result
end

local function _copyComponentLoadout(source)
    local result = {}
    for slotType, slots in pairs(source or {}) do
        result[tostring(slotType or "")] = {}
        for index, componentId in ipairs(slots or {}) do
            result[slotType][index] = tostring(componentId or "")
        end
    end
    return result
end

local function _weaponAllowed(configuration, group, weaponType)
    return shipDefinitionWeaponFitsGroup(
        _shipDefinition(),
        configuration,
        group,
        weaponType
    )
end

local function _clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function _resetBrowserState()
    local state = client.weaponConfigUiState
    state.weaponCategory = "all"
    state.weaponSearch = ""
    state.weaponSearchFocused = false
    state.weaponScroll = 0
    state.componentScroll = 0
end

local function _resetScrollState()
    local state = client.weaponConfigUiState
    state.centerScroll = 0
    state.summaryScroll = 0
    _resetBrowserState()
end

local function _weaponCategory(definition)
    local weapon = definition or {}
    if tostring(weapon.controllerType or "") == "chargedRay" then
        return "charged"
    end
    local behavior = tostring(weapon.behaviorType or "")
    if behavior == "raycast" or behavior == "infernoRaycast" then return "ray" end
    if behavior == "projectile" then return "projectile" end
    if behavior == "guidedProjectile" or behavior == "rocketProjectile" then
        return "missile"
    end
    if behavior == "strikeCraft" then return "craft" end
    return "other"
end

local function _filteredWeaponPool(configuration, group)
    local state = client.weaponConfigUiState
    local category = tostring(state.weaponCategory or "all")
    local search = string.lower(tostring(state.weaponSearch or ""))
    local result = {}
    for _, weaponType in ipairs(weaponCatalogGetSlotPool(group.slotType)) do
        local definition = (weaponData or {})[weaponType] or {}
        local categoryMatches = category == "all"
            or _weaponCategory(definition) == category
        local searchable = string.lower(
            tostring(definition.displayName or "") .. " "
            .. tostring(definition.englishName or "") .. " "
            .. tostring(weaponType)
        )
        if categoryMatches and (search == "" or searchable:find(search, 1, true) ~= nil)
            and _weaponAllowed(configuration, group, weaponType) then
            result[#result + 1] = weaponType
        end
    end
    return result
end

local function _updateScroll(key, viewportHeight, contentHeight)
    local state = client.weaponConfigUiState
    local maximum = math.max(0, contentHeight - viewportHeight)
    local current = _clamp(tonumber(state[key]) or 0, 0, maximum)
    if UiIsMouseInRect(UiWidth(), UiHeight()) then
        current = _clamp(current - InputValue("mousewheel") * 42, 0, maximum)
    end
    state[key] = current
    return current, maximum
end

local function _drawScrollBar(x, y, height, viewportHeight, contentHeight, scroll)
    if contentHeight <= viewportHeight then return end
    local trackWidth = 4
    local thumbHeight = math.max(26, height * viewportHeight / contentHeight)
    local maximum = math.max(1, contentHeight - viewportHeight)
    local thumbY = y + (height - thumbHeight) * scroll / maximum
    UiColor(0.05, 0.22, 0.20, 0.9)
    UiRect(trackWidth, height)
    UiTranslate(0, thumbY - y)
    UiColor(0.24, 0.72, 0.62, 0.95)
    UiRect(trackWidth, thumbHeight)
end

local function _ensureDraft()
    local state = client.weaponConfigUiState
    local configuration = _findConfiguration(state.configurationId)
    if configuration == nil then
        state.configurationId =
            tostring(_shipDefinition().defaultSlotConfigurationId or "")
        configuration = _findConfiguration(state.configurationId)
    end
    if configuration == nil then return nil end

    local defaults = configuration.defaultLoadout or {}
    for _, group in ipairs(configuration.slotGroups or {}) do
        local slotType = tostring(group.slotType or "")
        local key = tostring(group.groupId or slotType)
        local loadoutKey = shipDefinitionGetGroupLoadoutKey(key, slotType)
        local current = state.loadout[key]
        if current == nil or current == "" then
            current = state.loadout[loadoutKey]
        end
        if current == nil or current == "" then current = state.loadout[slotType] end
        if not _weaponAllowed(configuration, group, current) then
            current = defaults[key] or defaults[loadoutKey]
                or defaults[slotType] or ""
        end
        state.loadout[key] = tostring(current or "")
    end
    local componentDefaults = configuration.defaultComponentLoadout or {}
    state.componentLoadout = state.componentLoadout or {}
    for _, group in ipairs(shipComponentSlotGroups(configuration)) do
        local slotType = group.slotType
        state.componentLoadout[slotType] = state.componentLoadout[slotType] or {}
        for index = 1, group.count do
            local componentId =
                tostring(state.componentLoadout[slotType][index] or "")
            if not shipComponentAllowed(_shipDefinition(), slotType, componentId) then
                componentId =
                    tostring((componentDefaults[slotType] or {})[index] or "")
            end
            state.componentLoadout[slotType][index] = componentId
        end
    end
    return configuration
end

local function _activeGroups(configuration)
    local result = {}
    for _, group in ipairs((configuration or {}).slotGroups or {}) do
        result[#result + 1] = group
    end
    return result
end

local function _selectNextShipType()
    local state = client.weaponConfigUiState
    local available = _configurableShipTypes()
    if #available <= 1 then return end
    local index = 1
    for i = 1, #available do
        if available[i] == state.shipType then index = i break end
    end
    state.shipType = available[(index % #available) + 1]
    local template = client.weaponConfiguratorRequestTemplate(state.shipType)
    state.configurationId = tostring(template.configurationId or "")
    state.loadout = _copyLoadout(template.loadout)
    state.componentLoadout = _copyComponentLoadout(template.componentLoadout)
    state.selectedSlot = ""
    state.selectedDefenseType = ""
    state.selectedDefenseIndex = 0
    state.framePickerOpen = false
    _resetScrollState()
    state.dirty = false
    state.message = _localized("已载入本地设计", "LOCAL DESIGN LOADED")
    _ensureDraft()
end

local function _open()
    local state = client.weaponConfigUiState
    local available = _configurableShipTypes()
    -- The configuration UI also runs from the map-level content host, where
    -- ship runtime context is intentionally unavailable.
    local currentType = ""
    if client.shipContextGetType ~= nil then
        currentType = tostring(client.shipContextGetType() or "")
    end
    local currentDefinition = (shipTypeRegistryData or {})[currentType] or {}
    if shipDefinitionIsPlayerConfigurable(currentDefinition)
        and #(currentDefinition.slotConfigurations or {}) > 0 then
        state.shipType = currentType
    elseif #available > 0 and _shipDefinition().shipType == nil then
        state.shipType = (shipTypeRegistryData or {}).titan ~= nil and "titan" or available[1]
    end
    local template = client.weaponConfiguratorRequestTemplate(state.shipType)
    state.configurationId = tostring(template.configurationId or "")
    state.loadout = _copyLoadout(template.loadout)
    state.componentLoadout = _copyComponentLoadout(template.componentLoadout)
    state.pending = false
    state.dirty = false
    state.selectedSlot = ""
    state.selectedDefenseType = ""
    state.selectedDefenseIndex = 0
    state.framePickerOpen = false
    _resetScrollState()
    state.message = _localized("已载入本地设计", "LOCAL DESIGN LOADED")
    state.open = true
    SetBool(_uiRegistryKey(), true)
    _ensureDraft()
end

local function _close()
    local state = client.weaponConfigUiState
    state.open = false
    state.pending = false
    state.selectedSlot = ""
    state.selectedDefenseType = ""
    state.selectedDefenseIndex = 0
    state.framePickerOpen = false
    state.weaponSearchFocused = false
    SetBool(_uiRegistryKey(), false)
end

function client.weaponConfigUiSetOpen(open)
    if open then _open() else _close() end
end

function client.weaponConfigPanelIsOpen()
    return client.weaponConfigUiState.open and true or false
end

function client.weaponConfiguratorRequestTemplate(shipType)
    return client.weaponLocalConfigRead(tostring(shipType or ""))
end

function client.weaponConfiguratorSaveTemplate(
    shipType,
    configurationId,
    loadout,
    componentLoadout
)
    local definition = (shipTypeRegistryData or {})[tostring(shipType or "")] or {}
    local configuration = shipComponentFindConfiguration(definition, configurationId)
    local canonicalLoadout = _canonicalLoadout(loadout)
    local profile = shipComponentResolveProfile(
        definition,
        componentLoadout,
        configuration,
        canonicalLoadout
    )
    if not ((profile.energy or {}).valid) then
        local state = client.weaponConfigUiState
        state.pending = false
        state.message = _localized("能源必须为正", "POSITIVE POWER BALANCE REQUIRED")
        return false
    end
    local saved, saveError = client.weaponLocalConfigWrite(
        tostring(shipType or ""),
        tostring(configurationId or ""),
        canonicalLoadout,
        componentLoadout
    )
    local state = client.weaponConfigUiState
    if not saved then
        state.pending = false
        state.message = _localized(
            "璁捐鏍￠獙澶辫触",
            "DESIGN VALIDATION FAILED"
        )
        return false, saveError
    end
    state.pending = false
    state.message = _localized("设计已保存，仅影响下一艘生成的飞船", "SAVED FOR NEXT SPAWN")
    state.dirty = false
    return true
end

function client.weaponConfigUiTick(dt)
    local _ = dt
    local state = client.weaponConfigUiState
    if state.weaponSearchFocused then
        local key = string.lower(tostring(InputLastPressedKey() or ""))
        if key == "backspace" then
            state.weaponSearch = state.weaponSearch:sub(1, -2)
            state.weaponScroll = 0
        elseif key == "space" then
            state.weaponSearch = state.weaponSearch .. " "
            state.weaponScroll = 0
        elseif key:match("^[a-z0-9]$") then
            state.weaponSearch = state.weaponSearch .. key
            state.weaponScroll = 0
        elseif key == "escape" or key == "esc" then
            state.weaponSearchFocused = false
        end
    end
    if InputPressed("t") and not state.weaponSearchFocused then
        if client.weaponConfigUiState.open then _close() else _open() end
    end
end

local function _text(text, size, r, g, b, a)
    UiFont("regular.ttf", size)
    UiColor(r or 1, g or 1, b or 1, a or 1)
    UiText(tostring(text or ""))
end

_localized = function(zh, en)
    local state = client.weaponConfigUiState
    if state.language == "zh" then return tostring(zh or en or "") end
    return tostring(en or zh or "")
end

local function _displayName(definition, fallback)
    local entry = definition or {}
    return _localized(entry.displayName, entry.englishName or fallback)
end

local function _componentTooltipLines(componentId)
    local component = (shipComponentData or {})[tostring(componentId or "")] or {}
    local lines = { _displayName(component, componentId) }
    local function add(value, zh, en, format, multiplier)
        local numeric = (tonumber(value) or 0.0) * (multiplier or 1.0)
        if numeric ~= 0.0 then
            lines[#lines + 1] = _localized(zh, en) .. string.format(format, numeric)
        end
    end
    add(component.powerUse, "功耗 ", "POWER USE ", "%.0f")
    add(component.powerOutput, "功率输出 ", "POWER OUTPUT ", "%.0f")
    add(component.speedMultiplier, "速度 ", "SPEED ", "%+.0f%%", 100)
    add(component.turnResponseMultiplier, "转向响应 ", "TURN RESPONSE ", "%+.0f%%", 100)
    add(component.turnForceMultiplier, "转向力度 ", "TURN FORCE ", "%+.0f%%", 100)
    add(component.armorAdd, "装甲 ", "ARMOR ", "%+.0f")
    add(component.shieldAdd, "护盾 ", "SHIELD ", "%+.0f")
    add(component.shieldRegenAdd, "护盾回复 ", "SHIELD REGEN ", "%+.2f")
    add(component.armorHardening, "装甲硬化 ", "ARMOR HARDENING ", "%+.0f%%", 100)
    add(component.shieldHardening, "护盾硬化 ", "SHIELD HARDENING ", "%+.0f%%", 100)
    add(component.hullRegenPercent, "船体修复 ", "HULL REPAIR ", "%+.2f%%", 100)
    add(component.armorRegenPercent, "装甲修复 ", "ARMOR REPAIR ", "%+.2f%%", 100)
    add(component.reactorOutputMultiplier, "反应堆输出 ", "REACTOR OUTPUT ", "%+.0f%%", 100)
    add(component.sensorRange, "探测范围 ", "SENSOR RANGE ", "%.0f")
    add(component.sensorInterval, "扫描间隔 ", "SCAN INTERVAL ", "%.2fs")
    add(component.trackingAdd, "追踪 ", "TRACKING ", "%+.0f")
    add(component.cloakStrength, "隐形强度 ", "CLOAK STRENGTH ", "%.0f")
    add(component.cloakedShieldReduction, "隐形护盾削弱 ", "CLOAK SHIELD REDUCTION ", "%+.0f%%", 100)
    return lines
end

local function _drawComponentTooltip(componentId)
    if tostring(componentId or "") == "" then return end
    local lines = _componentTooltipLines(componentId)
    local width = 250
    local height = 18 + #lines * 18
    local mouseX, mouseY = UiGetMousePos()
    local x = _clamp(mouseX + 18, 8, _panelWidth - width - 8)
    local y = _clamp(mouseY + 18, 8, _panelHeight - height - 8)
    UiPush()
        UiTranslate(x, y)
        UiColor(0.004, 0.020, 0.024, 0.98)
        UiRect(width, height)
        UiColor(0.20, 0.72, 0.62, 0.95)
        UiRectOutline(width, height, 1)
        UiTranslate(10, 9)
        for index, line in ipairs(lines) do
            _text(line, index == 1 and 13 or 10, index == 1 and 0.94 or 0.70, index == 1 and 0.98 or 0.84, index == 1 and 0.94 or 0.80, 1)
            UiTranslate(0, 18)
        end
    UiPop()
end

local function _bilingual(zh, en, zhSize, enSize, color, alpha)
    local c = color or { 0.86, 0.94, 0.96 }
    local size = client.weaponConfigUiState.language == "zh"
        and (zhSize or 20) or (enSize or zhSize or 20)
    _text(_localized(zh, en), size, c[1], c[2], c[3], alpha or 1)
end

local function _panel(x, y, width, height, strong)
    UiPush()
        UiTranslate(x, y)
        UiColor(0.010, strong and 0.050 or 0.035, strong and 0.058 or 0.045, 0.98)
        UiRect(width, height)
        UiColor(0.10, strong and 0.52 or 0.34, strong and 0.46 or 0.38, 0.92)
        UiRectOutline(width, height, strong and 2 or 1)
    UiPop()
end

local function _button(x, y, width, height, label, primary, enabled)
    UiPush()
        UiAlign("left top")
        UiTranslate(x, y)
        local hover = enabled and UiIsMouseInRect(width, height)
        if primary then
            UiColor(0.06, hover and 0.48 or 0.34, hover and 0.42 or 0.30, enabled and 1 or 0.40)
        else
            UiColor(0.03, hover and 0.18 or 0.09, hover and 0.20 or 0.12, enabled and 0.98 or 0.40)
        end
        UiRect(width, height)
        UiColor(primary and 0.30 or 0.12, primary and 0.84 or 0.48, primary and 0.72 or 0.48, 1)
        UiRectOutline(width, height, primary and 2 or 1)
        local clicked = enabled and hover and InputPressed("lmb")
        UiAlign("center middle")
        UiTranslate(width * 0.5, height * 0.5)
        _text(label, 16, 0.90, 0.98, 0.96, enabled and 1 or 0.45)
    UiPop()
    return clicked
end

local function _drawHeader()
    UiColor(0.014, 0.070, 0.068, 1)
    UiRect(_panelWidth, 72)
    UiColor(0.12, 0.62, 0.52, 1)
    UiRect(_panelWidth, 3)
    UiPush()
        UiTranslate(24, 16)
        _bilingual("舰船设计器", "SHIP DESIGNER", 24, 11)
    UiPop()

    local ship = _shipLabel()
    UiPush()
        UiTranslate(_panelWidth - 330, 17)
        UiAlign("right top")
        _text(_localized(ship.zh, ship.en), 19, 0.90, 0.77, 0.34, 1)
    UiPop()
    local state = client.weaponConfigUiState
    if _button(_panelWidth - 104, 14, 38, 38,
        state.language == "en" and "中" or "EN", false, true) then
        state.language = state.language == "en" and "zh" or "en"
        state.message = state.dirty
            and _localized("未保存的设计", "UNSAVED DESIGN")
            or _localized("已载入本地设计", "LOCAL DESIGN LOADED")
    end
    if _button(_panelWidth - 54, 14, 38, 38, "X", false, true) then
        _close()
    end
end

local function _drawShipSidebar(configuration)
    local state = client.weaponConfigUiState
    _panel(0, 0, _leftWidth, _mainHeight, false)
    UiPush()
        UiTranslate(18, 18)
        _bilingual("舰船类型", "SHIP CLASS", 19, 10)
    UiPop()

    local ship = _shipLabel()
    UiPush()
        UiTranslate(16, 72)
        UiColor(0.025, 0.090, 0.085, 1)
        UiRect(_leftWidth - 32, 92)
        UiColor(0.18, 0.56, 0.48, 1)
        UiRectOutline(_leftWidth - 32, 92, 1)
        UiTranslate(14, 18)
        _bilingual(ship.zh, ship.en, 18, 10, { 0.86, 0.93, 0.88 })
    UiPop()

    local available = _configurableShipTypes()
    if #available > 1 and
        _button(16, 176, _leftWidth - 32, 38, _localized("切换舰船", "NEXT SHIP"), false, true) then
        _selectNextShipType()
    end

    UiPush()
        UiTranslate(18, 258)
        _bilingual("部署状态", "DEPLOYMENT", 18, 9)
        UiTranslate(0, 54)
        _text(_localized("配置应用于下一艘飞船", "APPLIES TO NEXT SPAWN"), 14, 0.70, 0.82, 0.78, 1)
    UiPop()

    if state.dirty then
        UiPush()
            UiTranslate(18, 552)
            _text(_localized("● 未保存", "● UNSAVED"), 12, 0.95, 0.64, 0.24, 1)
        UiPop()
    end
end

local function _drawWeaponOption(x, y, width, height, slotType, loadoutKey, weaponType)
    local state = client.weaponConfigUiState
    local definition = (weaponData or {})[weaponType] or {}
    local selected = tostring(state.loadout[loadoutKey] or "") == tostring(weaponType)
    local slot = _slotLabels[slotType] or _slotLabels.M
    UiPush()
        UiTranslate(x, y)
        local hover = UiIsMouseInRect(width, height)
        UiColor(
            selected and 0.045 or 0.018,
            selected and 0.150 or (hover and 0.090 or 0.052),
            selected and 0.145 or (hover and 0.092 or 0.060),
            1
        )
        UiRect(width, height)
        UiColor(slot.color[1], slot.color[2], slot.color[3], selected and 1 or 0.55)
        UiRect(selected and 4 or 2, height)
        UiRectOutline(width, height, selected and 2 or 1)

        UiTranslate(8, 8)
        UiColor(0.008, 0.018, 0.024, 1)
        UiRect(42, 42)
        local icon = tostring(definition.iconPath or "")
        if icon ~= "" then
            UiColor(1, 1, 1, 1)
            UiImageBox(icon, 42, 42, 0, 0)
        end
        UiTranslate(52, 1)
        _text(_displayName(definition, weaponType), 14, 0.88, 0.95, 0.92, 1)
        UiTranslate(width - 74, -16)
        _text(selected and _localized("已装备", "EQUIPPED") or "", 9, 0.40, 0.86, 0.72, 1)
        local clicked = hover and InputPressed("lmb")
    UiPop()
    return clicked
end

local _weaponCategoryLabels = {
    { id = "all", zh = "全部", en = "ALL" },
    { id = "ray", zh = "射线", en = "RAY" },
    { id = "charged", zh = "蓄力射线", en = "CHARGED" },
    { id = "projectile", zh = "弹道", en = "BALLISTIC" },
    { id = "missile", zh = "导弹", en = "MISSILE" },
    { id = "craft", zh = "舰载机", en = "CRAFT" },
}

local function _drawSearchBox(x, y, width)
    local state = client.weaponConfigUiState
    UiPush()
        UiTranslate(x, y)
        local hover = UiIsMouseInRect(width, 30)
        UiColor(0.018, state.weaponSearchFocused and 0.115 or 0.070,
            state.weaponSearchFocused and 0.105 or 0.072, 1)
        UiRect(width, 30)
        UiColor(0.20, state.weaponSearchFocused and 0.76 or 0.42,
            state.weaponSearchFocused and 0.66 or 0.46, 1)
        UiRectOutline(width, 30, state.weaponSearchFocused and 2 or 1)
        local value = tostring(state.weaponSearch or "")
        if value ~= "" and _button(width - 28, 3, 24, 24, "X", false, true) then
            state.weaponSearch = ""
            state.weaponScroll = 0
            value = ""
        end
        UiTranslate(10, 8)
        _text(value == "" and _localized("搜索英文名或 ID", "SEARCH ENGLISH NAME OR ID") or value, 11,
            value == "" and 0.44 or 0.86, value == "" and 0.62 or 0.93,
            value == "" and 0.58 or 0.88, 1)
        if hover and InputPressed("lmb") then state.weaponSearchFocused = true end
    UiPop()
end

local function _drawWeaponCategoryChips(x, y, width, configuration, group)
    local state = client.weaponConfigUiState
    local counts = {}
    for _, weaponType in ipairs(weaponCatalogGetSlotPool(group.slotType)) do
        local definition = (weaponData or {})[weaponType] or {}
        if _weaponAllowed(configuration, group, weaponType) then
            local category = _weaponCategory(definition)
            counts.all = (counts.all or 0) + 1
            counts[category] = (counts[category] or 0) + 1
        end
    end
    local chipGap = 5
    local chipWidth = math.floor((width - chipGap * 2) / 3)
    for index, category in ipairs(_weaponCategoryLabels) do
        local row = math.floor((index - 1) / 3)
        local column = (index - 1) % 3
        local count = counts[category.id] or 0
        local enabled = count > 0
        local selected = state.weaponCategory == category.id
        if _button(
            x + column * (chipWidth + chipGap),
            y + row * 30,
            chipWidth,
            26,
            _localized(category.zh, category.en) .. " " .. tostring(count),
            selected,
            enabled
        ) then
            state.weaponCategory = category.id
            state.weaponScroll = 0
        end
    end
end

local function _drawWeaponSidebar(groupId)
    local state = client.weaponConfigUiState
    local configuration = _findConfiguration(state.configurationId) or {}
    local group = nil
    for _, candidate in ipairs(configuration.slotGroups or {}) do
        if tostring(candidate.groupId or "") == tostring(groupId or "") then
            group = candidate
            break
        end
    end
    group = group or { groupId = groupId, slotType = groupId }
    local slotType = tostring(group.slotType or "")
    local loadoutKey = tostring(group.groupId or slotType)
    local displaySlot = _groupDisplaySlot(group)
    local slot = _slotLabels[displaySlot] or _slotLabels[slotType] or _slotLabels.M
    _panel(0, 0, _leftWidth, _mainHeight, true)
    UiPush()
        UiTranslate(18, 17)
        _bilingual("选择 " .. displaySlot .. " 武器", "SELECT " .. displaySlot,
            18, 9, slot.color)
    UiPop()
    if _button(16, 68, _leftWidth - 32, 34, _localized("← 返回", "← BACK"), false, true) then
        state.selectedSlot = ""
        return
    end

    _drawSearchBox(16, 112, _leftWidth - 32)
    _drawWeaponCategoryChips(16, 150, _leftWidth - 32, configuration, group)
    local pool = _filteredWeaponPool(configuration, group)
    local listY = 218
    local listHeight = _mainHeight - listY - 12
    local contentHeight = #pool * 58
    UiPush()
        UiTranslate(12, listY)
        UiWindow(_leftWidth - 30, listHeight, true)
        local scroll = _updateScroll("weaponScroll", listHeight, contentHeight)
        UiTranslate(0, -scroll)
        local y = 0
        for _, weaponType in ipairs(pool) do
            if _drawWeaponOption(0, y, _leftWidth - 36, 54, slotType, loadoutKey, tostring(weaponType)) then
                state.loadout[loadoutKey] = tostring(weaponType)
                state.message = _localized("未保存的设计", "UNSAVED DESIGN")
                state.dirty = true
            end
            y = y + 58
        end
    UiPop()
    UiPush()
        UiTranslate(_leftWidth - 14, listY)
        _drawScrollBar(0, 0, listHeight, listHeight, contentHeight, state.weaponScroll)
    UiPop()
    UiPush()
        UiTranslate(18, listY - 17)
        _text(_localized("结果 ", "RESULTS ") .. tostring(#pool), 9, 0.44, 0.68, 0.62, 1)
    UiPop()
end

local function _drawDefenseOption(x, y, width, height, slotType, componentId)
    local state = client.weaponConfigUiState
    local definition = shipComponentData[tostring(componentId or "")] or {}
    local selected = tostring(
        ((state.componentLoadout[slotType] or {})[state.selectedDefenseIndex]) or ""
    ) == tostring(componentId or "")
    UiPush()
        UiTranslate(x, y)
        local hover = UiIsMouseInRect(width, height)
        UiColor(0.018, hover and 0.090 or 0.052, hover and 0.092 or 0.060, 1)
        UiRect(width, height)
        UiColor(0.25, 0.76, 0.66, selected and 1 or 0.55)
        UiRectOutline(width, height, selected and 2 or 1)
        UiTranslate(9, 9)
        UiColor(0.006, 0.016, 0.022, 1)
        UiRect(48, 48)
        local icon = tostring(definition.iconPath or "")
        if icon ~= "" then
            UiColor(1, 1, 1, 1)
            UiImageBox(icon, 48, 48, 0, 0)
        end
        UiTranslate(60, 2)
        _text(_displayName(definition, _localized("空槽", "EMPTY")), 14, 0.88, 0.95, 0.92, 1)
        if hover and tostring(componentId or "") ~= "" then
            state.hoveredComponent = tostring(componentId)
        end
        local clicked = hover and InputPressed("lmb")
    UiPop()
    return clicked
end

local function _drawDefenseSidebar(slotType)
    local state = client.weaponConfigUiState
    local label = _componentSlotLabels[slotType]
        or { zh = slotType, en = string.upper(slotType), mark = "?" }
    _panel(0, 0, _leftWidth, _mainHeight, true)
    UiPush()
        UiTranslate(18, 17)
        _bilingual("选择" .. label.zh, "SELECT " .. label.en, 18, 9)
    UiPop()
    if _button(16, 68, _leftWidth - 32, 34, _localized("← 返回", "← BACK"), false, true) then
        state.selectedDefenseType = ""
        state.selectedDefenseIndex = 0
        return
    end
    local pool = shipComponentGetSlotPool(slotType)
    local options = {}
    local optional = slotType == "largeUtility" or slotType == "auxiliary"
    if optional then
        options[#options + 1] = ""
    end
    for _, componentId in ipairs(pool) do
        options[#options + 1] = componentId
    end
    local listY = 112
    local listHeight = _mainHeight - listY - 12
    local contentHeight = #options * 62
    UiPush()
        UiTranslate(12, listY)
        UiWindow(_leftWidth - 30, listHeight, true)
        local scroll = _updateScroll("componentScroll", listHeight, contentHeight)
        UiTranslate(0, -scroll)
        local y = 0
        for _, componentId in ipairs(options) do
            if _drawDefenseOption(0, y, _leftWidth - 36, 58, slotType, componentId) then
                state.componentLoadout[slotType][state.selectedDefenseIndex] =
                    tostring(componentId)
                state.message = _localized("未保存的设计", "UNSAVED DESIGN")
                state.dirty = true
            end
            y = y + 62
        end
    UiPop()
    UiPush()
        UiTranslate(_leftWidth - 14, listY)
        _drawScrollBar(0, 0, listHeight, listHeight, contentHeight, state.componentScroll)
    UiPop()
end

local function _drawDefenseSlot(x, y, size, slotType, index)
    local state = client.weaponConfigUiState
    local componentId =
        tostring(((state.componentLoadout[slotType] or {})[index]) or "")
    local component = shipComponentData[componentId] or {}
    local selected = state.selectedDefenseType == slotType
        and state.selectedDefenseIndex == index
    UiPush()
        UiTranslate(x, y)
        local hover = UiIsMouseInRect(size, size)
        UiColor(0.012, hover and 0.10 or 0.045, hover and 0.10 or 0.052, 1)
        UiRect(size, size)
        local core = slotType == "thruster"
            or slotType == "sensor" or slotType == "reactor"
        UiColor(
            core and 0.76 or (slotType == "auxiliary" and 0.24 or 0.20),
            core and 0.60 or (slotType == "auxiliary" and 0.76 or 0.62),
            core and 0.22 or (slotType == "auxiliary" and 0.58 or 0.82),
            1
        )
        UiRectOutline(size, size, selected and 3 or 1)
        local icon = tostring(component.iconPath or "")
        if icon ~= "" then
            UiColor(1, 1, 1, 1)
            UiImageBox(icon, size, size, 0, 0)
        end
        UiTranslate(4, 3)
        local label = _componentSlotLabels[slotType] or { mark = "?" }
        _text(label.mark, 12, 0.9, 0.9, 0.65, 1)
        if hover and componentId ~= "" then
            state.hoveredComponent = componentId
        end
        local clicked = hover and InputPressed("lmb")
    UiPop()
    return clicked
end

local function _drawGroupCard(x, y, width, height, group)
    local state = client.weaponConfigUiState
    local slotType = tostring(group.slotType or "")
    local loadoutKey = tostring(group.groupId or slotType)
    local displaySlot = _groupDisplaySlot(group)
    local slot = _slotLabels[displaySlot] or _slotLabels[slotType] or _slotLabels.M
    local weaponType = tostring(state.loadout[loadoutKey] or "")
    local weapon = (weaponData or {})[weaponType] or {}
    local selected = state.selectedSlot == loadoutKey

    UiPush()
        UiTranslate(x, y)
        local hover = UiIsMouseInRect(width, height)
        UiColor(
            selected and 0.040 or 0.014,
            selected and 0.120 or (hover and 0.085 or 0.045),
            selected and 0.125 or (hover and 0.090 or 0.058),
            1
        )
        UiRect(width, height)
        UiColor(slot.color[1], slot.color[2], slot.color[3], selected and 1 or 0.72)
        UiRectOutline(width, height, selected and 3 or 2)
        UiRect(width, 5)

        UiTranslate(12, 10)
        UiColor(slot.color[1], slot.color[2], slot.color[3], 1)
        UiRect(42, 24)
        UiAlign("center middle")
        UiTranslate(21, 12)
        _text(displaySlot, 15, 0.03, 0.04, 0.05, 1)
        UiAlign("left top")
        UiTranslate(32, -6)
        _text("×" .. tostring(group.count or 0), 15, 0.88, 0.94, 0.92, 1)

        UiTranslate(-44, 30)
        local icon = tostring(weapon.iconPath or "")
        UiColor(0.006, 0.016, 0.022, 1)
        UiRect(46, 46)
        if icon ~= "" then
            UiColor(1, 1, 1, 1)
            UiImageBox(icon, 46, 46, 0, 0)
        end
        UiTranslate(56, 0)
        _text(_displayName(weapon, weaponType), 13, 0.90, 0.95, 0.92, 1)
        local clicked = hover and InputPressed("lmb")
    UiPop()
    return clicked
end

local function _drawCenter(configuration, x, width)
    local state = client.weaponConfigUiState
    _panel(x, 0, width, _mainHeight, false)
    local frame = _frameLabel(configuration)
    if _button(
        x + (width - 320) * 0.5,
        18,
        320,
        56,
        _localized(frame.zh, frame.en) .. "  ▼",
        false,
        true
    ) then
        _toggleFramePicker()
    end

    local groups = _activeGroups(configuration)
    local componentSlotCounts = {}
    for _, group in ipairs(shipComponentSlotGroups(configuration)) do
        componentSlotCounts[group.slotType] = group.count
    end

    local viewportX = x + 16
    local viewportY = 88
    local viewportWidth = width - 32
    local viewportHeight = _mainHeight - viewportY - 12
    local cardGap = 10
    local cardWidth = (viewportWidth - cardGap - 10) * 0.5
    local cardHeight = 96
    local weaponRows = math.max(1, math.ceil(#groups / 2))
    local coreTypes = { "thruster", "sensor", "reactor" }
    local coreCount = 0
    for _, slotType in ipairs(coreTypes) do
        if math.floor(tonumber(componentSlotCounts[slotType]) or 0) > 0 then
            coreCount = coreCount + 1
        end
    end
    local coreY = 42 + weaponRows * (cardHeight + 10) + 14
    local defenseY = coreY + (coreCount > 0 and 82 or 0)
    local slotSize = 48
    local gap = 6
    local slotsPerRow = math.max(1, math.floor(viewportWidth / (slotSize + gap)))
    local auxiliaryCount = math.floor(tonumber(componentSlotCounts.auxiliary) or 0)
    local largeCount = math.floor(tonumber(componentSlotCounts.largeUtility) or 0)
    local auxiliaryRows = math.ceil(auxiliaryCount / slotsPerRow)
    local largeRows = math.ceil(largeCount / slotsPerRow)
    local largeY = defenseY + 38 + auxiliaryRows * (slotSize + gap) + 16
    local detailsY = largeY + largeRows * (slotSize + gap) + 16
    local detailsHeight = state.detailsOpen and 170 or 34
    local contentHeight = detailsY + detailsHeight + 12

    UiPush()
        UiTranslate(viewportX, viewportY)
        UiWindow(viewportWidth, viewportHeight, true)
        state.centerScroll = _updateScroll("centerScroll", viewportHeight, contentHeight)
        UiTranslate(0, -state.centerScroll)
        _bilingual("武器组", "WEAPON GROUPS", 18, 9)
        UiTranslate(0, 42)
        for index, group in ipairs(groups) do
            local column = (index - 1) % 2
            local row = math.floor((index - 1) / 2)
            if _drawGroupCard(
                column * (cardWidth + cardGap),
                row * (cardHeight + 10),
                cardWidth,
                cardHeight,
                group
            ) then
                state.selectedSlot = tostring(group.groupId or group.slotType or "")
                state.selectedDefenseType = ""
                state.selectedDefenseIndex = 0
                _resetBrowserState()
            end
        end

        if coreCount > 0 then
            UiPush()
                UiTranslate(0, coreY)
                _bilingual("核心组件", "CORE COMPONENTS", 16, 8)
            UiPop()
            local coreIndex = 0
            for _, slotType in ipairs(coreTypes) do
                if math.floor(tonumber(componentSlotCounts[slotType]) or 0) > 0 then
                    if _drawDefenseSlot(coreIndex * 58, coreY + 28, 48, slotType, 1) then
                        state.selectedSlot = ""
                        state.selectedDefenseType = slotType
                        state.selectedDefenseIndex = 1
                        _resetBrowserState()
                    end
                    coreIndex = coreIndex + 1
                end
            end
        end

        UiPush()
            UiTranslate(0, defenseY)
            _bilingual("防护与辅助组件", "DEFENSE & AUXILIARY", 16, 8)
        UiPop()
        for index = 1, auxiliaryCount do
            local row = math.floor((index - 1) / slotsPerRow)
            local column = (index - 1) % slotsPerRow
            if _drawDefenseSlot(column * (slotSize + gap), defenseY + 38 + row * (slotSize + gap), slotSize, "auxiliary", index) then
                state.selectedSlot = ""
                state.selectedDefenseType = "auxiliary"
                state.selectedDefenseIndex = index
                _resetBrowserState()
            end
        end
        for index = 1, largeCount do
            local row = math.floor((index - 1) / slotsPerRow)
            local column = (index - 1) % slotsPerRow
            if _drawDefenseSlot(column * (slotSize + gap), largeY + row * (slotSize + gap), slotSize, "largeUtility", index) then
                state.selectedSlot = ""
                state.selectedDefenseType = "largeUtility"
                state.selectedDefenseIndex = index
                _resetBrowserState()
            end
        end

        if _button(0, detailsY, viewportWidth - 8, 30, state.detailsOpen and "舰体数据  ▲" or "舰体数据  ▼", false, false) then
            state.detailsOpen = not state.detailsOpen
        end
        if state.detailsOpen then
            local profile = _componentProfile(configuration)
            local protection = profile.protection or {}
            local mobility = profile.mobility or {}
            local energy = profile.energy or {}
            UiPush()
                UiTranslate(8, detailsY + 42)
                _text(_localized("船体 / 装甲 / 护盾  ", "HULL / ARMOR / SHIELD  ") .. string.format("%.0f / %.0f / %.0f", protection.maxBodyHP or 0, protection.maxArmorHP or 0, protection.maxShieldHP or 0), 11, 0.78, 0.90, 0.84, 1)
                UiTranslate(0, 22)
                _text(_localized("硬化  ", "HARDENING  ") .. string.format(_localized("装甲 %.0f%%  护盾 %.0f%%", "ARMOR %.0f%%  SHIELD %.0f%%"), (protection.armorHardening or 0) * 100, (protection.shieldHardening or 0) * 100), 10, 0.64, 0.80, 0.76, 1)
                UiTranslate(0, 20)
                _text(_localized("机动  ", "MOBILITY  ") .. string.format(_localized("速度 +%.0f%%  转向 +%.0f%%", "SPEED +%.0f%%  TURN +%.0f%%"), (mobility.speedMultiplier or 0) * 100, (mobility.turnResponseMultiplier or 0) * 100), 10, 0.64, 0.80, 0.76, 1)
                UiTranslate(0, 20)
                _text(_localized("能源  ", "POWER  ") .. string.format("%.0f - %.0f = %.0f", energy.output or 0, energy.use or 0, energy.balance or 0), 10, energy.valid and 0.58 or 0.96, energy.valid and 0.76 or 0.30, energy.valid and 0.70 or 0.22, 1)
            UiPop()
        end
    UiPop()

    UiPush()
        UiTranslate(x + width - 10, viewportY)
        _drawScrollBar(0, 0, viewportHeight, viewportHeight, contentHeight, state.centerScroll)
    UiPop()
end

local function _drawSummary(configuration, x)
    local state = client.weaponConfigUiState
    _panel(x, 0, _rightWidth, _mainHeight, false)
    UiPush()
        UiTranslate(x + 18, 18)
        _bilingual("配置摘要", "DESIGN SUMMARY", 20, 10)
    UiPop()

    local groups = _activeGroups(configuration)
    local profile = _componentProfile(configuration)
    local energy = profile.energy or {}
    local viewportX = x + 14
    local viewportY = 62
    local viewportWidth = _rightWidth - 28
    local viewportHeight = _mainHeight - viewportY - 12
    local contentHeight = 64 + #groups * 50 + 72

    UiPush()
        UiTranslate(viewportX, viewportY)
        UiWindow(viewportWidth, viewportHeight, true)
        state.summaryScroll = _updateScroll("summaryScroll", viewportHeight, contentHeight)
        UiTranslate(0, -state.summaryScroll)
        local frame = _frameLabel(configuration)
        _text(_localized(frame.zh, frame.en), 16, 0.90, 0.77, 0.34, 1)
        UiTranslate(0, 28)
        for _, group in ipairs(groups) do
            local slotType = tostring(group.slotType or "")
            local loadoutKey = tostring(group.groupId or slotType)
            local displaySlot = _groupDisplaySlot(group)
            local slot = _slotLabels[displaySlot] or _slotLabels[slotType] or _slotLabels.M
            local weaponType = tostring(state.loadout[loadoutKey] or "")
            local weapon = (weaponData or {})[weaponType] or {}
            UiPush()
                UiColor(0.018, 0.060, 0.062, 1)
                UiRect(viewportWidth - 8, 42)
                UiColor(slot.color[1], slot.color[2], slot.color[3], 0.8)
                UiRect(3, 42)
                UiTranslate(10, 8)
                _text(displaySlot .. "×" .. tostring(group.count or 0) .. " - " .. _displayName(weapon, weaponType), 11, 0.86, 0.94, 0.90, 1)
            UiPop()
            UiTranslate(0, 50)
        end
        UiColor(0.06, 0.25, 0.22, 1)
        UiRect(viewportWidth - 8, 1)
        UiTranslate(0, 14)
        _text(_localized("能源余额  ", "POWER BALANCE  ") .. string.format("%.0f", energy.balance or 0), 12, energy.valid and 0.58 or 0.96, energy.valid and 0.76 or 0.30, energy.valid and 0.70 or 0.22, 1)
        UiTranslate(0, 20)
        _text(energy.valid and _localized("设计有效", "DESIGN VALID") or _localized("能源不足", "INSUFFICIENT POWER"), 10, energy.valid and 0.58 or 0.96, energy.valid and 0.76 or 0.30, energy.valid and 0.70 or 0.22, 1)
    UiPop()

    UiPush()
        UiTranslate(x + _rightWidth - 10, viewportY)
        _drawScrollBar(0, 0, viewportHeight, viewportHeight, contentHeight, state.summaryScroll)
    UiPop()
end

local function _groupSummary(configuration)
    local parts = {}
    for _, group in ipairs(_activeGroups(configuration)) do
        parts[#parts + 1] = tostring(group.slotType or "")
            .. "×" .. tostring(group.count or 0)
    end
    return table.concat(parts, "   ")
end

local function _drawFramePicker()
    local state = client.weaponConfigUiState
    UiPush()
        UiMakeInteractive()
        UiColor(0.001, 0.006, 0.008, 0.82)
        UiRect(_panelWidth, _panelHeight)

        local modalW = 820
        local modalH = 430
        local modalX = (_panelWidth - modalW) * 0.5
        local modalY = (_panelHeight - modalH) * 0.5
        UiTranslate(modalX, modalY)
        UiColor(0.010, 0.035, 0.040, 1)
        UiRect(modalW, modalH)
        UiColor(0.14, 0.58, 0.50, 1)
        UiRectOutline(modalW, modalH, 2)
        UiColor(0.10, 0.48, 0.42, 1)
        UiRect(modalW, 3)

        UiTranslate(24, 18)
        _bilingual("选择区段", "SELECT SECTION", 24, 11)
        if _button(modalW - 86, -4, 38, 38, "X", false, true) then
            state.framePickerOpen = false
        end

        local configurations = _shipDefinition().slotConfigurations or {}
        local cardW = 360
        local cardH = 282
        for index, candidate in ipairs(configurations) do
            local x = (index - 1) * (cardW + 24)
            local selected = state.configurationId ==
                tostring(candidate.configurationId or "")
            UiPush()
                UiTranslate(x, 82)
                local hover = UiIsMouseInRect(cardW, cardH)
                UiColor(
                    selected and 0.035 or 0.014,
                    selected and 0.120 or (hover and 0.085 or 0.048),
                    selected and 0.110 or (hover and 0.080 or 0.052),
                    1
                )
                UiRect(cardW, cardH)
                UiColor(selected and 0.28 or 0.10, selected and 0.82 or 0.44,
                    selected and 0.66 or 0.40, 1)
                UiRectOutline(cardW, cardH, selected and 3 or 1)
                local clicked = hover and InputPressed("lmb")
                local label = _frameLabel(candidate)
                UiTranslate(22, 22)
                _bilingual(label.zh, label.en, 24, 11,
                    selected and { 0.94, 0.80, 0.38 } or { 0.82, 0.91, 0.87 })
                UiTranslate(0, 72)
                _text(_localized("武器槽", "WEAPON SLOTS"), 12, 0.38, 0.62, 0.58, 1)
                UiTranslate(0, 31)
                _text(_groupSummary(candidate), 25, 0.80, 0.92, 0.86, 1)
                UiTranslate(0, 62)
                _text(selected and _localized("当前框架", "CURRENT") or _localized("点击选择", "SELECT"),
                    13, selected and 0.92 or 0.46, selected and 0.76 or 0.70,
                    selected and 0.30 or 0.64, 1)
            UiPop()
            if clicked then
                state.configurationId =
                    tostring(candidate.configurationId or "")
                state.framePickerOpen = false
                state.selectedSlot = ""
                state.selectedDefenseType = ""
                state.selectedDefenseIndex = 0
                state.message = _localized("未保存的设计", "UNSAVED DESIGN")
                state.dirty = true
                _ensureDraft()
                _resetScrollState()
            end
        end
    UiPop()
end

local function _resetDraft()
    local state = client.weaponConfigUiState
    local definition = _shipDefinition()
    state.configurationId = tostring(definition.defaultSlotConfigurationId or "")
    local configuration = _findConfiguration(state.configurationId)
    state.loadout = _copyLoadout((configuration or {}).defaultLoadout)
    state.componentLoadout = _copyComponentLoadout(
        (configuration or {}).defaultComponentLoadout
    )
    state.selectedSlot = ""
    state.selectedDefenseType = ""
    state.selectedDefenseIndex = 0
    state.framePickerOpen = false
    _resetScrollState()
    state.message = _localized("已恢复默认设计", "DEFAULT DESIGN RESTORED")
    state.dirty = true
    _ensureDraft()
end

local function _drawFooter(configuration)
    local state = client.weaponConfigUiState
    local footerWidth = _panelWidth - 28
    local profile = _componentProfile(configuration) or {}
    local energy = profile.energy or {}
    local designValid = energy.valid and true or false
    local balance = tonumber(energy.balance) or 0.0
    local message = tostring(state.message or "")
    if not designValid then
        message = _localized("能源不足", "POSITIVE POWER BALANCE REQUIRED")
    end

    UiPush()
        UiTranslate(14, _footerY)
        UiColor(0.008, 0.050, 0.054, 1.0)
        UiRect(footerWidth, _footerHeight)
        UiColor(0.12, 0.62, 0.52, 0.82)
        UiRect(footerWidth, 2)
        UiPush()
            UiTranslate(16, 12)
            _text(_localized("设计状态", "DESIGN STATUS"), 11, 0.48, 0.78, 0.72, 1)
            UiTranslate(0, 21)
            _text(message, 14, designValid and 0.82 or 1.0,
                designValid and 0.94 or 0.36,
                designValid and 0.88 or 0.24, 1)
            UiTranslate(0, 24)
            _text(string.format("POWER BALANCE %+0.0f", balance), 11,
                designValid and 0.42 or 0.96,
                designValid and 0.84 or 0.32,
                designValid and 0.72 or 0.20, 1)
        UiPop()

        local resetX = footerWidth - 374
        local saveX = resetX + 182
        if _button(resetX, 42, 170, 36,
            _localized("恢复默认", "RESET"), false, not state.pending) then
            _resetDraft()
            configuration = _ensureDraft() or configuration
        end
        if _button(saveX, 42, 170, 36,
            _localized("保存设计", "SAVE"), designValid, not state.pending) then
            client.weaponConfiguratorSaveTemplate(
                state.shipType,
                state.configurationId,
                _copyLoadout(state.loadout),
                _copyComponentLoadout(state.componentLoadout)
            )
        end
    UiPop()
    return configuration
end

function client.weaponConfigUiDraw()
    local state = client.weaponConfigUiState
    if not state.open then return end
    local configuration = _ensureDraft()
    if configuration == nil then return end
    state.hoveredComponent = nil

    UiPush()
        UiMakeInteractive()
        UiBlur(0.65)
        UiColor(0.001, 0.006, 0.008, 0.84)
        UiRect(UiWidth(), UiHeight())

        local scale = math.min(
            (UiWidth() - 24) / _panelWidth,
            (UiHeight() - 24) / _panelHeight,
            1.0
        )
        UiTranslate(
            (UiWidth() - _panelWidth * scale) * 0.5,
            (UiHeight() - _panelHeight * scale) * 0.5
        )
        UiScale(scale)

        UiColor(0.006, 0.020, 0.024, 1)
        UiRect(_panelWidth, _panelHeight)
        UiColor(0.10, 0.48, 0.42, 1)
        UiRectOutline(_panelWidth, _panelHeight, 2)
        _drawHeader()

        UiTranslate(14, _contentTop)
        if state.selectedDefenseType ~= "" then
            _drawDefenseSidebar(state.selectedDefenseType)
        elseif state.selectedSlot ~= "" then
            _drawWeaponSidebar(state.selectedSlot)
        else
            _drawShipSidebar(configuration)
        end

        local centerX = _leftWidth + _contentGap
        local centerWidth = _panelWidth - 28 - _leftWidth - _rightWidth
            - _contentGap * 2
        _drawCenter(configuration, centerX, centerWidth)
        _drawSummary(
            configuration,
            centerX + centerWidth + _contentGap
        )

        UiPush()
            UiTranslate(-14, -_contentTop)
            configuration = _drawFooter(configuration)
        UiPop()

        if not state.framePickerOpen then
            UiPush()
                UiTranslate(-14, -_contentTop)
                _drawComponentTooltip(state.hoveredComponent)
            UiPop()
        end

        if state.framePickerOpen then
            UiPush()
                UiTranslate(-14, -_contentTop)
                _drawFramePicker()
            UiPop()
        end
    UiPop()
end
