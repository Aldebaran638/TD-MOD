# Self-test for check-lua.ps1

param(
    [string]$LuaExecutable = "",
    [switch]$KeepFixtures
)

$checker = Join-Path $PSScriptRoot "check-lua.ps1"
$fixtureBase = Join-Path $PSScriptRoot (".lua-check-test-" + [Guid]::NewGuid().ToString("N"))
$fixtureRoot = Join-Path $fixtureBase "project"
$engineRoot = Join-Path $fixtureBase "engine-data"
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

function Write-EngineFixture {
    param([string]$RelativePath, [string]$Content)
    $fullPath = Join-Path $engineRoot $RelativePath
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $fullPath)) | Out-Null
    [System.IO.File]::WriteAllText($fullPath, $Content, $utf8NoBom)
}

function Invoke-Checker {
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $checker,
        "-Path", $fixtureRoot,
        "-TeardownDataPath", $engineRoot
    )
    if ($LuaExecutable -ne "") {
        $arguments += @("-LuaExecutable", $LuaExecutable)
    }
    $output = & $powershellExe @arguments 2>&1
    return @{ ExitCode = $LASTEXITCODE; Text = ($output | Out-String) }
}

try {
    [System.IO.Directory]::CreateDirectory($fixtureRoot) | Out-Null
    Write-EngineFixture "script_defs.lua" @'
---@class TVec

server = {}
client = {}
shared = {}

---@param x? number
---@param y? number
---@param z? number
---@return TVec
function Vec(x, y, z) return {} end

---@param pos TVec
---@param size number
function Explosion(pos, size) end

---@param pos TVec
---@param r number
---@param g number
---@param b number
---@param intensity? number
function PointLight(pos, r, g, b, intensity) end
'@
    Write-EngineFixture "td_vscode_plugin.lua" "function OnSetText(uri, text) return nil end`r`n"
    Write-EngineFixture "script/include/common.lua" "math.clamp = math.clamp or function(value, minimum, maximum) return value end`r`n"

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

    Write-Fixture "semantic-errors.lua" "#include `"modules/visible.lua`"`r`nvisibleFn()`r`nhiddenFn()`r`nPointLight(Vec(0, 0, 0), 1, 1)`r`nPointLight(Vec(0, 0, 0), `"bad`", 1, 1)`r`nPointLight(Vec(0, 0, 0), 1, 1, 1, 1, 2)`r`nPointLigth(Vec(0, 0, 0), 1, 1, 1)`r`n"
    Write-Fixture "modules/visible.lua" "function visibleFn() end`r`n"
    Write-Fixture "hidden-definition.lua" "function hiddenFn() end`r`n"

    $third = Invoke-Checker
    Write-Host $third.Text
    Assert-True ($third.ExitCode -eq 1) "semantic fixture set exits with code 1"
    Assert-True ($third.Text.Contains("hiddenFn")) "checks symbols against the entry include closure"
    Assert-True ($third.Text.Contains("PointLigth")) "detects missing official API declarations"
    Assert-True ($third.Text.Contains("missing-parameter")) "detects missing official API arguments"
    Assert-True ($third.Text.Contains("redundant-parameter")) "detects redundant official API arguments"
    Assert-True ($third.Text.Contains("param-type-mismatch")) "detects incorrect official API argument types"

    Remove-Item -LiteralPath (Join-Path $fixtureRoot "semantic-errors.lua") -Force
    Remove-Item -LiteralPath (Join-Path $fixtureRoot "hidden-definition.lua") -Force

    $fourth = Invoke-Checker
    Write-Host $fourth.Text
    Assert-True ($fourth.ExitCode -eq 0) "semantic-clean fixture set exits with code 0"
}
finally {
    if ($KeepFixtures) {
        Write-Host "Fixtures kept at: $fixtureBase" -ForegroundColor Yellow
    }
    elseif (Test-Path -LiteralPath $fixtureBase) {
        Remove-Item -LiteralPath $fixtureBase -Recurse -Force
    }
}

if ($failures -gt 0) {
    Write-Host "Self-test failed: $failures assertion(s) failed." -ForegroundColor Red
    exit 1
}

Write-Host "Self-test passed." -ForegroundColor Green
exit 0
