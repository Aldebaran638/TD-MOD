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
    message = "",
}

local _panelWidth = 1240
local _panelHeight = 820
local _sidebarWidth = 266
local _groupOrder = { "X", "L", "G", "M", "H" }
local _slotNames = {
    X = "SPINAL",
    L = "LARGE",
    M = "MEDIUM",
    G = "TORPEDO",
    H = "HANGAR",
}

local function _uiRegistryKey()
    return client.weaponLocalConfigUiOpenKey()
end

local function _shipDefinition()
    return (shipTypeRegistryData or {})[client.weaponConfigUiState.shipType] or {}
end

local function _shipDisplayName()
    return tostring(_shipDefinition().displayName or client.weaponConfigUiState.shipType)
end

local function _configurableShipTypes()
    local result = {}
    for shipType, definition in pairs(shipTypeRegistryData or {}) do
        if #(definition.slotConfigurations or {}) > 0 then result[#result + 1] = tostring(shipType) end
    end
    table.sort(result)
    return result
end

local function _findConfiguration(configurationId)
    for _, configuration in ipairs(_shipDefinition().slotConfigurations or {}) do
        if tostring(configuration.configurationId or "") == tostring(configurationId or "") then
            return configuration
        end
    end
    return nil
end

local function _copyLoadout(source)
    local result = {}
    for key, value in pairs(source or {}) do result[key] = tostring(value or "") end
    return result
end

local function _weaponAllowed(slotType, weaponType)
    for _, candidate in ipairs(((_shipDefinition().slotWeaponPools or {})[slotType]) or {}) do
        if tostring(candidate) == tostring(weaponType or "") then return true end
    end
    return false
end

local function _ensureDraft()
    local state = client.weaponConfigUiState
    local configuration = _findConfiguration(state.configurationId)
    if configuration == nil then
        state.configurationId = tostring(_shipDefinition().defaultSlotConfigurationId or "battleline_2x2l4m")
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
    return configuration
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
    state.dirty = false
    state.message = "LOCAL DESIGN LOADED"
    _ensureDraft()
end

local function _open()
    local state = client.weaponConfigUiState
    local available = _configurableShipTypes()
    if #available > 0 and _shipDefinition().shipType == nil then state.shipType = available[1] end
    local template = client.weaponConfiguratorRequestTemplate(state.shipType)
    state.configurationId = tostring(template.configurationId or "")
    state.loadout = _copyLoadout(template.loadout)
    state.pending = false
    state.dirty = false
    state.message = "LOCAL DESIGN LOADED"
    state.open = true
    SetBool(_uiRegistryKey(), true)
    _ensureDraft()
end

local function _close()
    client.weaponConfigUiState.open = false
    client.weaponConfigUiState.pending = false
    SetBool(_uiRegistryKey(), false)
end

function client.weaponConfigUiSetOpen(open)
    if open then _open() else _close() end
end

function client.weaponConfigUiIsOpen()
    return client.weaponConfigUiState.open and true or false
end

function client.weaponConfiguratorRequestTemplate(shipType)
    return client.weaponLocalConfigRead(tostring(shipType or ""))
end

function client.weaponConfiguratorSaveTemplate(shipType, configurationId, loadout)
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
        }
    )
    local state = client.weaponConfigUiState
    state.pending = false
    state.message = "LOCAL DESIGN SAVED — APPLIES TO THE NEXT SPAWNED " .. string.upper(_shipDisplayName())
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

