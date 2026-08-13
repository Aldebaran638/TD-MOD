# Independent Consumer regression for an exact Creator SDK Alpha package build.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$installer = Join-Path $PSScriptRoot "install-sdk-consumer-v1.ps1"
$build = Join-Path $root "testing\fixtures\creator_sdk\alpha_project\.cm2-sdk\package"
$consumerHostPath = Join-Path $root "_AI Test Consumer SDK Alpha\script\testing\sdk_cli\consumer_host.lua"
$utf8 = New-Object Text.UTF8Encoding($false)
$script:assertions = 0
function Assert-True([bool]$condition, [string]$message) { if (-not $condition) { throw ("SDK Consumer self-test failed: " + $message) }; $script:assertions++; Write-Host ("[PASS] " + $message) -ForegroundColor Green }
function Invoke-Install([string]$buildPath, [string]$consumer, [string]$trace) {
    $saved = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer -BuildPath $buildPath -ConsumerRoot $consumer -TracePath $trace *> $null
    $code = [int]$LASTEXITCODE; $ErrorActionPreference = $saved; return $code
}
function New-Consumer([string]$path) { New-Item -ItemType Directory -Path (Join-Path $path "script\testing\sdk_cli") -Force | Out-Null; Copy-Item -LiteralPath $consumerHostPath -Destination (Join-Path $path "script\testing\sdk_cli\consumer_host.lua") }

$temp = Join-Path ([IO.Path]::GetTempPath()) ("cm2-sdk-consumer-test-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $temp -Force | Out-Null
try {
    $consumerOne = Join-Path $temp "consumer-one"; $consumerTwo = Join-Path $temp "consumer-two"; New-Consumer $consumerOne; New-Consumer $consumerTwo
    $traceOne = Join-Path $temp "one.trace.json"; $traceTwo = Join-Path $temp "two.trace.json"
    Assert-True ((Invoke-Install $build $consumerOne $traceOne) -eq 0) "installs exact SDK package into first independent Consumer"
    Assert-True ((Invoke-Install $build $consumerTwo $traceTwo) -eq 0) "installs exact SDK package into second independent Consumer"
    $one = Get-Content -Raw -LiteralPath $traceOne | ConvertFrom-Json; $two = Get-Content -Raw -LiteralPath $traceTwo | ConvertFrom-Json
    Assert-True ([string]$one.packageArtifactHash -eq [string]$two.packageArtifactHash -and [string]$one.compilerCatalogHash -eq [string]$two.compilerCatalogHash) "two installs select identical package and Compiler hashes"
    Assert-True ([string]$one.validOperation -eq "accepted:Ship" -and [string]$one.invalidOperation -eq "rejected:unknown-capability:ExecuteLua") "Consumer records valid and invalid public operations"
    Assert-True (-not [bool]$one.runtimeLuaLoaded -and [int]$one.consumerPrivateIncludes -eq 0) "Consumer loads no package Runtime Lua and no private CM2 code"
    $installedOne = Join-Path $consumerOne ([string]$one.installedArtifact).Replace("/", "\")
    $installedTwo = Join-Path $consumerTwo ([string]$two.installedArtifact).Replace("/", "\")
    Assert-True ([IO.File]::ReadAllText($installedOne) -ceq [IO.File]::ReadAllText($installedTwo)) "independent installs are byte-identical"
    [IO.File]::WriteAllText($installedOne, "tampered", $utf8)
    Assert-True ((Invoke-Install $build $consumerOne $traceOne) -eq 0) "exact reinstall repairs a tampered installed artifact"
    Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath $installedOne).Hash.ToLowerInvariant() -eq [string]$one.packageArtifactHash) "reinstall restores exact valid artifact bytes"
    $lastValid = [IO.File]::ReadAllText($installedOne)
    $invalidBuild = Join-Path $temp "invalid-build"; Copy-Item -LiteralPath $build -Destination $invalidBuild -Recurse
    [IO.File]::AppendAllText((Join-Path $invalidBuild "package.artifact.json"), "drift", $utf8)
    Assert-True ((Invoke-Install $invalidBuild $consumerOne $traceOne) -ne 0) "invalid SDK artifact fails before Consumer install"
    Assert-True ([IO.File]::ReadAllText($installedOne) -ceq $lastValid) "failed install preserves the last valid Consumer artifact exactly"
    Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $consumerOne "packages") -Recurse -File -Filter "*.lua").Count -eq 0) "installed package tree contains no Lua files"
}
finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue } }
Write-Host ("Creator SDK Consumer self-test passed: " + $script:assertions + " assertions.") -ForegroundColor Green
exit 0
