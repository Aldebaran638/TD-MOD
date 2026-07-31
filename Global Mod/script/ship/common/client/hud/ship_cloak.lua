---@diagnostic disable: undefined-global

client = client or {}
client.shipCloakInputState = client.shipCloakInputState or { lastBody = 0 }

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
