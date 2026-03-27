---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.shipHelpOverlayConfig = client.shipHelpOverlayConfig or {
    width = 320,
    rightOffset = 24,
    topOffset = 170,
    lineGap = 8,
    titleSize = 20,
    textSize = 16,

    bgColor = { 0.05, 0.07, 0.09, 0.76 },
    borderColor = { 1.0, 1.0, 1.0, 0.22 },
    titleColor = { 1.0, 0.96, 0.90, 1.0 },
    textColor = { 0.90, 0.93, 0.96, 0.98 },
    keyColor = { 0.30, 0.84, 1.0, 1.0 },
    subColor = { 0.72, 0.80, 0.88, 0.95 },
}

client.shipHelpOverlayState = client.shipHelpOverlayState or {
    visible = true,
}

local function _shipHelpResolveControlledShipBody()
    if client.shipCameraGetControlledBody ~= nil then
        local body = client.shipCameraGetControlledBody()
        if body ~= nil and body ~= 0 then
            return body
        end
    end

    local veh = GetPlayerVehicle()
    if veh == nil or veh == 0 then
        return 0
    end

    local playerBody = GetVehicleBody(veh)
    local scriptBody = client.shipBody or 0
    if scriptBody == 0 or playerBody == nil or playerBody == 0 or playerBody ~= scriptBody then
        return 0
    end

    if client.registryShipExists ~= nil and (not client.registryShipExists(scriptBody)) then
        return 0
    end

    return scriptBody
end

local function _shipHelpDrawLine(y, keyText, zhText, enText, cfg)
    UiPush()
        UiTranslate(14, y)
        UiColor(cfg.keyColor[1], cfg.keyColor[2], cfg.keyColor[3], cfg.keyColor[4])
        UiFont("regular.ttf", cfg.textSize)
        UiText(keyText)
    UiPop()

    UiPush()
        UiTranslate(76, y)
        UiColor(cfg.textColor[1], cfg.textColor[2], cfg.textColor[3], cfg.textColor[4])
        UiFont("regular.ttf", cfg.textSize)
        UiText(zhText)
    UiPop()

    UiPush()
        UiTranslate(76, y + 18)
        UiColor(cfg.subColor[1], cfg.subColor[2], cfg.subColor[3], cfg.subColor[4])
        UiFont("regular.ttf", cfg.textSize - 2)
        UiText(enText)
    UiPop()
end

function client.shipHelpOverlayTick(dt)
    local _ = dt
    if InputPressed("u") then
        client.shipHelpOverlayState.visible = not client.shipHelpOverlayState.visible
    end
end

function client.shipHelpOverlayDraw()
    local state = client.shipHelpOverlayState
    if not state.visible then
        return
    end

    if _shipHelpResolveControlledShipBody() == 0 then
        return
    end

    local cfg = client.shipHelpOverlayConfig
    local panelW = cfg.width
    local panelH = 242
    local x = UiWidth() - panelW - cfg.rightOffset
    local y = cfg.topOffset

    UiPush()
        UiAlign("left top")
        UiTranslate(x, y)
        UiColor(cfg.bgColor[1], cfg.bgColor[2], cfg.bgColor[3], cfg.bgColor[4])
        UiRect(panelW, panelH)
        UiColor(cfg.borderColor[1], cfg.borderColor[2], cfg.borderColor[3], cfg.borderColor[4])
        UiRectOutline(panelW, panelH, 2)

        UiPush()
            UiTranslate(14, 12)
            UiColor(cfg.titleColor[1], cfg.titleColor[2], cfg.titleColor[3], cfg.titleColor[4])
            UiFont("regular.ttf", cfg.titleSize)
            UiText("飞船操作 / Ship Controls")
        UiPop()

        _shipHelpDrawLine(48, "AUTO", "飞船自动浮空", "The ship hovers automatically", cfg)
        _shipHelpDrawLine(92, "W / S", "前后移动", "Move forward / backward", cfg)
        _shipHelpDrawLine(136, "MOUSE", "鼠标控制朝向", "Mouse controls ship facing", cfg)
        _shipHelpDrawLine(180, "LMB", "左键开火", "Left click to fire", cfg)
        _shipHelpDrawLine(224, "RMB / Q / U", "右键切换视角，Q切武器，U开关说明", "Right click changes camera, Q swaps weapons, U toggles help", cfg)
    UiPop()
end
