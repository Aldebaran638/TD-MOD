#version 2

---@diagnostic disable: undefined-global

local fixture = {
    id = "test_consumer_sdk_alpha",
    revision = "sdk-consumer-v1",
    packageId = GetStringParam("packageId", "missing"),
    packageVersion = GetStringParam("packageVersion", "missing"),
    packageHash = GetStringParam("packageHash", "missing"),
    validOperation = GetStringParam("validOperation", "missing"),
    invalidOperation = GetStringParam("invalidOperation", "missing"),
    buildId = GetStringParam("buildId", "missing"),
    compilerHash = GetStringParam("compilerHash", "missing"),
}

function server.init()
    SetString("CM2SdkConsumer/id", fixture.id, true)
    SetString("CM2SdkConsumer/revision", fixture.revision, true)
    SetString("CM2SdkConsumer/packageId", fixture.packageId, true)
    SetString("CM2SdkConsumer/packageVersion", fixture.packageVersion, true)
    SetString("CM2SdkConsumer/packageHash", fixture.packageHash, true)
    SetString("CM2SdkConsumer/validOperation", fixture.validOperation, true)
    SetString("CM2SdkConsumer/invalidOperation", fixture.invalidOperation, true)
    SetString("CM2SdkConsumer/buildId", fixture.buildId, true)
    SetString("CM2SdkConsumer/compilerHash", fixture.compilerHash, true)
    SetBool("CM2SdkConsumer/runtimeLuaLoaded", false, true)
    SetBool("CM2SdkConsumer/loaded", true, true)
end

function client.draw()
    local installed = fixture.packageId == "cm2.creator.hello-ship"
        and fixture.packageVersion == "0.1.0"
        and string.len(fixture.packageHash) == 64
        and string.len(fixture.compilerHash) == 64
    local validAccepted = fixture.validOperation == "accepted:Ship"
    local invalidRejected = fixture.invalidOperation == "rejected:unknown-capability:ExecuteLua"
    local passed = installed and validAccepted and invalidRejected

    UiPush()
        UiAlign("center middle")
        UiTranslate(UiCenter(), 76)
        UiFont("regular.ttf", 32)
        UiColor(1, 1, 1)
        UiText("CM2 CREATOR SDK EXTERNAL CONSUMER")
        UiTranslate(0, 46)
        UiFont("regular.ttf", 22)
        if passed then
            UiColor(0.35, 1.0, 0.45)
            UiText("CREATOR SDK CLI ALPHA CONSUMER PASS")
        else
            UiColor(1.0, 0.3, 0.25)
            UiText("CREATOR SDK CLI ALPHA CONSUMER FAIL")
        end
        UiTranslate(0, 34)
        UiColor(0.8, 0.8, 0.8)
        UiText(fixture.packageId .. " @ " .. fixture.packageVersion)
        UiTranslate(0, 27)
        UiFont("regular.ttf", 18)
        UiText("VALID  " .. fixture.validOperation)
        UiTranslate(0, 24)
        UiText("INVALID  " .. fixture.invalidOperation)
        UiTranslate(0, 24)
        UiText("SHARED COMPILER  " .. string.sub(fixture.compilerHash, 1, 20) .. "...")
        UiTranslate(0, 24)
        UiText("RUNTIME LUA  FORBIDDEN / NOT LOADED")
        UiTranslate(0, 24)
        UiText("PACKAGE  " .. string.sub(fixture.packageHash, 1, 20) .. "...")
        UiTranslate(0, 24)
        UiText(fixture.id .. " / " .. fixture.revision .. " / " .. fixture.buildId)
    UiPop()
end