local function _frameCard(x, y, width, height, configuration, selected, enabled)
    UiPush()
        UiTranslate(x, y)
        local hover = enabled and UiIsMouseInRect(width, height)
        UiColor(selected and 0.055 or 0.025, selected and 0.18 or 0.07, selected and 0.25 or 0.10, 0.98)
        UiRect(width, height)
        if hover and not selected then
            UiColor(0.08, 0.32, 0.42, 0.32)
            UiRect(width, height)
        end
        UiColor(selected and 0.22 or 0.10, selected and 0.82 or 0.34, selected and 1.0 or 0.48, 1)
        UiRect(4, height)
        UiRectOutline(width, height, selected and 2 or 1)
        UiTranslate(18, 16)
        _text(tostring(configuration.label or configuration.configurationId), 25, 0.84, 0.95, 1, 1)
        UiTranslate(0, 31)
        local groups = {}
        for _, group in ipairs(configuration.slotGroups or {}) do
            groups[#groups + 1] = tostring(group.count or 0) .. tostring(group.slotType or "")
        end
        _text(table.concat(groups, "  •  "), 16, 0.42, 0.66, 0.76, 1)
        local clicked = enabled and hover and InputPressed("lmb")
    UiPop()
    return clicked
end

local function _weaponCard(x, y, width, height, slotType, weaponType, selected, enabled)
    local definition = (weaponData or {})[weaponType] or {}
    UiPush()
        UiTranslate(x, y)
        local hover = enabled and UiIsMouseInRect(width, height)
        UiColor(selected and 0.04 or 0.025, selected and 0.20 or 0.075, selected and 0.28 or 0.105, 0.98)
        UiRect(width, height)
        if hover and not selected then
            UiColor(0.10, 0.44, 0.56, 0.28)
            UiRect(width, height)
        end
        UiColor(selected and 0.28 or 0.10, selected and 0.90 or 0.38, selected and 1.0 or 0.52, 1)
        UiRectOutline(width, height, selected and 2 or 1)
        if selected then
            UiRect(width, 3)
        end

        local icon = tostring(definition.iconPath or "")
        UiTranslate(8, 8)
        UiColor(0.015, 0.035, 0.05, 1)
        UiRect(40, 40)
        if icon ~= "" then
            UiColor(1, 1, 1, enabled and 1 or 0.45)
            UiImageBox(icon, 40, 40, 0, 0)
        end
        UiTranslate(0, 46)
        _text(tostring(definition.displayName or weaponType), 13, 0.88, 0.95, 0.98, enabled and 1 or 0.45)
        UiTranslate(0, 15)
        local _en = tostring(definition.englishName or weaponType)
        _text(_en, 9, 0.52, 0.74, 0.84, enabled and 0.85 or 0.38)
        UiTranslate(0, 11)
        _text(string.upper(tostring(definition.behaviorType or "")), 9, 0.35, 0.65, 0.76, enabled and 1 or 0.45)
        local clicked = enabled and hover and InputPressed("lmb")
    UiPop()
    return clicked
end

local function _actionButton(x, y, width, height, text, primary, enabled)
    UiPush()
        UiTranslate(x, y)
        local hover = enabled and UiIsMouseInRect(width, height)
        if primary then
            UiColor(0.04, hover and 0.54 or 0.40, hover and 0.69 or 0.56, enabled and 1 or 0.45)
        else
            UiColor(0.04, 0.09, 0.12, enabled and 0.98 or 0.45)
        end
        UiRect(width, height)
        UiColor(primary and 0.34 or 0.14, primary and 0.92 or 0.46, 1, 1)
        UiRectOutline(width, height, primary and 2 or 1)
        UiAlign("center middle")
        UiTranslate(width * 0.5, height * 0.5)
        _text(text, 20, 0.92, 0.98, 1, enabled and 1 or 0.45)
        local clicked = enabled and hover and InputPressed("lmb")
    UiPop()
    return clicked
end

function client.weaponConfigUiDraw()
    local state = client.weaponConfigUiState
    if not state.open then return end
    local configuration = _ensureDraft()
    if configuration == nil then return end

    UiPush()
        UiMakeInteractive()
        UiBlur(0.65)
        UiColor(0.002, 0.008, 0.012, 0.80)
        UiRect(UiWidth(), UiHeight())

        local scale = math.min(UiWidth() / 1360, UiHeight() / 800, 1.15)
        UiTranslate((UiWidth() - _panelWidth * scale) * 0.5, (UiHeight() - _panelHeight * scale) * 0.5)
        UiScale(scale)

        UiColor(0.012, 0.030, 0.043, 0.995)
        UiRect(_panelWidth, _panelHeight)
        UiColor(0.10, 0.52, 0.68, 1)
        UiRectOutline(_panelWidth, _panelHeight, 2)
        UiColor(0.10, 0.66, 0.84, 1)
        UiRect(_panelWidth, 4)

        UiColor(0.018, 0.052, 0.070, 1)
        UiRect(_sidebarWidth, _panelHeight)
        UiColor(0.08, 0.34, 0.44, 1)
        UiTranslate(_sidebarWidth, 0)
        UiRect(1, _panelHeight)
        UiTranslate(-_sidebarWidth, 0)

        UiTranslate(24, 24)
        UiPush()
            _text("SHIP DESIGNER", 30, 0.66, 0.91, 1, 1)
            UiTranslate(0, 36)
            _text("SPAWN TEMPLATE", 15, 0.28, 0.68, 0.82, 1)
            UiTranslate(0, 72)
            _text("WEAPON FRAME", 14, 0.42, 0.64, 0.72, 1)
        UiPop()

        local availableShipTypes = _configurableShipTypes()
        if _actionButton(0, 76, _sidebarWidth - 48, 36, string.upper(_shipDisplayName()), false, not state.pending) then
            _selectNextShipType()
        end
        if #availableShipTypes > 1 then
            UiPush()
                UiTranslate(0, 116)
                _text("Click ship class to cycle", 11, 0.32, 0.60, 0.70, 1)
            UiPop()
        end

        for index, candidate in ipairs(_shipDefinition().slotConfigurations or {}) do
            if _frameCard(
                0, 150 + (index - 1) * 96, _sidebarWidth - 48, 78,
                candidate,
                state.configurationId == tostring(candidate.configurationId or ""),
                not state.pending
            ) then
                state.configurationId = tostring(candidate.configurationId or "")
                state.message = "UNSAVED DESIGN"
                state.dirty = true
                _ensureDraft()
            end
        end

        UiPush()
            UiTranslate(0, 732)
            UiColor(0.03, 0.12, 0.16, 1)
            UiRect(_sidebarWidth - 48, 72)
            UiTranslate(12, 12)
            _text("DEPLOYMENT RULE", 12, 0.30, 0.70, 0.82, 1)
            UiTranslate(0, 20)
            _text("Existing ships remain unchanged.", 14, 0.70, 0.82, 0.86, 1)
            UiTranslate(0, 18)
            _text("Design loads on the next spawn.", 14, 0.70, 0.82, 0.86, 1)
        UiPop()

        UiTranslate(_sidebarWidth + 28, 0)
        _text(tostring(configuration.label or configuration.configurationId), 28, 0.82, 0.95, 1, 1)
        UiTranslate(0, 33)
        _text("Select one weapon for every active slot group", 15, 0.40, 0.65, 0.74, 1)
        UiColor(0.06, 0.24, 0.31, 1)
        UiTranslate(0, 34)
        UiRect(900, 1)

        local row = 0
        for _, slotType in ipairs(_groupOrder) do
            local active = false
            for _, group in ipairs(configuration.slotGroups or {}) do
                if tostring(group.slotType or "") == slotType then active = true end
            end
            if active then
                local y = 72 + row * 132
                UiPush()
                    UiTranslate(0, y)
                    UiColor(0.025, 0.075, 0.098, 0.96)
                    UiRect(900, 120)
                    UiColor(0.08, 0.31, 0.40, 1)
                    UiRectOutline(900, 120, 1)
                    UiTranslate(14, 14)
                    _text(slotType, 28, 0.30, 0.82, 1, 1)
                    UiTranslate(0, 32)
                    _text(_slotNames[slotType] or slotType, 11, 0.34, 0.59, 0.68, 1)
                    local pool = ((_shipDefinition().slotWeaponPools or {})[slotType]) or {}
                    for index, weaponType in ipairs(pool) do
                        if _weaponCard(
                            74 + (index - 1) * 134, -36, 124, 116,
                            slotType,
                            tostring(weaponType),
                            state.loadout[slotType] == tostring(weaponType),
                            not state.pending
                        ) then
                            state.loadout[slotType] = tostring(weaponType)
                            state.message = "UNSAVED DESIGN"
                            state.dirty = true
                        end
                    end
                UiPop()
                row = row + 1
            end
        end

        local footerY = 732
        UiPush()
            UiTranslate(0, footerY)
            UiColor(0.025, 0.074, 0.095, 1)
            UiRect(900, 74)
            UiTranslate(16, 28)
            _text(state.message or "", 14, 0.52, 0.76, 0.84, 1)
        UiPop()

        if _actionButton(604, footerY + 12, 170, 48, "SAVE DESIGN", true, not state.pending) then
            client.weaponConfiguratorSaveTemplate(
                state.shipType,
                state.configurationId,
                _copyLoadout(state.loadout)
            )
        end
        if _actionButton(786, footerY + 12, 114, 48, "CLOSE", false, not state.pending) then _close() end
    UiPop()
end
