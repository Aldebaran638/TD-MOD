# Stage the accepted AI candidate as a data-only artifact for an independent
# consumer. This is an explicit test install, not AI publication or Runtime
# registration.

param(
    [string]$ResultPath = "",
    [string]$PolicyPath = "",
    [string]$ApprovalPath = "",
    [string]$ConsumerRoot = "",
    [string]$TracePath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\.." )).Path
if ($ResultPath -eq "") { $ResultPath = Join-Path $root "docs\candidates\ai-weapon-assistant-v1.result.json" }
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\ai-weapon-assistant-v1.json" }
if ($ApprovalPath -eq "") { $ApprovalPath = Join-Path $root "docs\candidates\ai-weapon-assistant-v1.runtime-approval.json" }
if ($ConsumerRoot -eq "") { $ConsumerRoot = Join-Path $root "_AI Test Consumer AI Weapon V1" }
if ($TracePath -eq "") { $TracePath = Join-Path $root "docs\candidates\ai-weapon-assistant-v1.consumer-trace.json" }
$utf8 = New-Object Text.UTF8Encoding($false)

function Canonical([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Require([bool]$condition, [string]$message) { if (-not $condition) { throw ("AI Weapon Consumer install failed: " + $message) } }
function Write-Atomic([string]$path, [string]$text) {
    $full = [IO.Path]::GetFullPath($path)
    $parent = Split-Path -Parent $full
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temp = $full + ".tmp." + [Guid]::NewGuid().ToString("N")
    try { [IO.File]::WriteAllText($temp, $text, $utf8); Move-Item -LiteralPath $temp -Destination $full -Force }
    finally { if (Test-Path -LiteralPath $temp -PathType Leaf) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue } }
}
function Xml-Escape([string]$value) { return [Security.SecurityElement]::Escape($value) }
function Sha256-File([string]$path) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() }

Require (Test-Path -LiteralPath $ResultPath -PathType Leaf) "AI result is missing"
Require (Test-Path -LiteralPath $PolicyPath -PathType Leaf) "AI policy is missing"
Require (Test-Path -LiteralPath $ApprovalPath -PathType Leaf) "runtime approval record is missing"
Require (Test-Path -LiteralPath $ConsumerRoot -PathType Container) "independent Consumer is missing"
$hostPath = Join-Path $ConsumerRoot "script\testing\ai_weapon\consumer_host.lua"
Require (Test-Path -LiteralPath $hostPath -PathType Leaf) "Consumer host is missing"
$hostSource = Get-Content -Raw -LiteralPath $hostPath
foreach ($forbidden in @("Content Mod 2", "Global Mod", "include(", "dofile(", "loadfile(", "ServerCall(")) {
    Require (-not $hostSource.Contains($forbidden)) ("Consumer host contains a private/runtime reference: " + $forbidden)
}
$result = Get-Content -Raw -LiteralPath $ResultPath | ConvertFrom-Json
$policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json
$approval = Get-Content -Raw -LiteralPath $ApprovalPath | ConvertFrom-Json
$candidate = @($result.evaluations | Where-Object { [string]$_.id -eq "pulse" }) | Select-Object -First 1
Require ($null -ne $candidate -and [string]$candidate.decision -eq "accept") "pulse candidate was not accepted"
Require ([string]$candidate.candidateHash -eq [string]$approval.candidateHash) "candidate provenance hash mismatch"
Require ([string]$candidate.finalBuildHash -eq [string]$approval.finalBuildHash) "final compiler hash mismatch"
Require ([string]$approval.status -eq "disposable-test-only" -and [string]$approval.projectionScope -eq "disposable-test-scenario") "approval scope is not disposable"
Require (-not [bool]$approval.automaticPublish -and [string]$approval.promotion -eq "forbidden") "Consumer staging bypasses the publish gate"
Require ([string]$policy.permissions.default -eq "deny" -and @($policy.permissions.deny) -contains "runtime-registration") "AI policy runtime-registration deny is missing"
Require ([int]$candidate.aiWrites.generated -eq 0 -and [int]$candidate.aiWrites.core -eq 0 -and [int]$candidate.aiWrites.lua -eq 0 -and [int]$candidate.aiWrites.network -eq 0) "AI candidate has forbidden writes"

$artifact = [ordered]@{
    schema = "cm2.ai-weapon-candidate-package/1"
    packageId = "cm2.ai.weapon.assistant"
    packageVersion = "1.0.0-candidate"
    entrypoints = [ordered]@{ runtime = "data-only"; preview = "cm2.preview/1"; lua = $null }
    content = [ordered]@{
        candidateId = [string]$candidate.id
        candidateHash = [string]$candidate.candidateHash
        finalBuildHash = [string]$candidate.finalBuildHash
        sourceScope = "source-definition-candidate"
        behavior = [string]$candidate.intent.behavior
        effectType = [string]$candidate.intent.effectType
        fireRateHz = [double]$candidate.intent.fireRateHz
        damage = [double]$candidate.intent.damage
        speedMps = [double]$candidate.intent.speedMps
        effectPriority = [double]$candidate.intent.effectPriority
    }
    capabilities = @("Weapon", "Projectile", "Effect", "Assets")
    runtimeRegistration = $false
    generatedArtifactWrite = $false
    coreWrite = $false
    luaWrite = $false
    networkWrite = $false
    humanApprovalRequired = $true
    automaticPublish = $false
}
$packageRoot = Join-Path $ConsumerRoot "packages\cm2.ai.weapon.assistant"
$artifactPath = Join-Path $packageRoot "candidate.artifact.json"
Write-Atomic $artifactPath (Canonical $artifact)
$packageHash = Sha256-File $artifactPath
$mainXml = @"
<scene version="2.0.1" shadowVolume="40 20 40">
    <environment template="sunny"/>
    <script file="MOD/script/testing/ai_weapon/consumer_host.lua" param0="candidateId=$(Xml-Escape ([string]$candidate.id))" param1="candidateHash=$(Xml-Escape ([string]$candidate.candidateHash))" param2="finalBuildHash=$(Xml-Escape ([string]$candidate.finalBuildHash))" param3="packageHash=$(Xml-Escape $packageHash)" param4="validOperation=accepted:Weapon-Projectile-Effect" param5="invalidOperation=rejected:ExecuteLua" param6="runtimeEntrypoint=data-only" param7="projection=manual-approval-required"/>
    <body name="AI Consumer Fixture Floor" dynamic="false" pos="0 -0.1 0">
        <voxbox size="20 1 20" material="masonry"/>
    </body>
    <location name="Player" tags="player" pos="0 1 4" rot="0 0 0"/>
</scene>
"@
Write-Atomic (Join-Path $ConsumerRoot "main.xml") $mainXml
$trace = [ordered]@{
    schema = "cm2.ai-weapon-consumer-install-trace/1"
    consumerMod = "_AI Test Consumer AI Weapon V1"
    packageId = [string]$artifact.packageId
    packageVersion = [string]$artifact.packageVersion
    packageHash = $packageHash
    candidateId = [string]$candidate.id
    candidateHash = [string]$candidate.candidateHash
    finalBuildHash = [string]$candidate.finalBuildHash
    validOperation = "accepted:Weapon-Projectile-Effect"
    invalidOperation = "rejected:ExecuteLua"
    runtimeEntrypoint = "data-only"
    runtimeLuaLoaded = $false
    consumerPrivateIncludes = 0
    automaticPublish = $false
    result = "pass"
}
Write-Atomic $TracePath (Canonical $trace)
Write-Output (Canonical $trace)
Write-Host "AI Weapon independent Consumer staging passed." -ForegroundColor Green
exit 0
