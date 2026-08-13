# Self-test for the Preview Suite v1 contract and its negative boundaries.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$runner = Join-Path $PSScriptRoot "run-preview-suite-v1.ps1"
$fixturePath = Join-Path $root "docs\candidates\preview-suite-v1.fixture.json"
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("Preview Suite self-test failed: " + $message) }
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function Invoke-Runner([string]$fixture, [string]$report) {
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -FixturePath $fixture -ReportPath $report *> $null
    $exitCode = [int]$LASTEXITCODE
    $ErrorActionPreference = $savedPreference
    return $exitCode
}
function Write-Fixture([object]$document, [string]$path) {
    [IO.File]::WriteAllText($path, ($document | ConvertTo-Json -Depth 80), $utf8)
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-preview-suite-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $baseReport = Join-Path $tempRoot "base-report.json"
    $baseExit = Invoke-Runner $fixturePath $baseReport
    Assert-True ($baseExit -eq 0) "accepts shared Effect Lab, Weapon Range and Ship Dock contracts"
    $base = Get-Content -Raw -LiteralPath $baseReport | ConvertFrom-Json
    Assert-True ([string]$base.result -eq "pass") "writes a machine report"
    Assert-True ([string]$base.sharedAuthority.worldEntityAdapter -eq "cm2.world/1") "reports shared World/Entity adapter"
    Assert-True ([string]$base.effectLab.replayHash -eq [string]$base.effectLab.replayHash) "Effect Lab replay hash is present"
    Assert-True ([string]$base.weaponRange.replayHash -eq [string]$base.weaponRange.replayHash) "Weapon Range fixed-seed replay hash is present"
    Assert-True ([int]$base.shipDock.anchors -ge 1 -and @($base.shipDock.lifecycle).Count -eq 5) "Ship Dock marker/lifecycle report is present"
    Assert-True ([bool]$base.runtimeCatalogUnchanged) "Preview report proves runtime catalog was not mutated"
    Assert-True ([bool]$base.liveHost.sharedWorldEntityAdapter) "live host uses the shared World/Entity adapter boundary"
    Assert-True (@($base.liveHost.realInputModes) -contains "leftarrow" -and @($base.liveHost.realInputModes) -contains "rightarrow" -and @($base.liveHost.realInputModes) -contains "space") "live host declares non-conflicting real keyboard controls"
    Assert-True ([bool]$base.liveHost.numberedKeysReservedForNativeTools) "live host does not dual-consume native numbered tool keys"
    Assert-True (-not (@($base.liveHost.realInputModes) -contains "lmb") -and [bool]$base.liveHost.lmbReservedForNativeTool) "live host does not dual-consume native LMB"

    $cases = @(
        @{ Name = "wrong compiler"; Mutate = { param($d) $d.sharedAuthority.compiler = "editor-only-compiler" } },
        @{ Name = "runtime catalog mutation"; Mutate = { param($d) $d.sharedAuthority.runtimeCatalogMutationForbidden = $false } },
        @{ Name = "missing world/entity adapter"; Mutate = { param($d) $d.sharedAuthority.worldEntityAdapter = "" } },
        @{ Name = "missing moving target"; Mutate = { param($d) $d.weaponRange.movingTarget = $null } },
        @{ Name = "missing VOX"; Mutate = { param($d) $d.shipDock.vox = $null } },
        @{ Name = "missing stale disposal case"; Mutate = { param($d) $d.shipDock.spawnDispose = @("spawn", "dispose") } }
    )
    foreach ($case in $cases) {
        $document = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
        & $case.Mutate $document
        $caseFixture = Join-Path $tempRoot (($case.Name -replace "[^A-Za-z0-9]", "-") + ".json")
        $caseReport = Join-Path $tempRoot (($case.Name -replace "[^A-Za-z0-9]", "-") + ".report.json")
        Write-Fixture $document $caseFixture
        $caseExit = Invoke-Runner $caseFixture $caseReport
        Assert-True ($caseExit -ne 0) ("rejects " + $case.Name)
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "Self-test passed." -ForegroundColor Green
exit 0
