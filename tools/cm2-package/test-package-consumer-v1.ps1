# Self-test for the independent PackageManifest consumer install boundary.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$installer = Join-Path $PSScriptRoot "install-package-consumer-v1.ps1"
$sourceConsumer = Join-Path $root "_AI Test Consumer Basic"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-package-consumer-test-" + [Guid]::NewGuid().ToString("N"))
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("Package consumer self-test failed: " + $message) }
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function Invoke-Install([string]$consumer, [string]$trace, [string]$buildId) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer -ConsumerRoot $consumer -TracePath $trace -BuildId $buildId *> $null
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    return $code
}

New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $consumerOne = Join-Path $tempRoot "consumer-one"
    $consumerTwo = Join-Path $tempRoot "consumer-two"
    Copy-Item -LiteralPath $sourceConsumer -Destination $consumerOne -Recurse
    Copy-Item -LiteralPath $sourceConsumer -Destination $consumerTwo -Recurse
    $traceOne = Join-Path $tempRoot "one.trace.json"
    $traceTwo = Join-Path $tempRoot "two.trace.json"
    Assert-True ((Invoke-Install $consumerOne $traceOne "package-consumer-build-v1") -eq 0) "installs the public artifact into clean consumer one"
    Assert-True ((Invoke-Install $consumerTwo $traceTwo "package-consumer-build-v1") -eq 0) "installs the public artifact into clean consumer two"
    $one = Get-Content -Raw -LiteralPath $traceOne | ConvertFrom-Json
    $two = Get-Content -Raw -LiteralPath $traceTwo | ConvertFrom-Json
    Assert-True ([string]$one.packageArtifactHash -eq [string]$two.packageArtifactHash) "two clean installs select the same package hash"
    Assert-True ([IO.File]::ReadAllText((Join-Path $consumerOne "main.xml")) -ceq [IO.File]::ReadAllText((Join-Path $consumerTwo "main.xml"))) "two clean installs emit byte-identical Mod XML"
    Assert-True ([IO.File]::ReadAllText((Join-Path $consumerOne "main.xml")).Contains('file="MOD/script/testing/package_manifest/consumer_host.lua"')) "generated XML uses a parameterized non-main script host"
    Assert-True ([string]$one.validOperation -eq "accepted:Ship") "valid public Ship capability is accepted"
    Assert-True ([string]$one.invalidOperation -eq "rejected:unknown-capability:ExecuteLua") "unknown ExecuteLua capability fails closed"
    Assert-True (-not [bool]$one.runtimeLuaLoaded -and [int]$one.consumerPrivateIncludes -eq 0) "consumer loads no package Lua and includes no private CM2 implementation"
    Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $consumerOne "packages") -Recurse -File -Filter "*.lua").Count -eq 0) "installed package tree contains no Lua"

    $tampered = Join-Path $consumerOne "packages\cm2.thirdparty.hello-ship\package.artifact.json"
    [IO.File]::WriteAllText($tampered, "tampered", $utf8)
    Assert-True ((Invoke-Install $consumerOne $traceOne "package-consumer-build-v1") -eq 0) "reinstall replaces a tampered artifact from clean source"
    Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath $tampered).Hash.ToLowerInvariant() -eq [string]$one.packageArtifactHash) "exact reinstall restores the valid package bytes"
}
finally {
    if (Test-Path -LiteralPath $tempRoot -PathType Container) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "Package consumer self-test passed." -ForegroundColor Green
exit 0
