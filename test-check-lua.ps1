# Self-test for check-lua.ps1

param(
    [string]$LuaExecutable = "",
    [switch]$KeepFixtures
)

$checker = Join-Path $PSScriptRoot "check-lua.ps1"
$fixtureRoot = Join-Path $PSScriptRoot (".lua-check-test-" + [Guid]::NewGuid().ToString("N"))
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$powershellExe = (Get-Process -Id $PID).Path
$failures = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        Write-Host "[PASS] $Message" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] $Message" -ForegroundColor Red
        $script:failures++
    }
}

function Write-Fixture {
    param([string]$RelativePath, [string]$Content)
    $fullPath = Join-Path $fixtureRoot $RelativePath
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $fullPath)) | Out-Null
    [System.IO.File]::WriteAllText($fullPath, $Content, $utf8NoBom)
}

function Invoke-Checker {
    $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $checker, "-Path", $fixtureRoot)
    if ($LuaExecutable -ne "") {
        $arguments += @("-LuaExecutable", $LuaExecutable)
    }
    $output = & $powershellExe @arguments 2>&1
    return @{ ExitCode = $LASTEXITCODE; Text = ($output | Out-String) }
}

try {
    [System.IO.Directory]::CreateDirectory($fixtureRoot) | Out-Null
    Write-Fixture "main.lua" "#version 2`r`n#include `"script/include/common.lua`"`r`n#include `"modules/good.lua`"`r`nlocal mainValue = true`r`n"
    Write-Fixture "modules/good.lua" "local good = true`r`nreturn good`r`n"
    Write-Fixture "missing.lua" "#include `"modules/not-found.lua`"`r`n"
    Write-Fixture "escape.lua" "#include `"../outside.lua`"`r`n"
    Write-Fixture "malformed-include.lua" "#include modules/good.lua`r`n"
    Write-Fixture "cycle-a.lua" "#include `"cycle-b.lua`"`r`n"
    Write-Fixture "cycle-b.lua" "#include `"cycle-a.lua`"`r`n"
    Write-Fixture "syntax-error.lua" "local broken = (`r`n"

    Write-Host "Fixtures: $fixtureRoot" -ForegroundColor Cyan
    $first = Invoke-Checker
    Write-Host $first.Text
    Assert-True ($first.ExitCode -eq 1) "invalid fixture set exits with code 1"
    Assert-True ($first.Text.Contains("missing: modules/not-found.lua")) "detects missing include"
    Assert-True ($first.Text.Contains("escapes check root: ../outside.lua")) "detects include escaping the checked script root"
    Assert-True ($first.Text.Contains("malformed directive")) "detects malformed include directive"
    Assert-True ($first.Text.Contains("[INCLUDE CYCLE]")) "detects include cycle"
    Assert-True ($first.Text.Contains("syntax-error.lua")) "detects Lua syntax error"
    Assert-True (-not $first.Text.Contains("missing: script/include/common.lua")) "accepts Teardown engine include"

    Remove-Item -LiteralPath (Join-Path $fixtureRoot "missing.lua") -Force
    Remove-Item -LiteralPath (Join-Path $fixtureRoot "escape.lua") -Force
    Remove-Item -LiteralPath (Join-Path $fixtureRoot "malformed-include.lua") -Force
    Remove-Item -LiteralPath (Join-Path $fixtureRoot "cycle-a.lua") -Force
    Remove-Item -LiteralPath (Join-Path $fixtureRoot "cycle-b.lua") -Force
    Remove-Item -LiteralPath (Join-Path $fixtureRoot "syntax-error.lua") -Force

    $second = Invoke-Checker
    Write-Host $second.Text
    Assert-True ($second.ExitCode -eq 0) "valid fixture set exits with code 0"
}
finally {
    if ($KeepFixtures) {
        Write-Host "Fixtures kept at: $fixtureRoot" -ForegroundColor Yellow
    }
    elseif (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

if ($failures -gt 0) {
    Write-Host "Self-test failed: $failures assertion(s) failed." -ForegroundColor Red
    exit 1
}

Write-Host "Self-test passed." -ForegroundColor Green
exit 0
