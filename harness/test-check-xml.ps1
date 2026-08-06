# Self-test for check-xml.ps1.

param([switch]$KeepFixtures)

$checker = Join-Path $PSScriptRoot "check-xml.ps1"
$root = Join-Path $PSScriptRoot (".xml-check-test-" + [Guid]::NewGuid().ToString("N"))
$encoding = New-Object Text.UTF8Encoding($false)
$powershellExe = (Get-Process -Id $PID).Path
$failures = 0

function Assert-True { param([bool]$Condition, [string]$Message); if ($Condition) { Write-Host "[PASS] $Message" -ForegroundColor Green } else { Write-Host "[FAIL] $Message" -ForegroundColor Red; $script:failures++ } }
function Write-Fixture { param([string]$Relative, [string]$Text); $path = Join-Path $root $Relative; [IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null; [IO.File]::WriteAllText($path, $Text, $encoding) }
function Invoke-Checker { $output = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $checker -Path $root 2>&1; return @{ ExitCode = $LASTEXITCODE; Text = ($output -join "`n") } }

try {
    Write-Fixture "main.xml" '<scene version="2.0.1"><instance file="MOD/missing.xml"/></scene>'
    Write-Fixture "prefabs/valid.xml" '<prefab version="2.0.0"><group/></prefab>'
    $valid = Invoke-Checker
    Assert-True ($valid.ExitCode -eq 0) "accepts well-formed XML without resource semantics"
    Write-Fixture "prefabs/broken.xml" '<prefab><group></prefab>'
    $invalid = Invoke-Checker
    Assert-True ($invalid.ExitCode -eq 1) "rejects malformed XML"
    Assert-True ($invalid.Text -match "broken.xml") "reports the malformed XML file"
}
finally { if ($KeepFixtures) { Write-Host "Fixtures kept at: $root" } elseif (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force } }

if ($failures -gt 0) { exit 1 }
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
