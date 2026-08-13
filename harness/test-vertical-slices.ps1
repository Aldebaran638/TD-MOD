# Self-test for the four Compiler MVP vertical slices.

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$builder = Join-Path $repositoryRoot "tools\cm2-slices\build-vertical-slices.ps1"
$ownership = Join-Path $repositoryRoot "docs\candidates\ownership-map.json"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-vertical-slices-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

function Run-Build([string]$outputRoot) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $builder -RepositoryRoot $repositoryRoot -OwnershipPath $ownership -OutputRoot $outputRoot 2>$null | Out-String | Out-Null
    return $LASTEXITCODE
}

try {
    $one = Join-Path $tempRoot "one"; $two = Join-Path $tempRoot "two"
    if ((Run-Build $one) -ne 0 -or (Run-Build $two) -ne 0) { throw "vertical slice build failed" }
    $report = Get-Content -Raw -LiteralPath (Join-Path $one "vertical-slices-report.json") | ConvertFrom-Json
    if (@($report.slices).Count -ne 4) { throw "vertical slice report does not contain four slices" }
    $expectedNames = @("guided-missile", "logical-projectile-impact", "ray-beam", "tachyon-charge-beam-impact")
    if ((@($report.slices.name) | Sort-Object) -join "," -ne ($expectedNames -join ",")) { throw "vertical slice names are incomplete" }
    foreach ($slice in @($report.slices)) {
        $catalogOne = Join-Path (Join-Path $one $slice.name) "catalog.lua"
        $catalogTwo = Join-Path (Join-Path $two $slice.name) "catalog.lua"
        if (-not (Test-Path -LiteralPath $catalogOne) -or -not (Test-Path -LiteralPath $catalogTwo)) { throw "candidate catalog missing: $($slice.name)" }
        $bytesOne = [Convert]::ToBase64String([IO.File]::ReadAllBytes($catalogOne)); $bytesTwo = [Convert]::ToBase64String([IO.File]::ReadAllBytes($catalogTwo))
        if ($bytesOne -cne $bytesTwo) { throw "candidate catalog is not deterministic: $($slice.name)" }
        if ((Get-Content -Raw -LiteralPath $catalogOne) -notmatch '^-- CM2 GENERATED FILE; DO NOT EDIT\.') { throw "candidate header missing: $($slice.name)" }
    }
    $allIds = @($report.slices | ForEach-Object { $_.ids })
    if (@($allIds | Group-Object | Where-Object Count -gt 1).Count -gt 0) { throw "ownership map contains duplicate IDs" }
    Write-Host "[PASS] four vertical slices compile deterministically with explicit ownership"

    $brokenOwnership = Join-Path $tempRoot "broken-ownership.json"
    $broken = Get-Content -Raw -LiteralPath $ownership | ConvertFrom-Json
    $broken.slices[0].ownership = "silent-overwrite"
    $broken | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $brokenOwnership -Encoding utf8
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $builder -RepositoryRoot $repositoryRoot -OwnershipPath $brokenOwnership -OutputRoot (Join-Path $tempRoot "broken") 2>$null | Out-String | Out-Null
        $brokenExitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }
    if ($brokenExitCode -eq 0) { throw "implicit ownership policy was accepted" }
    Write-Host "[PASS] rejects missing explicit generated/legacy ownership"

    Write-Host "Self-test passed." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
