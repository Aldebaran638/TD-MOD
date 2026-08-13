# Independent Consumer regression for compatibility negotiation and rollback.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$installer = Join-Path $PSScriptRoot "install-compatibility-consumer-v1.ps1"
$build = Join-Path $root "testing\fixtures\creator_sdk\alpha_project\.cm2-sdk\package"
$hostSource = Join-Path $root "_AI Test Consumer Compatibility V1\script\testing\compatibility\consumer_host.lua"
$script:assertions = 0

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("Compatibility Consumer self-test failed: " + $message) }
    $script:assertions++
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function New-Consumer([string]$path) {
    New-Item -ItemType Directory -Path (Join-Path $path "script\testing\compatibility") -Force | Out-Null
    Copy-Item -LiteralPath $hostSource -Destination (Join-Path $path "script\testing\compatibility\consumer_host.lua")
}
function Invoke-Install([string]$consumer, [string]$trace, [string]$core = "1.2.0") {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer -BuildPath $build -ConsumerRoot $consumer -TracePath $trace -CoreApiVersion $core *> $null
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    return $code
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-compat-consumer-test-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $consumerOne = Join-Path $tempRoot "consumer-one"
    $consumerTwo = Join-Path $tempRoot "consumer-two"
    New-Consumer $consumerOne
    New-Consumer $consumerTwo
    $traceOne = Join-Path $tempRoot "one.trace.json"
    $traceTwo = Join-Path $tempRoot "two.trace.json"
    Assert-True ((Invoke-Install $consumerOne $traceOne) -eq 0) "compatible package installs into first clean-room Consumer"
    Assert-True ((Invoke-Install $consumerTwo $traceTwo) -eq 0) "compatible package installs into second clean-room Consumer"
    $one = Get-Content -Raw -LiteralPath $traceOne | ConvertFrom-Json
    $two = Get-Content -Raw -LiteralPath $traceTwo | ConvertFrom-Json
    Assert-True ([string]$one.packageArtifactHash -eq [string]$two.packageArtifactHash -and [string]$one.policyHash -eq [string]$two.policyHash) "independent installs resolve identical package and policy hashes"
    Assert-True ([string]$one.compatibleOperation.result -eq "accepted" -and [string]$one.incompatibleOperation.code -eq "core-policy-version") "Consumer executes one compatible and one rejected compatibility operation"
    Assert-True (-not [bool]$one.runtimeLuaLoaded -and [int]$one.consumerPrivateIncludes -eq 0) "Consumer loads no package Runtime Lua or private CM2 code"
    $installedOne = Join-Path $consumerOne ([string]$one.installedArtifact).Replace("/", "\")
    $installedTwo = Join-Path $consumerTwo ([string]$two.installedArtifact).Replace("/", "\")
    Assert-True ([IO.File]::ReadAllText($installedOne) -ceq [IO.File]::ReadAllText($installedTwo)) "independent Consumer installs are byte-identical"
    $lastValid = [IO.File]::ReadAllText($installedOne)
    $lastTrace = [IO.File]::ReadAllText($traceOne)
    Assert-True ((Invoke-Install $consumerOne $traceOne "2.0.0") -ne 0) "incompatible future Core fails before Consumer install"
    Assert-True ([IO.File]::ReadAllText($installedOne) -ceq $lastValid -and [IO.File]::ReadAllText($traceOne) -ceq $lastTrace) "failed install preserves exact last-valid artifact and trace"
    Assert-True ((Invoke-Install $consumerOne $traceOne) -eq 0) "compatible reinstall succeeds after a rejected downgrade/upgrade selection"
    Assert-True ([IO.File]::ReadAllText($installedOne) -ceq $lastValid) "compatible reinstall restores exact expected bytes"
    Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $consumerOne "packages") -Recurse -File -Filter "*.lua").Count -eq 0) "installed package tree contains no Lua files"
}
finally {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    $systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolved.StartsWith($systemTemp, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolved)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Write-Host ("Compatibility Consumer self-test passed: " + $script:assertions + " assertions.") -ForegroundColor Green
exit 0
