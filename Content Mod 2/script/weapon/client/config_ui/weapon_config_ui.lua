---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}
client.weaponConfigUiState = client.weaponConfigUiState or {
    open = false,
    pending = false,
    dirty = false,
    shipType = "enigmaticCruiser",
    configurationId = "",
    loadout = {},
    componentLoadout = {},
    message = "",
    selectedSlot = "",
    selectedDefenseType = "",
    selectedDefenseIndex = 0,
    framePickerOpen = false,
}

local _panelWidth = 1280
local _panelHeight = 940
local _leftWidth = 272
local _rightWidth = 286
local _contentGap = 18
-- The footer is anchored to the panel origin, below the content transform.
local _mainHeight = 770
local _footerY = _panelHeight - 104
local _slotOrder = { "X", "L", "G", "M", "H", "P" }

local _slotLabels = {
    X = { zh = "轴基武器", en = "X-SLOT", color = { 0.62, 0.30, 0.96 } },
    L = { zh = "大型武器", en = "L-SLOT", color = { 0.32, 0.72, 0.92 } },
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

local function _componentProfile(configuration)
    local state = client.weaponConfigUiState
    return shipComponentResolveProfile(
        _shipDefinition(),
        state.componentLoadout,
        configuration,
        state.loadout
    )
end

local function _uiRegistryKey()
    return client.weaponLocalConfigUiOpenKey()
end

local function _shipDefinition()
    return (shipTypeRegistryData or {})[client.weaponConfigUiState.shipType] or {}
end

local function _shipLabel()
    local state = client.weaponConfigUiState
    local known = _shipLabels[state.shipType]
    if known ~= nil then return known end
    return {
        zh = tostring(_shipDefinition().displayName or state.shipType),
        en = string.upper(tostring(state.shipType or "")),
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
        if definition.playerConfigurable ~= false
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

local function _weaponAllowed(slotType, weaponType)
    local pool = ((_shipDefinition().slotWeaponPools or {})[slotType]) or {}
    for _, candidate in ipairs(pool) do
        if tostring(candidate) == tostring(weaponType or "") then return true end
    end
    return false
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
        if not _weaponAllowed(slotType, state.loadout[slotType]) then
            state.loadout[slotType] = tostring(defaults[slotType] or "")
        end
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
    local bySlot = {}
    for _, group in ipairs((configuration or {}).slotGroups or {}) do
        bySlot[tostring(group.slotType or "")] = group
    end
    local result = {}
    for _, slotType in ipairs(_slotOrder) do
        if bySlot[slotType] ~= nil then result[#result + 1] = bySlot[slotType] end
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
    state.dirty = false
    state.message = "已载入本地设计 / LOCAL DESIGN LOADED"
    _ensureDraft()
end

local function _open()
    local state = client.weaponConfigUiState
    local available = _configurableShipTypes()
    if #available > 0 and _shipDefinition().shipType == nil then
        state.shipType = available[1]
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
    state.message = "已载入本地设计 / LOCAL DESIGN LOADED"
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
    local profile = shipComponentResolveProfile(
        definition,
        componentLoadout,
        configuration,
        loadout
    )
    if not ((profile.energy or {}).valid) then
        local state = client.weaponConfigUiState
        state.pending = false
        state.message = "能源必须为正 / POSITIVE POWER BALANCE REQUIRED"
        return false
    end
    local selected = loadout or {}
    client.weaponLocalConfigWrite(
        tostring(shipType or ""),
        tostring(configurationId or ""),
        {
            X = tostring(selected.X or ""),
            L = tostring(selected.L or ""),
            M = tostring(selected.M or ""),
            G = tostring(selected.G or ""),
            H = tostring(selected.H or ""),
            P = tostring(selected.P or ""),
        },
        componentLoadout
    )
    local state = client.weaponConfigUiState
    state.pending = false
    state.message = "设计已保存，仅影响下一艘生成的飞船"
        .. " / SAVED FOR NEXT SPAWN"
    state.dirty = false
    return true
end

function client.weaponConfigUiTick(dt)
    local _ = dt
    if InputPressed("t") then
        if client.weaponConfigUiState.open then _close() else _open() end
    end
end

local function _text(text, size, r, g, b, a)
    UiFont("regular.ttf", size)
    UiColor(r or 1, g or 1, b or 1, a or 1)
    UiText(tostring(text or ""))
end

local function _bilingual(zh, en, zhSize, enSize, color, alpha)
    local c = color or { 0.86, 0.94, 0.96 }
    _text(zh, zhSize or 20, c[1], c[2], c[3], alpha or 1)
    UiTranslate(0, (zhSize or 20) + 5)
    _text(en, enSize or 11, c[1] * 0.72, c[2] * 0.82, c[3] * 0.88, alpha or 1)
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
        local clicked = enabled and UiBlankButton(width, height)
        -- Keep the action usable on builds where UiBlankButton does not report
        -- a click after a preceding custom draw operation.
        if enabled and not clicked and hover and InputPressed("lmb") then
            clicked = true
        end
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
        _text(ship.zh, 19, 0.90, 0.77, 0.34, 1)
        UiTranslate(0, 23)
        _text(ship.en, 10, 0.58, 0.70, 0.68, 1)
    UiPop()
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
        _button(16, 176, _leftWidth - 32, 38, "切换舰船 / NEXT SHIP", false, true) then
        _selectNextShipType()
    end

    local frame = _frameLabel(configuration)
    UiPush()
        UiTranslate(18, 246)
        _bilingual("当前区段", "CURRENT SECTION", 18, 10)
    UiPop()
    if _button(
        18,
        296,
        _leftWidth - 36,
        56,
        frame.zh .. " / " .. frame.en .. "  ▼",
        false,
        true
    ) then
        _toggleFramePicker()
    end

    UiPush()
        UiTranslate(18, 375)
        _bilingual("部署规则", "DEPLOYMENT RULE", 18, 10)
        UiTranslate(0, 58)
        _text("当前飞船不会改变", 15, 0.70, 0.82, 0.78, 1)
        UiTranslate(0, 22)
        _text("EXISTING SHIPS UNCHANGED", 9, 0.40, 0.60, 0.56, 1)
        UiTranslate(0, 34)
        _text("配置应用于下一艘飞船", 15, 0.70, 0.82, 0.78, 1)
        UiTranslate(0, 22)
        _text("APPLIES TO NEXT SPAWN", 9, 0.40, 0.60, 0.56, 1)
    UiPop()

    if state.dirty then
        UiPush()
            UiTranslate(18, 552)
            _text("● 未保存 / UNSAVED", 12, 0.95, 0.64, 0.24, 1)
        UiPop()
    end
end

local function _drawWeaponOption(x, y, width, height, slotType, weaponType)
    local state = client.weaponConfigUiState
    local definition = (weaponData or {})[weaponType] or {}
    local selected = tostring(state.loadout[slotType] or "") == tostring(weaponType)
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

        UiTranslate(10, 10)
        UiColor(0.008, 0.018, 0.024, 1)
        UiRect(50, 50)
        local icon = tostring(definition.iconPath or "")
        if icon ~= "" then
            UiColor(1, 1, 1, 1)
            UiImageBox(icon, 50, 50, 0, 0)
        end
        UiTranslate(62, 1)
        _text(tostring(definition.displayName or weaponType), 15, 0.88, 0.95, 0.92, 1)
        UiTranslate(0, 20)
        _text(tostring(definition.englishName or weaponType), 10, 0.48, 0.68, 0.64, 1)
        UiTranslate(0, 19)
        _text(selected and "已装备 / EQUIPPED" or "点击装备 / SELECT", 9,
            selected and 0.40 or 0.34, selected and 0.86 or 0.58,
            selected and 0.72 or 0.54, 1)
        local clicked = hover and InputPressed("lmb")
    UiPop()
    return clicked
end

local function _drawWeaponSidebar(slotType)
    local state = client.weaponConfigUiState
    local slot = _slotLabels[slotType] or _slotLabels.M
    _panel(0, 0, _leftWidth, _mainHeight, true)
    UiPush()
        UiTranslate(18, 17)
        _bilingual("选择" .. slotType .. "槽武器", "SELECT " .. slot.en .. " WEAPON",
            18, 9, slot.color)
    UiPop()
    if _button(16, 68, _leftWidth - 32, 34, "← 返回 / BACK", false, true) then
        state.selectedSlot = ""
        return
    end

    local pool = ((_shipDefinition().slotWeaponPools or {})[slotType]) or {}
    local y = 104
    for _, weaponType in ipairs(pool) do
        if _drawWeaponOption(12, y, _leftWidth - 24, 74, slotType, tostring(weaponType)) then
            state.loadout[slotType] = tostring(weaponType)
            state.message = "未保存的设计 / UNSAVED DESIGN"
            state.dirty = true
        end
        y = y + 79
    end
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
        _text(tostring(definition.displayName or "空槽"), 14, 0.88, 0.95, 0.92, 1)
        UiTranslate(0, 20)
        _text(tostring(definition.englishName or "EMPTY"), 9, 0.48, 0.68, 0.64, 1)
        local clicked = hover and InputPressed("lmb")
    UiPop()
    return clicked
end

local function _drawDefenseSidebar(slotType)
    local state = client.weaponConfigUiState
    local label = _componentSlotLabels[slotType]
        or { zh = slotType, en = string.upper(slotType), mark = "?" }
    local slotLabel = label.zh
    local english = label.en
    _panel(0, 0, _leftWidth, _mainHeight, true)
    UiPush()
        UiTranslate(18, 17)
        _bilingual("选择" .. slotLabel, "SELECT " .. english, 18, 9)
    UiPop()
    if _button(16, 68, _leftWidth - 32, 34, "← 返回 / BACK", false, true) then
        state.selectedDefenseType = ""
        state.selectedDefenseIndex = 0
        return
    end
    local pool = ((_shipDefinition().componentPools or {})[slotType]) or {}
    local y = 108
    local optional = slotType == "largeUtility" or slotType == "auxiliary"
    if optional then
        if _drawDefenseOption(12, y, _leftWidth - 24, 68, slotType, "") then
            state.componentLoadout[slotType][state.selectedDefenseIndex] = ""
            state.message = "未保存的设计 / UNSAVED DESIGN"
            state.dirty = true
        end
        y = y + 73
    end
    for _, componentId in ipairs(pool) do
        local hiddenLowerReactorBooster = slotType == "auxiliary"
            and (componentId == "reactorBooster1"
                or componentId == "reactorBooster2")
        if not hiddenLowerReactorBooster then
            if _drawDefenseOption(12, y, _leftWidth - 24, 68, slotType, componentId) then
                state.componentLoadout[slotType][state.selectedDefenseIndex] =
                    tostring(componentId)
                state.message = "未保存的设计 / UNSAVED DESIGN"
                state.dirty = true
            end
            y = y + 73
        end
    end
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
        local clicked = hover and InputPressed("lmb")
    UiPop()
    return clicked
end

local function _drawGroupCard(x, y, width, height, group)
    local state = client.weaponConfigUiState
    local slotType = tostring(group.slotType or "")
    local slot = _slotLabels[slotType] or _slotLabels.M
    local weaponType = tostring(state.loadout[slotType] or "")
    local weapon = (weaponData or {})[weaponType] or {}
    local selected = state.selectedSlot == slotType

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

        UiTranslate(14, 12)
        UiColor(slot.color[1], slot.color[2], slot.color[3], 1)
        UiRect(46, 26)
        UiAlign("center middle")
        UiTranslate(23, 13)
        _text(slotType, 17, 0.03, 0.04, 0.05, 1)
        UiAlign("left top")
        UiTranslate(36, -7)
        _text("×" .. tostring(group.count or 0), 18, 0.88, 0.94, 0.92, 1)

        UiTranslate(-50, 36)
        local icon = tostring(weapon.iconPath or "")
        UiColor(0.006, 0.016, 0.022, 1)
        UiRect(58, 58)
        if icon ~= "" then
            UiColor(1, 1, 1, 1)
            UiImageBox(icon, 58, 58, 0, 0)
        end
        UiTranslate(70, 0)
        _text(tostring(weapon.displayName or weaponType), 13, 0.90, 0.95, 0.92, 1)
        UiTranslate(0, 18)
        _text(tostring(weapon.englishName or weaponType), 9, 0.48, 0.68, 0.64, 1)
        UiTranslate(0, 18)
        _text(slot.zh .. " / " .. slot.en, 8, slot.color[1], slot.color[2], slot.color[3], 1)
        UiTranslate(-70, 22)
        _text("点击更换整组武器 / CLICK TO CHANGE GROUP", 8, 0.38, 0.58, 0.54, 1)
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
        frame.zh .. "  /  " .. frame.en .. "  ▼",
        false,
        true
    ) then
        _toggleFramePicker()
    end

    UiPush()
        UiTranslate(x + 24, 94)
        _bilingual("武器组", "WEAPON GROUPS", 19, 10)
        UiTranslate(0, 48)
        UiColor(0.06, 0.25, 0.22, 1)
        UiRect(width - 48, 1)
    UiPop()

    local groups = _activeGroups(configuration)
    local cardGap = 12
    local coreStripWidth = 70
    local cardWidth = (width - 64 - cardGap - coreStripWidth) * 0.5
    local cardHeight = 132
    for index, group in ipairs(groups) do
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        local cardX = x + 24 + column * (cardWidth + cardGap)
        local cardY = 142 + row * (cardHeight + 10)
        if _drawGroupCard(cardX, cardY, cardWidth, cardHeight, group) then
            state.selectedSlot = tostring(group.slotType or "")
            state.selectedDefenseType = ""
            state.selectedDefenseIndex = 0
        end
    end

    local componentSlotCounts = {}
    for _, group in ipairs(shipComponentSlotGroups(configuration)) do
        componentSlotCounts[group.slotType] = group.count
    end

    UiPush()
        UiTranslate(x + width - 62, 102)
        _bilingual("核心", "CORE", 16, 9)
    UiPop()
    local coreTypes = { "thruster", "sensor", "reactor" }
    for index, slotType in ipairs(coreTypes) do
        if math.floor(tonumber(componentSlotCounts[slotType]) or 0) > 0 then
            if _drawDefenseSlot(
                x + width - 62,
                150 + (index - 1) * 66,
                58,
                slotType,
                1
            ) then
                state.selectedSlot = ""
                state.selectedDefenseType = slotType
                state.selectedDefenseIndex = 1
            end
        end
    end

    local weaponRows = math.ceil(#groups / 2)
    local defenseY = 142 + weaponRows * (cardHeight + 10) + 14
    UiPush()
        UiTranslate(x + 24, defenseY)
        _bilingual("防护与辅助组件", "DEFENSE & AUXILIARY", 18, 9)
    UiPop()
    local slotSize = 48
    local gap = 6
    local auxiliaryCount =
        math.floor(tonumber(componentSlotCounts.auxiliary) or 0)
    for index = 1, auxiliaryCount do
        local slotX = x + 24 + (index - 1) * (slotSize + gap)
        if _drawDefenseSlot(slotX, defenseY + 44, slotSize, "auxiliary", index) then
            state.selectedSlot = ""
            state.selectedDefenseType = "auxiliary"
            state.selectedDefenseIndex = index
        end
    end
    local largeCount =
        math.floor(tonumber(componentSlotCounts.largeUtility) or 0)
    for index = 1, largeCount do
        local slotX = x + 24 + (index - 1) * (slotSize + gap)
        if _drawDefenseSlot(slotX, defenseY + 102, slotSize, "largeUtility", index) then
            state.selectedSlot = ""
            state.selectedDefenseType = "largeUtility"
            state.selectedDefenseIndex = index
        end
    end
end

local function _drawSummary(configuration, x)
    local state = client.weaponConfigUiState
    _panel(x, 0, _rightWidth, _mainHeight, false)
    UiPush()
        UiTranslate(x + 18, 18)
        _bilingual("配置摘要", "DESIGN SUMMARY", 20, 10)
    UiPop()

    local frame = _frameLabel(configuration)
    UiPush()
        UiTranslate(x + 18, 75)
        _text("框架 / FRAME", 11, 0.38, 0.62, 0.58, 1)
        UiTranslate(0, 23)
        _text(frame.zh, 18, 0.90, 0.77, 0.34, 1)
        UiTranslate(0, 22)
        _text(frame.en, 9, 0.48, 0.64, 0.60, 1)
    UiPop()

    local y = 128
    for _, group in ipairs(_activeGroups(configuration)) do
        local slotType = tostring(group.slotType or "")
        local slot = _slotLabels[slotType] or _slotLabels.M
        local weaponType = tostring(state.loadout[slotType] or "")
        local weapon = (weaponData or {})[weaponType] or {}
        UiPush()
            UiTranslate(x + 16, y)
            UiColor(0.018, 0.060, 0.062, 1)
            UiRect(_rightWidth - 32, 70)
            UiColor(slot.color[1], slot.color[2], slot.color[3], 0.72)
            UiRect(3, 70)
            UiTranslate(12, 12)
            UiColor(slot.color[1], slot.color[2], slot.color[3], 1)
            UiRect(36, 24)
            UiAlign("center middle")
            UiTranslate(18, 12)
            _text(slotType .. "×" .. tostring(group.count or 0), 13, 0.03, 0.04, 0.05, 1)
            UiAlign("left top")
            UiTranslate(30, -8)
            _text(tostring(weapon.displayName or weaponType), 12, 0.86, 0.94, 0.90, 1)
            UiTranslate(0, 18)
            _text(tostring(weapon.englishName or weaponType), 8, 0.45, 0.65, 0.60, 1)
            UiTranslate(-48, 22)
            _text(slot.zh .. " / " .. slot.en, 8, slot.color[1], slot.color[2], slot.color[3], 1)
        UiPop()
        y = y + 78
    end

    local profile = _componentProfile(configuration)
    local protection = profile.protection or {}
    local mobility = profile.mobility or {}
    local energy = profile.energy or {}
    UiPush()
        UiTranslate(x + 18, 570)
        _bilingual("防护数据", "DEFENSE STATS", 17, 9)
        UiTranslate(0, 46)
        _text("船体 / HULL        " .. string.format("%.0f", protection.maxBodyHP), 12, 0.78, 0.90, 0.84, 1)
        UiTranslate(0, 22)
        _text("装甲 / ARMOR      " .. string.format("%.0f", protection.maxArmorHP), 12, 0.78, 0.90, 0.84, 1)
        UiTranslate(0, 22)
        _text("护盾 / SHIELD     " .. string.format("%.0f", protection.maxShieldHP), 12, 0.78, 0.90, 0.84, 1)
        UiTranslate(0, 22)
        _text("装甲硬化 / ARMOR  " .. string.format("%.0f%%", protection.armorHardening * 100), 11, 0.64, 0.80, 0.76, 1)
        UiTranslate(0, 20)
        _text("护盾硬化 / SHIELD " .. string.format("%.0f%%", protection.shieldHardening * 100), 11, 0.64, 0.80, 0.76, 1)
        UiTranslate(0, 20)
        _text(
            "航速/转向/力度  +"
                .. string.format("%.0f%%/%.0f%%/%.0f%%",
                    mobility.speedMultiplier * 100,
                    mobility.turnResponseMultiplier * 100,
                    mobility.turnForceMultiplier * 100),
            10, 0.64, 0.80, 0.76, 1
        )
        UiTranslate(0, 18)
        _text(
            "能源 / POWER  "
                .. string.format("%.0f - %.0f = %.0f",
                    energy.output or 0.0,
                    energy.use or 0.0,
                    energy.balance or 0.0),
            10,
            energy.valid and 0.58 or 0.96,
            energy.valid and 0.76 or 0.30,
            energy.valid and 0.70 or 0.22,
            1
        )
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
                local clicked = UiBlankButton(cardW, cardH)
                local label = _frameLabel(candidate)
                UiTranslate(22, 22)
                _bilingual(label.zh, label.en, 24, 11,
                    selected and { 0.94, 0.80, 0.38 } or { 0.82, 0.91, 0.87 })
                UiTranslate(0, 72)
                _text("武器槽 / WEAPON SLOTS", 12, 0.38, 0.62, 0.58, 1)
                UiTranslate(0, 31)
                _text(_groupSummary(candidate), 25, 0.80, 0.92, 0.86, 1)
                UiTranslate(0, 62)
                _text(selected and "当前框架 / CURRENT" or "点击选择 / SELECT",
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
                state.message = "未保存的设计 / UNSAVED DESIGN"
                state.dirty = true
                _ensureDraft()
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
    state.message = "已恢复默认设计 / DEFAULT DESIGN RESTORED"
    state.dirty = true
    _ensureDraft()
end

local function _drawFooter(configuration)
    local state = client.weaponConfigUiState
    local footerWidth = _panelWidth - 28
    local buttonY = _footerY + 48
    local resetX = footerWidth - 494
    local saveX = resetX + 182
    local cancelX = saveX + 182

    UiPush()
        UiTranslate(14, _footerY)
        UiColor(0.010, 0.045, 0.048, 1)
        UiRect(footerWidth, 104)
        UiColor(0.10, 0.48, 0.42, 1)
        UiRect(footerWidth, 2)
        UiTranslate(16, 16)
        _text(state.message or "", 13, 0.52, 0.74, 0.69, 1)
    UiPop()

    local designValid = ((_componentProfile(configuration).energy or {}).valid)
    if _button(
        14 + resetX,
        buttonY,
        170,
        38,
        "恢复默认 / RESET",
        false,
        not state.pending
    ) then
        _resetDraft()
        configuration = _ensureDraft() or configuration
        designValid = ((_componentProfile(configuration).energy or {}).valid)
    end
    if _button(
        14 + saveX,
        buttonY,
        170,
        38,
        "保存设计 / SAVE",
        true,
        not state.pending and designValid
    ) then
        client.weaponConfiguratorSaveTemplate(
            state.shipType,
            state.configurationId,
            _copyLoadout(state.loadout),
            _copyComponentLoadout(state.componentLoadout)
        )
    end
    if _button(
        14 + cancelX,
        buttonY,
        130,
        38,
        "关闭 / CLOSE",
        false,
        not state.pending
    ) then
        _close()
    end
    return configuration
end

function client.weaponConfigUiDraw()
    local state = client.weaponConfigUiState
    if not state.open then return end
    local configuration = _ensureDraft()
    if configuration == nil then return end

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

        UiTranslate(14, 88)
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

        -- Return to panel coordinates before drawing the fixed action bar.
        UiPush()
            UiTranslate(-14, -88)
            configuration = _drawFooter(configuration)
        UiPop()

        if state.framePickerOpen then
            UiPush()
                UiTranslate(-14, -88)
                _drawFramePicker()
            UiPop()
        end
    UiPop()
end
