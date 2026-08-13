# Validate the init-only candidate shadow gate and its current comparison report.

param([string]$Path = ".")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $Path).Path
$shadowLua = Join-Path $root "Content Mod 2\script\data\candidate_catalog_shadow.lua"
$compare = Join-Path $root "tools\cm2-shadow\compare-shadow.ps1"
$candidateRoot = Join-Path $root "docs\candidates\generated"
$issues = New-Object System.Collections.Generic.List[string]
foreach ($file in @($shadowLua, $compare, (Join-Path $root "docs\candidates\shadow-map.json"))) { if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { $issues.Add("missing shadow artifact: $file") } }
if ($issues.Count -eq 0) {
    $source = Get-Content -Raw -LiteralPath $shadowLua
    foreach ($symbol in @("init", "getSource", "isFrozen", "recordDifference", "getDiagnostics")) { if ($source -notmatch "function shadow\.$symbol\b") { $issues.Add("missing shadow API: $symbol") } }
    if ($source -notmatch 'shadow\.initialized\s+then\s+return false') { $issues.Add("shadow init is not single-shot") }
    if ($source -match 'function shadow\.(update|tick|render)') { $issues.Add("shadow comparison must not run in hot tick") }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $compare -RepositoryRoot $root -DefinitionSource legacy -CandidateRoot $candidateRoot -ReportPath (Join-Path $candidateRoot "shadow-report.json")
    if ($LASTEXITCODE -ne 0) { $issues.Add("legacy shadow comparison reported unexplained differences") }
}
if ($issues.Count -gt 0) { Write-Error ("Shadow catalog check failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "Shadow catalog contract passed: init-only, legacy-safe, four-slice comparison clean." -ForegroundColor Green
exit 0
