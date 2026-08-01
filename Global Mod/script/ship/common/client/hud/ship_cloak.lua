---@diagnostic disable: undefined-global

client = client or {}
client.shipCloakInputState = client.shipCloakInputState or { lastBody = 0 }

local function _shipCloakPlayerVehicleBody(playerId)
    local vehicle = GetPlayerVehicle(playerId)
    if vehicle == nil or vehicle == 0 then return 0 end
    local body = GetVehicleBody(vehicle)
    if body == nil or body == 0 then return 0 end
    return body
end

function client.shipCloakPlayersTick()
    local anyCloaked = false
    for _, body in ipairs(client.registryShipGetRegisteredBodyIds() or {}) do
        if client.registryShipIsCloaked(body) then
            anyCloaked = true
            break
        end
    end

    for _, playerId in ipairs(GetAllPlayers() or {}) do
        local body = _shipCloakPlayerVehicleBody(playerId)
        if body ~= 0 and client.registryShipIsCloaked(body) then
            -- SetPlayerHidden is frame-scoped, so refresh it while cloaked.
            SetPlayerHidden(playerId)
        end
    end

    -- The stock multiplayer HUD exposes only a level-wide nameplate switch;
    -- keep it in sync with the cloak state so a cloaked pilot's name is not
    -- rendered above the hidden character.
    SetBool("level.hidenameplates", anyCloaked)
end

function client.shipCloakInputTick()
    local body = client.shipContextGetBody()
    if body == 0 or not client.registryShipExists(body) then return end
    local state = client.shipCloakInputState
    if body ~= state.lastBody then state.lastBody = body end
    if InputPressed("c") then
        client.shipRequestToggleCloak(body, not client.registryShipIsCloaked(body))
    end
end

function client.shipCloakDraw()
    local body = client.shipContextGetBody()
    if body == 0 or not client.registryShipExists(body) then return end
    local strength = client.registryShipGetCloakStrength(body)
    if strength <= 0.0 then return end
    UiPush()
        UiTranslate(UiWidth() - 34, 34)
        UiAlign("right top")
        UiFont("regular.ttf", 15)
        if client.registryShipIsCloaked(body) then
            UiColor(0.30, 0.90, 1.0, 0.95)
            UiText("CLOAKED")
        else
            UiColor(0.65, 0.75, 0.80, 0.80)
            UiText("CLOAK READY")
        end
    UiPop()
end
