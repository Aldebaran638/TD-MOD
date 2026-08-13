# Deterministic regression for the ProjectPath-driven Creator SDK CLI Alpha.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$cli = Join-Path $PSScriptRoot "cm2-sdk.ps1"
$fixture = Get-Content -Raw -LiteralPath (Join-Path $root "docs\candidates\sdk-cli-v1.fixture.json") | ConvertFrom-Json
$utf8 = New-Object Text.UTF8Encoding($false)
$script:assertions = 0

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("Creator SDK CLI self-test failed: " + $message) }
    $script:assertions++
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function Invoke-Sdk([string]$command, [string]$project, [string]$output = "") {
    $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $cli, "-Command", $command)
    if ($project -ne "") { $arguments += @("-ProjectPath", $project) }
    if ($output -ne "") { $arguments += @("-OutputPath", $output) }
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $lines = @(& powershell.exe @arguments 2>&1)
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    $jsonLine = @($lines | ForEach-Object { [string]$_ } | Where-Object { $_.TrimStart().StartsWith("{") }) | Select-Object -Last 1
    $json = if ($null -ne $jsonLine) { $jsonLine | ConvertFrom-Json } else { $null }
    return [pscustomobject]@{ code=$code; json=$json; lines=$lines }
}
function Read-Document([string]$path) { return Get-Content -Raw -LiteralPath $path | ConvertFrom-Json }
function Write-Document([string]$path, [object]$value) { [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 100 -Compress), $utf8) }
function Tree-Fingerprint([string]$path) {
    $parts = @(Get-ChildItem -LiteralPath $path -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/]\.cm2-sdk[\\/]' } | Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring($path.Length).TrimStart("\", "/").Replace("\", "/")
        $relative + "=" + (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
    })
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($parts -join "`n"))))).Replace("-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Assert-Error([object]$result, [string]$code, [string]$message) {
    Assert-True ($result.code -ne 0 -and $null -ne $result.json -and [string]$result.json.result -eq "fail") ($message + " fails closed")
    Assert-True ([string]$result.json.code -eq $code) ($message + " returns " + $code)
    foreach ($field in @($fixture.expected.stableErrorFields)) { Assert-True ($null -ne $result.json.PSObject.Properties[[string]$field]) ($message + " exposes stable " + [string]$field) }
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-sdk-test-" + [Guid]::NewGuid().ToString("N"))
$projectOne = Join-Path $tempRoot "windows-workstation"
$projectTwo = Join-Path $tempRoot "ci-clean-root"
$projectAlias = Join-Path $tempRoot "new-alias"
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $initOne = Invoke-Sdk "init" $projectOne
    $initTwo = Invoke-Sdk "init" $projectTwo
    Assert-True ($initOne.code -eq 0 -and [string]$initOne.json.result -eq "pass") "init creates a usable Windows project"
    Assert-True ($initTwo.code -eq 0 -and [string]$initTwo.json.result -eq "pass") "init creates a second clean CI project"
    Assert-True ((Invoke-Sdk "new" $projectAlias).code -eq 0) "new remains an init-compatible alias"
    Assert-True ((Tree-Fingerprint $projectOne) -eq (Tree-Fingerprint $projectTwo)) "init emits byte-identical clean-room source trees"
    Assert-True (@(Get-ChildItem -LiteralPath $projectOne -Recurse -File -Filter "*.lua").Count -eq 0) "init emits no Runtime Lua"
    Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $projectOne "definitions") -Recurse -File -Filter "*.json").Count -eq 5) "hello-ship contains five public source-envelope definitions"

    $validateOne = Invoke-Sdk "validate" $projectOne
    $validateTwo = Invoke-Sdk "validate" $projectTwo
    Assert-True ($validateOne.code -eq 0 -and [int]$validateOne.json.definitionCount -eq 5) "validate executes the shared Compiler over ProjectPath"
    Assert-True ([string]$validateOne.json.manifestHash -eq [string]$validateTwo.json.manifestHash) "validation hash is root-independent"
    Assert-True ([string]$validateOne.json.compilerInputHash -eq [string]$validateTwo.json.compilerInputHash) "Compiler input hash is root-independent"

    $buildOne = Invoke-Sdk "build" $projectOne
    $buildTwo = Invoke-Sdk "build" $projectTwo
    Assert-True ($buildOne.code -eq 0 -and [string]$buildOne.json.compilerMode -eq "shared-compiler") "build uses the shared Definition Compiler"
    Assert-True ($buildTwo.code -eq 0) "second clean-root build passes"
    $buildPathOne = Join-Path $projectOne ".cm2-sdk\build"
    $buildPathTwo = Join-Path $projectTwo ".cm2-sdk\build"
    foreach ($output in @($fixture.expected.buildOutputs)) { Assert-True (Test-Path -LiteralPath (Join-Path $buildPathOne ([string]$output)) -PathType Leaf) ("build publishes " + [string]$output) }
    Assert-True ([IO.File]::ReadAllText((Join-Path $buildPathOne "package.artifact.json")) -ceq [IO.File]::ReadAllText((Join-Path $buildPathTwo "package.artifact.json"))) "Windows and CI roots emit byte-identical package artifacts"
    Assert-True ([IO.File]::ReadAllText((Join-Path $buildPathOne "build-report.json")) -ceq [IO.File]::ReadAllText((Join-Path $buildPathTwo "build-report.json"))) "Windows and CI roots emit byte-identical build reports"
    Assert-True ([IO.File]::ReadAllText((Join-Path $buildPathOne "compiler-manifest.json")) -ceq [IO.File]::ReadAllText((Join-Path $buildPathTwo "compiler-manifest.json"))) "Windows and CI roots emit byte-identical Compiler manifests"
    $artifact = Read-Document (Join-Path $buildPathOne "package.artifact.json")
    Assert-True ([string]$artifact.schema -eq "cm2.package-artifact/1" -and [string]$artifact.manifest.entrypoints.runtime -eq "data-only" -and $null -eq $artifact.manifest.entrypoints.lua) "built package is a real data-only artifact"
    Assert-True (@(Get-ChildItem -LiteralPath $buildPathOne -Recurse -File -Filter "*.lua").Count -eq 0) "published package contains no Runtime Lua or Compiler catalog Lua"
    Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $buildPathOne "package.artifact.json")).Hash.ToLowerInvariant() -eq [string]$buildOne.json.fingerprint) "package fingerprint matches exact artifact bytes"

    $beforeSecondBuild = [IO.File]::ReadAllText((Join-Path $buildPathOne "package.artifact.json"))
    $repeatBuild = Invoke-Sdk "build" $projectOne
    Assert-True ($repeatBuild.code -eq 0 -and (Test-Path -LiteralPath ($buildPathOne + ".previous") -PathType Container)) "repeat build preserves the prior valid directory"
    Assert-True ([IO.File]::ReadAllText((Join-Path ($buildPathOne + ".previous") "package.artifact.json")) -ceq $beforeSecondBuild) "rollback directory preserves exact prior artifact bytes"

    $explain = Invoke-Sdk "explain" $projectOne
    Assert-True ($explain.code -eq 0 -and [bool]$explain.json.compatibility.coreApi.compatible -and [bool]$explain.json.compatibility.sdk.compatible) "explain reports compatible Core and SDK ranges"
    Assert-True ([string]$explain.json.coreOnlyFallback.policy -eq "builtin-only") "explain reports explicit Core-only fallback"
    $preview = Invoke-Sdk "preview" $projectOne
    Assert-True ($preview.code -eq 0 -and -not [bool]$preview.json.runtimeRequired) "headless preview does not require Teardown or Editor"
    $test = Invoke-Sdk "test" $projectOne
    Assert-True ($test.code -eq 0 -and [string]$test.json.compilerHash -eq [string]$buildOne.json.compilerCatalogHash) "test composes package, Compiler and preview contracts"
    $package = Invoke-Sdk "package" $projectOne
    Assert-True ($package.code -eq 0 -and (Test-Path -LiteralPath (Join-Path $projectOne ".cm2-sdk\package\package.artifact.json") -PathType Leaf)) "package publishes an installable artifact"
    $migrate = Invoke-Sdk "migrate" $projectOne
    Assert-True ($migrate.code -eq 0 -and (Test-Path -LiteralPath (Join-Path $projectOne ".cm2-sdk\migrated\manifest.migrated.json") -PathType Leaf)) "migrate records explicit schema provenance"
    $doctor = Invoke-Sdk "doctor" $projectOne
    Assert-True ($doctor.code -eq 0 -and [bool]$doctor.json.compiler -and [bool]$doctor.json.schema -and [bool]$doctor.json.dataOnlyCommandsAvailable) "doctor proves CLI availability without Editor coupling"
    Assert-True ($null -ne $doctor.json.PSObject.Properties["teardownRunning"] -and $null -ne $doctor.json.PSObject.Properties["teardownProcessCount"]) "doctor distinguishes live Teardown process state"

    $sourcePath = Join-Path $projectOne "package.source.json"
    $validSourceText = [IO.File]::ReadAllText($sourcePath)
    $lastValidArtifact = [IO.File]::ReadAllText((Join-Path $buildPathOne "package.artifact.json"))

    $invalid = Read-Document $sourcePath; $invalid.manifest.entrypoints.lua = "script/runtime.lua"; Write-Document $sourcePath $invalid
    Assert-Error (Invoke-Sdk "build" $projectOne) "validate-failed" "Runtime Lua manifest"
    Assert-True ([IO.File]::ReadAllText((Join-Path $buildPathOne "package.artifact.json")) -ceq $lastValidArtifact) "failed manifest build preserves last valid artifact"
    [IO.File]::WriteAllText($sourcePath, $validSourceText, $utf8)

    $invalid = Read-Document $sourcePath; $invalid.manifest.coreApiVersionRange = ">=2.0.0 <3.0.0"; Write-Document $sourcePath $invalid
    Assert-Error (Invoke-Sdk "validate" $projectOne) "validate-failed" "incompatible Core API range"
    [IO.File]::WriteAllText($sourcePath, $validSourceText, $utf8)

    $invalid = Read-Document $sourcePath; $invalid.manifest.capabilities += "ExecuteLua"; Write-Document $sourcePath $invalid
    Assert-Error (Invoke-Sdk "validate" $projectOne) "validate-failed" "unknown capability"
    [IO.File]::WriteAllText($sourcePath, $validSourceText, $utf8)

    $effectPath = Join-Path $projectOne "definitions\effect\pulse.json"
    $validEffectText = [IO.File]::ReadAllText($effectPath)
    $invalidEffect = Read-Document $effectPath; $invalidEffect.editor.displayName = "Content Mod 2 private path"; Write-Document $effectPath $invalidEffect
    Assert-Error (Invoke-Sdk "validate" $projectOne) "private-reference" "private Runtime reference"
    [IO.File]::WriteAllText($effectPath, $validEffectText, $utf8)

    $invalidEffect = Read-Document $effectPath; $invalidEffect.runtime.priority = 101; Write-Document $effectPath $invalidEffect
    $compileFailure = Invoke-Sdk "build" $projectOne
    Assert-Error $compileFailure "compile-failed" "invalid Definition Compiler range"
    Assert-True ([string]$compileFailure.json.definitionId -eq "cm2.creator.hello-ship:effect.pulse" -and [string]$compileFailure.json.fieldPath -eq "runtime.priority" -and [string]$compileFailure.json.suggestion -ne "") "Compiler failure identifies definition, field, and repair suggestion"
    Assert-True ([IO.File]::ReadAllText((Join-Path $buildPathOne "package.artifact.json")) -ceq $lastValidArtifact) "failed Compiler build preserves last valid artifact"
    [IO.File]::WriteAllText($effectPath, $validEffectText, $utf8)

    $lockPath = Join-Path $projectOne "sdk.tool-lock.json"
    $validLockText = [IO.File]::ReadAllText($lockPath)
    $invalidLock = Read-Document $lockPath; $invalidLock.tools[0].version = "9.9.9"; Write-Document $lockPath $invalidLock
    Assert-Error (Invoke-Sdk "validate" $projectOne) "tool-version" "tool lock mismatch"
    [IO.File]::WriteAllText($lockPath, $validLockText, $utf8)

    [IO.File]::AppendAllText((Join-Path $buildPathOne "build-report.json"), "drift", $utf8)
    Assert-Error (Invoke-Sdk "build" $projectOne) "generated-drift" "generated build drift"

    Assert-Error (Invoke-Sdk "clean" $projectTwo $tempRoot) "unsafe-clean" "unsafe clean outside project SDK root"
    Assert-True ((Invoke-Sdk "clean" $projectTwo (Join-Path $projectTwo ".cm2-sdk\package")).code -eq 0) "clean removes an approved SDK-owned package leaf"
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $projectTwo ".cm2-sdk\package"))) "clean removes only the requested SDK-owned leaf"
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ("Creator SDK CLI Alpha self-test passed: " + $script:assertions + " assertions.") -ForegroundColor Green
exit 0
