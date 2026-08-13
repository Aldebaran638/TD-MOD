#version 2

---@diagnostic disable: undefined-global

local fixture = {
    id = "test_consumer_basic",
    revision = "consumer-basic-v3",
    packageId = GetStringParam("packageId", "missing"),
    packageVersion = GetStringParam("packageVersion", "missing"),
    packageHash = GetStringParam("packageHash", "missing"),
    validOperation = GetStringParam("validOperation", "missing"),
    invalidOperation = GetStringParam("invalidOperation", "missing"),
    buildId = GetStringParam("buildId", "missing"),
}

function server.init()
    SetString("CM2ConsumerTest/id", fixture.id, true)
    SetString("CM2ConsumerTest/revision", fixture.revision, true)
    SetString("CM2ConsumerTest/packageId", fixture.packageId, true)
    SetString("CM2ConsumerTest/packageVersion", fixture.packageVersion, true)
    SetString("CM2ConsumerTest/packageHash", fixture.packageHash, true)
    SetString("CM2ConsumerTest/validOperation", fixture.validOperation, true)
    SetString("CM2ConsumerTest/invalidOperation", fixture.invalidOperation, true)
    SetString("CM2ConsumerTest/buildId", fixture.buildId, true)
    SetBool("CM2ConsumerTest/runtimeLuaLoaded", false, true)
    SetBool("CM2ConsumerTest/loaded", true, true)
end

function client.draw()
    local installed = fixture.packageId ~= "missing"
        and fixture.packageVersion ~= "missing"
        and string.len(fixture.packageHash) == 64
    local validAccepted = fixture.validOperation == "accepted:Ship"
    local invalidRejected = fixture.invalidOperation == "rejected:unknown-capability:ExecuteLua"
    local passed = installed and validAccepted and invalidRejected

    UiPush()
        UiAlign("center middle")
        UiTranslate(UiCenter(), 90)
        UiFont("regular.ttf", 32)
        UiColor(1, 1, 1)
        UiText("CM2 EXTERNAL CONSUMER FIXTURE")
        UiTranslate(0, 46)
        UiFont("regular.ttf", 22)
        if passed then
            UiColor(0.35, 1.0, 0.45)
            UiText("PACKAGE MANIFEST V1 CONSUMER PASS")
        else
            UiColor(1.0, 0.3, 0.25)
            UiText("PACKAGE MANIFEST V1 CONSUMER FAIL")
        end
        UiTranslate(0, 34)
        UiColor(0.8, 0.8, 0.8)
        UiText(fixture.packageId .. " @ " .. fixture.packageVersion)
        UiTranslate(0, 28)
        UiFont("regular.ttf", 18)
        UiText("VALID  " .. fixture.validOperation)
        UiTranslate(0, 24)
        UiText("INVALID  " .. fixture.invalidOperation)
        UiTranslate(0, 24)
        UiText("RUNTIME LUA  FORBIDDEN / NOT LOADED")
        UiTranslate(0, 24)
        UiText("HASH  " .. string.sub(fixture.packageHash, 1, 20) .. "...")
        UiTranslate(0, 24)
        UiText(fixture.id .. " / " .. fixture.revision .. " / " .. fixture.buildId)
    UiPop()
end
