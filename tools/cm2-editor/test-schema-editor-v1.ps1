# Self-test for Schema Editor v1: form generation, source-only guard,
# deterministic compile, migration/history and invalid-save blocking.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$runner = Join-Path $PSScriptRoot "run-schema-editor-v1.ps1"
$fixturePath = Join-Path $root "docs\candidates\schema-editor-v1.fixture.json"
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("Schema Editor self-test failed: " + $message) }
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function Invoke-Editor([string]$fixture, [string]$report) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -FixturePath $fixture -ReportPath $report *> $null
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    return $code
}
function Write-Fixture([object]$document, [string]$path) { [IO.File]::WriteAllText($path, ($document | ConvertTo-Json -Depth 100), $utf8) }

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-schema-editor-test-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $baseReport = Join-Path $tempRoot "base.report.json"
    Assert-True ((Invoke-Editor $fixturePath $baseReport) -eq 0) "accepts five schema-driven forms and a valid source package"
    $base = Get-Content -Raw -LiteralPath $baseReport | ConvertFrom-Json
    Assert-True ([int]$base.formKinds.Count -eq 5 -and [int]$base.fieldMetadataCount -ge 19) "generates units/ranges/references/budget metadata from one schema"
    Assert-True ([bool]$base.sourceOnly -and [bool]$base.invalidSaveBlocked) "source-only save gate blocks invalid fields"
    Assert-True ([bool]$base.unknownMetadataRoundTrip) "unknown Editor metadata survives migration"
    Assert-True ([bool]$base.compiler.sourceRecompileByteIdentical) "source recompiles byte-identically through shared Compiler"
    Assert-True ([string]$base.compiler.generatedLuaManualEdit -eq "forbidden") "generated Lua remains immutable"
    Assert-True ([string]$base.baselineSourceHash -ne [string]$base.editedSourceHash) "manual diff has distinct source hashes"
    Assert-True ([string]$base.undoHash -eq [string]$base.baselineSourceHash -and [string]$base.redoHash -eq [string]$base.editedSourceHash) "undo/redo restores exact source snapshots"
    Assert-True ([string]$base.runtimeGeneratedCatalogHashBefore -eq [string]$base.runtimeGeneratedCatalogHashAfter) "editor did not mutate Runtime generated catalog"
    Assert-True (-not [bool]$base.liveHost.threeDimensionalView -and [int]$base.liveHost.forms.Count -eq 5) "live host is a non-3D five-form presentation surface"
    Assert-True (-not [bool]$base.liveHost.sourceWriteAuthority -and -not [bool]$base.liveHost.compilerInvokeAuthority -and -not [bool]$base.liveHost.generatedCatalogWriteAuthority -and -not [bool]$base.liveHost.runtimeAuthority) "live host cannot bypass source/compiler/runtime authority"
    Assert-True (@($base.liveHost.realInputs) -contains "return" -and @($base.liveHost.realInputs) -contains "delete" -and @($base.liveHost.realInputs) -contains "backspace") "live host declares real validation, invalid-value, and history controls"

    $cases = @(
        @{ Name = "source-only disabled"; Mutate = { param($d) $d.sourceOnly = $false } },
        @{ Name = "required field missing"; Mutate = { param($d) $weapon = @($d.packageSource.definitions | Where-Object {$_.kind -eq "weapon"})[0]; $weapon.runtime.fireRateHz = $null } },
        @{ Name = "unsafe generated path"; Mutate = { param($d) $weapon = @($d.packageSource.definitions | Where-Object {$_.kind -eq "weapon"})[0]; $weapon.build.sourcePath = "../../Content Mod 2/script/forbidden.lua" } },
        @{ Name = "form kind removed"; Mutate = { param($d) $d.formKinds = @("weapon", "effect") } }
    )
    foreach ($case in $cases) {
        $document = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
        & $case.Mutate $document
        $caseFixture = Join-Path $tempRoot (($case.Name -replace "[^A-Za-z0-9]", "-") + ".json")
        $caseReport = Join-Path $tempRoot (($case.Name -replace "[^A-Za-z0-9]", "-") + ".report.json")
        Write-Fixture $document $caseFixture
        Assert-True ((Invoke-Editor $caseFixture $caseReport) -ne 0) ("rejects " + $case.Name)
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "Self-test passed." -ForegroundColor Green
exit 0
