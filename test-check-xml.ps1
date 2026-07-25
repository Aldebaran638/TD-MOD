# Self-test for check-xml.ps1.

param([switch]$KeepFixtures)

$checker = Join-Path $PSScriptRoot "check-xml.ps1"
$fixtureRoot = Join-Path $PSScriptRoot (".xml-check-test-" + [Guid]::NewGuid().ToString("N"))
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$powershellExe = (Get-Process -Id $PID).Path
$failures = 0

function Write-Fixture {
    param([string]$RelativePath, [string]$Content)
    $fullPath = Join-Path $fixtureRoot $RelativePath
    [IO.Directory]::CreateDirectory((Split-Path -Parent $fullPath)) | Out-Null
    [IO.File]::WriteAllText($fullPath, $Content, $utf8NoBom)
}

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

function Invoke-Checker {
    $output = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $checker -Path $fixtureRoot 2>&1
    return @{
        ExitCode = $LASTEXITCODE
        Output = ($output -join "`n")
    }
}

try {
    Write-Fixture "main.xml" @'
<scene version="2.0.1">
  <instance file="MOD/prefabs/ships/enigma_battlecruiser.xml"/>
</scene>
'@
    Write-Fixture "prefabs/ships/enigma_battlecruiser.xml" @'
<script file="MOD/script/shipMain.lua">
  <vehicle tags="stellarisShip"/>
</script>
'@
    Write-Fixture "script/shipMain.lua" @'
#include "muzzle_light.lua"
server.tachyonMuzzleLightInit()
server.tachyonMuzzleLightTick(0)
'@
    Write-Fixture "script/muzzle_light.lua" @'
function server.tachyonMuzzleLightInit()
    FindLight("tachyonMuzzleLight", false)
end
function server.tachyonMuzzleLightTick(dt)
    SetLightIntensity(0, 0)
end
'@

    $invalid = Invoke-Checker
    Assert-True ($invalid.ExitCode -eq 1) "rejects semantically invalid instance target"
    Assert-True ($invalid.Output -match 'root <prefab>') "reports missing prefab root"

    Write-Fixture "prefabs/ships/enigma_battlecruiser.xml" @'
<prefab version="2.0.0">
  <group>
    <script file="MOD/script/shipMain.lua">
      <vehicle tags="stellarisShip">
        <body tags="stellarisShip">
          <light tags="tachyonMuzzleLight"/>
        </body>
        <location name="Player" tags="player"/>
        <location name="exit" tags="exit"/>
      </vehicle>
    </script>
  </group>
</prefab>
'@

    $valid = Invoke-Checker
    Assert-True ($valid.ExitCode -eq 0) "accepts valid battlecruiser prefab contract"
}
finally {
    if ($KeepFixtures) {
        Write-Host "Fixtures kept at: $fixtureRoot"
    }
    elseif (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

if ($failures -gt 0) {
    Write-Host "Self-test failed: $failures assertion(s)." -ForegroundColor Red
    exit 1
}
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
