# Self-test for check-lua.ps1.

param([string]$LuaExecutable = "", [switch]$KeepFixtures)

$checker = Join-Path $PSScriptRoot "check-lua.ps1"
$root = Join-Path $PSScriptRoot (".lua-check-test-" + [Guid]::NewGuid().ToString("N"))
$engineRoot = Join-Path $root "engine-data"
$project = Join-Path $root "project"
$encoding = New-Object Text.UTF8Encoding($false)
$powershellExe = (Get-Process -Id $PID).Path
$failures = 0

function Assert-True { param([bool]$Condition, [string]$Message); if ($Condition) { Write-Host "[PASS] $Message" -ForegroundColor Green } else { Write-Host "[FAIL] $Message" -ForegroundColor Red; $script:failures++ } }
function Write-Fixture { param([string]$Relative, [string]$Text); $path = Join-Path $project $Relative; [IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null; [IO.File]::WriteAllText($path, $Text, $encoding) }
function Write-Engine { param([string]$Relative, [string]$Text); $path = Join-Path $engineRoot $Relative; [IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null; [IO.File]::WriteAllText($path, $Text, $encoding) }
function Invoke-Checker { $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $checker, "-Path", $project, "-TeardownDataPath", $engineRoot); if ($LuaExecutable -ne "") { $args += @("-LuaExecutable", $LuaExecutable) }; $output = & $powershellExe @args 2>&1; return @{ ExitCode = $LASTEXITCODE; Text = ($output -join "`n") } }

try {
    Write-Engine "script_defs.lua" ""
    Write-Engine "script/include/common.lua" ""
    Write-Fixture "main.lua" "#version 2`r`n#include `"script/include/common.lua`"`r`n#include `"modules/good.lua`"`r`nlocal ok = true`r`n"
    Write-Fixture "modules/good.lua" "return true`r`n"
    $valid = Invoke-Checker
    Assert-True ($valid.ExitCode -eq 0) "accepts valid Lua and include closure"
    Write-Fixture "missing.lua" '#include "modules/missing.lua"'
    Write-Fixture "escape.lua" '#include "../outside.lua"'
    Write-Fixture "cycle-a.lua" '#include "cycle-b.lua"'
    Write-Fixture "cycle-b.lua" '#include "cycle-a.lua"'
    Write-Fixture "malformed.lua" '#include modules/good.lua'
    Write-Fixture "syntax-error.lua" 'local broken = ('
    $invalid = Invoke-Checker
    Assert-True ($invalid.ExitCode -eq 1) "rejects invalid Lua/include fixtures"
    Assert-True ($invalid.Text -match 'missing: modules/missing.lua') "detects missing include"
    Assert-True ($invalid.Text -match 'escapes check root') "detects include escape"
    Assert-True ($invalid.Text -match 'INCLUDE CYCLE') "detects include cycle"
    Assert-True ($invalid.Text -match 'malformed directive') "detects malformed include"
    Assert-True ($invalid.Text -match 'syntax-error.lua') "detects Lua syntax error"
}
finally { if ($KeepFixtures) { Write-Host "Fixtures kept at: $root" } elseif (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force } }

if ($failures -gt 0) { exit 1 }
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
