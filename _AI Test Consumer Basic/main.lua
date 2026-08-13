#version 2

---@diagnostic disable: undefined-global

local fixture = {
    id = "test_consumer_basic",
    revision = "consumer-basic-v1",
}

function server.init()
    SetString("CM2ConsumerTest/id", fixture.id, true)
    SetString("CM2ConsumerTest/revision", fixture.revision, true)
    SetBool("CM2ConsumerTest/loaded", true, true)
end

function client.draw()
    local protocol = GetString("StellarisShips/world/v1/protocolVersion")
    local telemetrySession = GetString("StellarisShips/telemetry/v1/session")
    local compatible = protocol ~= "" or telemetrySession ~= ""

    UiPush()
        UiAlign("center middle")
        UiTranslate(UiCenter(), 90)
        UiFont("regular.ttf", 32)
        UiColor(1, 1, 1)
        UiText("CM2 EXTERNAL CONSUMER FIXTURE")
        UiTranslate(0, 46)
        UiFont("regular.ttf", 22)
        if compatible then
            UiColor(0.35, 1.0, 0.45)
            UiText("VERSIONED CM2 REGISTRY DETECTED")
        else
            UiColor(1.0, 0.75, 0.2)
            UiText("WAITING FOR PUBLIC CM2 CONTRACT")
        end
        UiTranslate(0, 34)
        UiColor(0.8, 0.8, 0.8)
        UiText(fixture.id .. " / " .. fixture.revision)
    UiPop()
end
