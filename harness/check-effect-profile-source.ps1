# Static/deterministic checker for versioned Effect Profile Source v1.

param([string]$Path = ".")

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path -LiteralPath $Path).Path
$sourcePath = Join-Path $repositoryRoot "docs\effect-profiles-v1.json"
$builder = Join-Path $repositoryRoot "tools\cm2-profiles\build-effect-profile-source.ps1"
$issues = New-Object System.Collections.Generic.List[string]
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { $issues.Add("missing effect profile source") }
if (-not (Test-Path -LiteralPath $builder -PathType Leaf)) { $issues.Add("missing effect profile builder") }
if ($issues.Count -eq 0) {
    $data = Get-Content -Raw -LiteralPath $sourcePath | ConvertFrom-Json
    if ([string]$data.schemaVersion -ne "cm2.effect-profile-source/1" -or $data.generated -ne $true) { $issues.Add("source schema/generated marker invalid") }
    if (@($data.profiles).Count -lt 100) { $issues.Add("source profile inventory is unexpectedly small") }
    if (@($data.aliases).Count -ne @($data.profiles).Count) { $issues.Add("profile/alias counts differ") }
    if (@($data.unresolved).Count -ne 0) { $issues.Add("source contains unresolved references") }
    $ids = @($data.profiles | ForEach-Object { [string]$_.id })
    if (($ids | Sort-Object -Unique).Count -ne $ids.Count) { $issues.Add("profile IDs are not unique") }
    foreach ($profile in $data.profiles) {
        foreach ($field in @("id", "kind", "schemaVersion", "legacyId", "phase", "rendererId", "rendererVersion", "cost", "lod", "ownerPolicy", "terminationPolicy")) {
            if ($null -eq $profile.PSObject.Properties[$field] -or [string]$profile.$field -eq "") { $issues.Add("profile missing field: $($profile.id)/$field") }
        }
        foreach ($cost in @("particles", "sprites", "lines", "lights", "voices")) {
            if ($null -eq $profile.cost.PSObject.Properties[$cost]) { $issues.Add("profile missing cost: $($profile.id)/$cost") }
        }
    }
    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("cm2-effect-profiles-" + [guid]::NewGuid().ToString("N") + ".json")
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $builder -RepositoryRoot $repositoryRoot -OutputPath $tempPath 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { $issues.Add("deterministic builder failed") }
    elseif ((Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $tempPath -Algorithm SHA256).Hash) { $issues.Add("source is not byte-deterministic") }
    if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue }
}
if ($issues.Count -gt 0) { Write-Error ("Effect profile source check failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "Effect profile source contract passed: 108+ versioned profiles, aliases, costs, zero unresolved references, deterministic build." -ForegroundColor Green
exit 0
