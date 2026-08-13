$ErrorActionPreference = "Stop"
$checker = Join-Path $PSScriptRoot "check-vehicle-component-catalog.ps1"
& $checker -Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ($LASTEXITCODE -ne 0) { throw "vehicle/component catalog checker rejected the generated candidate" }
$data = Get-Content -Raw (Join-Path $PSScriptRoot "..\docs\generated\cm2-vehicle-definitions-v1.json") | ConvertFrom-Json
if (@($data.vehicles).Count -ne 5 -or @($data.parts).Count -ne 5 -or @($data.mounts).Count -lt 32 -or @($data.components).Count -lt 26 -or @($data.interceptors).Count -ne 3) { throw "catalog counts do not cover the five-vehicle migration" }
if (@($data.vehicles | Where-Object {$_.runtime.flight.coordinateFrame -notmatch "parent-local"}).Count -ne 0) { throw "vehicle coordinate frame is not explicit" }
if (@($data.mounts | Where-Object {$_.localTransform.space -ne "parent-local"}).Count -ne 0) { throw "mount coordinate fixture is not parent-local" }
if (@($data.interceptors | Where-Object {$_.runtime.budget.maxActive -le 0}).Count -ne 0) { throw "interceptor budget fixture is missing" }
Write-Host "[PASS] five Vehicle records, normalized mounts/components, target filters and interceptor budgets are covered"
Write-Host "[PASS] deterministic candidate output, canonical references and legacy-safe ownership gates are present"
Write-Host "Self-test passed."
exit 0
