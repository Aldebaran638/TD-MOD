# Self-tests for semantic snapshot generation and field-level comparison.

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$builder = Join-Path $repositoryRoot "tools\cm2-snapshot\build-semantic-snapshot.ps1"
$comparer = Join-Path $repositoryRoot "tools\cm2-snapshot\compare-semantic-snapshot.ps1"
$modPath = Join-Path $repositoryRoot "Content Mod 2"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("semantic-snapshot-fixtures-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

function Run-Build([string]$output, [string]$hash) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $builder -Path $modPath -OutputPath $output -HashPath $hash 2>$null | Out-String | Out-Null
    return $LASTEXITCODE
}

try {
    $one = Join-Path $tempRoot "one.json"; $oneHash = Join-Path $tempRoot "one.sha256"
    $two = Join-Path $tempRoot "two.json"; $twoHash = Join-Path $tempRoot "two.sha256"
    if ((Run-Build $one $oneHash) -ne 0 -or (Run-Build $two $twoHash) -ne 0) { throw "semantic snapshot build failed" }
    $oneBytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($one)); $twoBytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($two))
    if ($oneBytes -cne $twoBytes) { throw "repeated snapshot builds are not byte-identical" }
    $snapshot = Get-Content -Raw -LiteralPath $one | ConvertFrom-Json
    if ($snapshot.weaponCount -ne 109 -or $snapshot.vehicleCount -ne 5) { throw "snapshot count is not 109 weapons / 5 vehicles" }
    if (@($snapshot.weapons).Count -ne 109 -or @($snapshot.vehicles).Count -ne 5) { throw "snapshot arrays do not match counts" }
    if (@($snapshot.weapons.id | Group-Object | Where-Object Count -gt 1).Count -gt 0) { throw "weapon IDs are not unique" }
    $titan = @($snapshot.vehicles | Where-Object id -eq "titan")[0]
    if ($null -eq $titan -or $titan.mountCount -ne 18 -or $null -eq $titan.normalizedMounts[0].direction) { throw "Titan normalized mount golden data is incomplete" }
    foreach ($field in @("fallbackExpressions", "implicitDefaultExpressions", "nonUnitDirectionFields", "magicOffsetFields")) {
        if ($null -eq $snapshot.observations.PSObject.Properties[$field]) { throw "snapshot observation missing $field" }
    }
    $hashText = (Get-Content -Raw -LiteralPath $oneHash).Trim().Split(' ')[0]
    $actualHash = [Security.Cryptography.SHA256]::Create()
    try { $actualHash = (($actualHash.ComputeHash([IO.File]::ReadAllBytes($one)) | ForEach-Object { $_.ToString('x2') }) -join '') }
    finally { if ($actualHash -is [IDisposable]) { $actualHash.Dispose() } }
    if ($hashText -cne $actualHash) { throw "snapshot hash file does not match bytes" }
    Write-Host "[PASS] 109/5 snapshot, normalized mount data, observations, and hash are stable"

    $candidate = Join-Path $tempRoot "candidate.json"
    $mutated = Get-Content -Raw -LiteralPath $one | ConvertFrom-Json
    $weapon = @($mutated.weapons | Where-Object id -eq "mediumAutocannon")[0]
    $weapon.damageMax = "999999"
    $mutated | ConvertTo-Json -Depth 30 -Compress | Set-Content -LiteralPath $candidate -Encoding utf8
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $comparer -BaselinePath $one -CandidatePath $candidate 2>&1 | Out-String | Set-Variable compareOutput
    if ($LASTEXITCODE -eq 0 -or $compareOutput -notmatch 'weapons\[mediumAutocannon\]\.damageMax') { throw "field-level snapshot diff did not identify changed ID/field" }
    Write-Host "[PASS] snapshot comparison reports concrete ID/field diff"

    Write-Host "Self-test passed." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
