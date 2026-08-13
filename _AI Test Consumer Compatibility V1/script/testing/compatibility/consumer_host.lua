#version 2

---@diagnostic disable: undefined-global

local fixture = {
    id = "test_consumer_compatibility_v1",
    revision = "compatibility-consumer-v1",
    packageId = GetStringParam("packageId", "missing"),
    packageHash = GetStringParam("packageHash", "missing"),
    policyHash = GetStringParam("policyHash", "missing"),
    validOperation = GetStringParam("validOperation", "missing"),
    invalidOperation = GetStringParam("invalidOperation", "missing"),
    installId = GetStringParam("installId", "missing"),
}

function server.init()
    SetString("CM2CompatibilityConsumer/id", fixture.id, true)
    SetString("CM2CompatibilityConsumer/revision", fixture.revision, true)
    SetString("CM2CompatibilityConsumer/packageId", fixture.packageId, true)
    SetString("CM2CompatibilityConsumer/packageHash", fixture.packageHash, true)
    SetString("CM2CompatibilityConsumer/policyHash", fixture.policyHash, true)
    SetString("CM2CompatibilityConsumer/validOperation", fixture.validOperation, true)
    SetString("CM2CompatibilityConsumer/invalidOperation", fixture.invalidOperation, true)
    SetString("CM2CompatibilityConsumer/installId", fixture.installId, true)
    SetBool("CM2CompatibilityConsumer/runtimeLuaLoaded", false, true)
    SetBool("CM2CompatibilityConsumer/loaded", true, true)
end

function client.draw()
    local installed = fixture.packageId == "cm2.creator.hello-ship"
        and string.len(fixture.packageHash) == 64
        and string.len(fixture.policyHash) == 64
    local compatibleAccepted = fixture.validOperation == "accepted:core-1.2.0/sdk-1.0.0/package-1"
    local incompatibleRejected = fixture.invalidOperation == "rejected:core-policy-version:2.0.0"
    local passed = installed and compatibleAccepted and incompatibleRejected

    UiPush()
        UiAlign("center middle")
        UiTranslate(UiCenter(), 70)
        UiFont("regular.ttf", 32)
        UiColor(1, 1, 1)
        UiText("CM2 EXTERNAL COMPATIBILITY CONSUMER")
        UiTranslate(0, 46)
        UiFont("regular.ttf", 23)
        if passed then
            UiColor(0.35, 1.0, 0.45)
            UiText("COMPATIBILITY POLICY V1 CONSUMER PASS")
        else
            UiColor(1.0, 0.3, 0.25)
            UiText("COMPATIBILITY POLICY V1 CONSUMER FAIL")
        end
        UiTranslate(0, 36)
        UiColor(0.82, 0.82, 0.82)
        UiFont("regular.ttf", 18)
        UiText("VALID  " .. fixture.validOperation)
        UiTranslate(0, 25)
        UiText("INVALID  " .. fixture.invalidOperation)
        UiTranslate(0, 25)
        UiText("POLICY  " .. string.sub(fixture.policyHash, 1, 20) .. "...")
        UiTranslate(0, 25)
        UiText("PACKAGE  " .. string.sub(fixture.packageHash, 1, 20) .. "...")
        UiTranslate(0, 25)
        UiText("RUNTIME LUA  FORBIDDEN / NOT LOADED")
        UiTranslate(0, 25)
        UiText(fixture.id .. " / " .. fixture.revision .. " / " .. fixture.installId)
    UiPop()
end
