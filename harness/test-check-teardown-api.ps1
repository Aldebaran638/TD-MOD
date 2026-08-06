# Self-test for check-teardown-api.ps1.

param([string]$LuaExecutable = "", [switch]$KeepFixtures)

$checker = Join-Path $PSScriptRoot "check-teardown-api.ps1"
$root = Join-Path $PSScriptRoot (".teardown-api-check-test-" + [Guid]::NewGuid().ToString("N"))
$engineRoot = Join-Path $root "engine-data"
$project = Join-Path $root "project"
$encoding = New-Object Text.UTF8Encoding($false)
$powershellExe = (Get-Process -Id $PID).Path
$failures = 0

function Assert-True { param([bool]$Condition, [string]$Message); if ($Condition) { Write-Host "[PASS] $Message" -ForegroundColor Green } else { Write-Host "[FAIL] $Message" -ForegroundColor Red; $script:failures++ } }
function Write-Text { param([string]$Path, [string]$Text); [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null; [IO.File]::WriteAllText($Path, $Text, $encoding) }
function Invoke-Checker { $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $checker, "-Path", $project, "-TeardownDataPath", $engineRoot); if ($LuaExecutable -ne "") { $args += @("-LuaExecutable", $LuaExecutable) }; $output = & $powershellExe @args 2>&1; return @{ ExitCode = $LASTEXITCODE; Text = ($output -join "`n") } }

try {
    Write-Text (Join-Path $engineRoot "script_defs.lua") @'
---@param pos table
---@param size number
function Explosion(pos, size) end
function Vec(x, y, z) return {} end
'@
    Write-Text (Join-Path $engineRoot "td_vscode_plugin.lua") "function OnSetText(uri, text) return nil end`r`n"
    Write-Text (Join-Path $project "main.lua") 'Explosion(Vec(0, 0, 0), 1)'
    $valid = Invoke-Checker
    Assert-True ($valid.ExitCode -eq 0) "accepts valid Teardown API calls"
    Write-Text (Join-Path $project "invalid.lua") 'MissingTeardownApi(); Explosion(Vec(0, 0, 0))'
    $invalid = Invoke-Checker
    Assert-True ($invalid.ExitCode -eq 1) "rejects invalid Teardown API calls"
    Assert-True ($invalid.Text -match 'MissingTeardownApi|missing-parameter') "reports API symbol or argument violations"
}
finally { if ($KeepFixtures) { Write-Host "Fixtures kept at: $root" } elseif (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force } }

if ($failures -gt 0) { exit 1 }
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
