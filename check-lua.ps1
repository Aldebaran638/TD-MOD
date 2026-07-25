# Teardown Lua syntax and #include chain checker

param(
    [string]$Path = ".\Content Mod 2\script",
    [string]$LuaExecutable = "",
    [string]$TeardownDataPath = "",
    [switch]$SkipSemantic,
    [switch]$Verbose
)

Write-Host "=== Teardown Lua Syntax and Include Checker ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    Write-Host "[ERROR] Directory does not exist: $Path" -ForegroundColor Red
    exit 1
}

function Find-LuaExecutable {
    param([string]$RequestedPath)

    if ($RequestedPath -ne "") {
        if (Test-Path -LiteralPath $RequestedPath -PathType Leaf) {
            return (Resolve-Path -LiteralPath $RequestedPath).Path
        }
        return $null
    }

    $command = Get-Command lua-language-server -ErrorAction SilentlyContinue
    if ($command -ne $null) {
        return $command.Source
    }

    $extensionRoots = @(
        (Join-Path $env:USERPROFILE ".vscode\extensions"),
        (Join-Path $env:USERPROFILE ".vscode-insiders\extensions")
    )
    foreach ($extensionRoot in $extensionRoots) {
        if (-not (Test-Path -LiteralPath $extensionRoot -PathType Container)) {
            continue
        }
        $candidates = Get-ChildItem -LiteralPath $extensionRoot -Directory -Filter "sumneko.lua-*" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending
        foreach ($candidate in $candidates) {
            $exe = Join-Path $candidate.FullName "server\bin\lua-language-server.exe"
            if (Test-Path -LiteralPath $exe -PathType Leaf) {
                return $exe
            }
        }
    }

    $luaCommand = Get-Command lua -ErrorAction SilentlyContinue
    if ($luaCommand -ne $null) {
        return $luaCommand.Source
    }
    return $null
}

function Test-EngineInclude {
    param([string]$IncludePath)
    $normalized = $IncludePath.Replace("\", "/")
    return $normalized.StartsWith("script/include/", [System.StringComparison]::OrdinalIgnoreCase)
}

function Find-TeardownDataPath {
    param([string]$RequestedPath)

    $candidates = New-Object System.Collections.Generic.List[string]
    if ($RequestedPath -ne "") {
        $candidates.Add($RequestedPath)
    }
    $candidates.Add("D:\SteamLibrary\steamapps\common\Teardown\data")
    $candidates.Add("C:\Program Files (x86)\Steam\steamapps\common\Teardown\data")
    $candidates.Add("C:\Program Files\Steam\steamapps\common\Teardown\data")

    foreach ($candidateValue in $candidates) {
        $candidate = [System.IO.Path]::GetFullPath($candidateValue)
        if ((Split-Path -Leaf $candidate) -ne "data") {
            $candidate = Join-Path $candidate "data"
        }
        $defs = Join-Path $candidate "script_defs.lua"
        $scriptRoot = Join-Path $candidate "script"
        if ((Test-Path -LiteralPath $defs -PathType Leaf) -and
            (Test-Path -LiteralPath $scriptRoot -PathType Container)) {
            return $candidate
        }
    }
    return $null
}

$root = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path).TrimEnd("\", "/")
$rootPrefix = $root + [System.IO.Path]::DirectorySeparatorChar
$luaExe = Find-LuaExecutable -RequestedPath $LuaExecutable
if ($luaExe -eq $null) {
    Write-Host "[ERROR] No Lua parser found." -ForegroundColor Red
    Write-Host "Install the VS Code Lua extension, install Lua, or pass -LuaExecutable <path>." -ForegroundColor Yellow
    exit 1
}
$teardownDataRoot = Find-TeardownDataPath -RequestedPath $TeardownDataPath
if (-not $SkipSemantic -and $teardownDataRoot -eq $null) {
    Write-Host "[ERROR] Teardown data directory not found; official API validation is unavailable." -ForegroundColor Red
    Write-Host "Pass -TeardownDataPath <Teardown install or data directory>." -ForegroundColor Yellow
    exit 1
}
if (-not $SkipSemantic -and [System.IO.Path]::GetFileName($luaExe) -notlike "lua-language-server*") {
    Write-Host "[ERROR] lua-language-server is required for semantic API validation." -ForegroundColor Red
    exit 1
}

$strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$files = @(Get-ChildItem -LiteralPath $root -Filter *.lua -Recurse -File -ErrorAction Stop)
$graph = @{}
$engineIncludesByFile = @{}
$includeIssueCount = 0
$readIssueCount = 0
$externalIncludeCount = 0
$includePattern = '^\s*#include\s+"([^"]+)"\s*(?:--.*)?$'
$includeStartPattern = '^\s*#include\b'
$directivePattern = '^\s*#(?:include|version)\b'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("teardown-lua-check-" + [Guid]::NewGuid().ToString("N"))

function Get-RelativeSourcePath {
    param([string]$FullPath)
    if ($FullPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $FullPath.Substring($rootPrefix.Length)
    }
    return $FullPath
}

function Read-StrictUtf8 {
    param([string]$FilePath)
    [byte[]]$bytes = [System.IO.File]::ReadAllBytes($FilePath)
    $offset = 0
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $offset = 3
    }
    return $strictUtf8.GetString($bytes, $offset, $bytes.Length - $offset)
}

try {
    [System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null

    foreach ($file in $files) {
        $fullPath = [System.IO.Path]::GetFullPath($file.FullName)
        $graph[$fullPath] = @()
        $engineIncludesByFile[$fullPath] = @()

        try {
            $content = Read-StrictUtf8 -FilePath $fullPath
        }
        catch {
            Write-Host "[READ ERROR] $(Get-RelativeSourcePath $fullPath): invalid UTF-8" -ForegroundColor Red
            $readIssueCount++
            continue
        }

        $lines = @($content -split "`r`n|`n|`r")
        $sanitizedLines = New-Object System.Collections.Generic.List[string]

        for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
            $line = $lines[$lineIndex]
            $lineNumber = $lineIndex + 1

            if ($line -match $includePattern) {
                $includePath = $matches[1]
                if (Test-EngineInclude -IncludePath $includePath) {
                    if ($teardownDataRoot -ne $null) {
                        $engineCandidate = [System.IO.Path]::GetFullPath((Join-Path $teardownDataRoot $includePath))
                        $engineDataPrefix = [System.IO.Path]::GetFullPath($teardownDataRoot).TrimEnd("\", "/") +
                            [System.IO.Path]::DirectorySeparatorChar
                        if (-not $engineCandidate.StartsWith($engineDataPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                            Write-Host "[INCLUDE ERROR] $(Get-RelativeSourcePath $fullPath):$lineNumber escapes Teardown data root: $includePath" -ForegroundColor Red
                            $includeIssueCount++
                        }
                        elseif (-not (Test-Path -LiteralPath $engineCandidate -PathType Leaf)) {
                            Write-Host "[INCLUDE ERROR] $(Get-RelativeSourcePath $fullPath):$lineNumber missing engine include: $includePath" -ForegroundColor Red
                            $includeIssueCount++
                        }
                        else {
                            $externalIncludeCount++
                            $engineIncludesByFile[$fullPath] += @{
                                Source = $engineCandidate
                                Relative = $includePath.Replace("/", [System.IO.Path]::DirectorySeparatorChar)
                            }
                            if ($Verbose) {
                                Write-Host "[ENGINE INCLUDE] $(Get-RelativeSourcePath $fullPath):$lineNumber -> $includePath" -ForegroundColor DarkCyan
                            }
                        }
                    }
                    else {
                        $externalIncludeCount++
                    }
                }
                else {
                    $candidate = [System.IO.Path]::GetFullPath((Join-Path $file.DirectoryName $includePath))
                    if (-not $candidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                        Write-Host "[INCLUDE ERROR] $(Get-RelativeSourcePath $fullPath):$lineNumber escapes check root: $includePath" -ForegroundColor Red
                        $includeIssueCount++
                    }
                    elseif (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                        Write-Host "[INCLUDE ERROR] $(Get-RelativeSourcePath $fullPath):$lineNumber missing: $includePath" -ForegroundColor Red
                        $includeIssueCount++
                    }
                    else {
                        $graph[$fullPath] += $candidate
                        if ($Verbose) {
                            Write-Host "[INCLUDE] $(Get-RelativeSourcePath $fullPath):$lineNumber -> $(Get-RelativeSourcePath $candidate)" -ForegroundColor DarkGray
                        }
                    }
                }
            }
            elseif ($line -match $includeStartPattern) {
                Write-Host "[INCLUDE ERROR] $(Get-RelativeSourcePath $fullPath):$lineNumber malformed directive" -ForegroundColor Red
                $includeIssueCount++
            }

            if ($line -match $directivePattern) {
                $sanitizedLines.Add("-- Teardown preprocessor directive")
            }
            else {
                $sanitizedLines.Add($line)
            }
        }

        $relativePath = Get-RelativeSourcePath $fullPath
        $tempFile = Join-Path $tempRoot $relativePath
        $tempDirectory = Split-Path -Parent $tempFile
        [System.IO.Directory]::CreateDirectory($tempDirectory) | Out-Null
        [System.IO.File]::WriteAllText($tempFile, ($sanitizedLines -join "`r`n"), $utf8NoBom)
    }

    $visitState = @{}
    $visitStack = New-Object System.Collections.Generic.List[string]

    function Visit-IncludeNode {
        param([string]$Node)

        $state = $visitState[$Node]
        if ($state -eq 2) {
            return
        }
        if ($state -eq 1) {
            $startIndex = $visitStack.IndexOf($Node)
            $cycle = New-Object System.Collections.Generic.List[string]
            for ($i = $startIndex; $i -lt $visitStack.Count; $i++) {
                $cycle.Add((Get-RelativeSourcePath $visitStack[$i]))
            }
            $cycle.Add((Get-RelativeSourcePath $Node))
            Write-Host "[INCLUDE CYCLE] $($cycle -join ' -> ')" -ForegroundColor Red
            $script:includeIssueCount++
            return
        }

        $visitState[$Node] = 1
        $visitStack.Add($Node)
        foreach ($target in @($graph[$Node])) {
            Visit-IncludeNode -Node $target
        }
        $visitStack.RemoveAt($visitStack.Count - 1)
        $visitState[$Node] = 2
    }

    foreach ($node in @($graph.Keys)) {
        Visit-IncludeNode -Node $node
    }

    $tempFiles = @(Get-ChildItem -LiteralPath $tempRoot -Filter *.lua -Recurse -File)
    $syntaxIssue = $false
    if ($tempFiles.Count -gt 0) {
        $expression = 'local failed=false; for i=4,#arg do local f,e=loadfile(arg[i]); if not f then io.stderr:write(e, string.char(10)); failed=true end end; if failed then os.exit(1) end'
        $arguments = @("-e", $expression, "--") + @($tempFiles.FullName)
        $syntaxOutput = & $luaExe @arguments 2>&1
        $syntaxExitCode = $LASTEXITCODE
        if ($syntaxExitCode -ne 0) {
            $syntaxIssue = $true
            Write-Host "[SYNTAX ERROR]" -ForegroundColor Red
            foreach ($outputLine in $syntaxOutput) {
                $mapped = ([string]$outputLine).Replace($tempRoot, $root)
                Write-Host $mapped -ForegroundColor Red
            }
        }
        elseif ($Verbose) {
            Write-Host "[SYNTAX OK] $($tempFiles.Count) files" -ForegroundColor Green
        }
    }

    $semanticIssueCount = 0
    if (-not $SkipSemantic -and $includeIssueCount -eq 0 -and $readIssueCount -eq 0 -and -not $syntaxIssue) {
        $incomingCount = @{}
        foreach ($node in @($graph.Keys)) {
            $incomingCount[$node] = 0
        }
        foreach ($node in @($graph.Keys)) {
            foreach ($target in @($graph[$node])) {
                $incomingCount[$target] = ([int]$incomingCount[$target]) + 1
            }
        }

        $entryFiles = @($graph.Keys | Where-Object { ([int]$incomingCount[$_]) -eq 0 } | Sort-Object)
        $semanticRoot = Join-Path $tempRoot "_semantic"
        [System.IO.Directory]::CreateDirectory($semanticRoot) | Out-Null
        $officialDefs = Join-Path $teardownDataRoot "script_defs.lua"
        $officialPlugin = Join-Path $teardownDataRoot "td_vscode_plugin.lua"
        $semanticDiagnosticKeys = New-Object "System.Collections.Generic.HashSet[string]" ([System.StringComparer]::Ordinal)
        $semanticDiagnostics = New-Object System.Collections.Generic.List[string]

        function Get-IncludeClosure {
            param([string]$EntryFile)
            $visited = @{}
            $stack = New-Object System.Collections.Generic.Stack[string]
            $stack.Push($EntryFile)
            while ($stack.Count -gt 0) {
                $current = $stack.Pop()
                if ($visited.ContainsKey($current)) {
                    continue
                }
                $visited[$current] = $true
                foreach ($target in @($graph[$current])) {
                    $stack.Push($target)
                }
            }
            return @($visited.Keys)
        }

        for ($entryIndex = 0; $entryIndex -lt $entryFiles.Count; $entryIndex++) {
            $entryFile = $entryFiles[$entryIndex]
            $entryWorkspace = Join-Path $semanticRoot ("entry-" + $entryIndex)
            [System.IO.Directory]::CreateDirectory($entryWorkspace) | Out-Null
            $closure = @(Get-IncludeClosure -EntryFile $entryFile)

            foreach ($closureFile in $closure) {
                $relativePath = Get-RelativeSourcePath $closureFile
                $sanitizedSource = Join-Path $tempRoot $relativePath
                $destination = Join-Path $entryWorkspace $relativePath
                [System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
                [System.IO.File]::Copy($sanitizedSource, $destination, $true)

                foreach ($engineInclude in @($engineIncludesByFile[$closureFile])) {
                    $engineDestination = Join-Path $entryWorkspace ([string]$engineInclude.Relative)
                    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $engineDestination)) | Out-Null
                    [System.IO.File]::Copy([string]$engineInclude.Source, $engineDestination, $true)
                }
            }

            $config = @{
                runtime = @{
                    version = "Lua 5.1"
                    plugin = $officialPlugin
                }
                workspace = @{
                    library = @($officialDefs)
                    checkThirdParty = $false
                }
                diagnostics = @{
                    globals = @("server", "client", "shared")
                    disable = @(
                        "ambiguity-1",
                        "count-down-loop",
                        "different-requires",
                        "duplicate-index",
                        "duplicate-set-field",
                        "empty-block",
                        "global-element",
                        "lowercase-global",
                        "name-style-check",
                        "need-check-nil",
                        "redefined-local",
                        "trailing-space",
                        "unbalanced-assignments",
                        "unused-function",
                        "unused-label",
                        "unused-local",
                        "unused-vararg"
                    )
                    neededFileStatus = @{
                        "undefined-global" = "Any"
                        "undefined-field" = "Any"
                        "missing-parameter" = "Any"
                        "redundant-parameter" = "Any"
                        "param-type-mismatch" = "Any"
                    }
                }
            }
            $configPath = Join-Path $entryWorkspace ".luarc.json"
            [System.IO.File]::WriteAllText(
                $configPath,
                ($config | ConvertTo-Json -Depth 8),
                $utf8NoBom
            )
            $apiOverrides = @'
---@param playerId number
---@param functionName string
---@param ... any
function ClientCall(playerId, functionName, ...) end

---@param functionName string
---@param ... any
function ServerCall(functionName, ...) end
'@
            [System.IO.File]::WriteAllText(
                (Join-Path $entryWorkspace "_teardown_api_overrides.lua"),
                $apiOverrides,
                $utf8NoBom
            )

            $entryLog = Join-Path $entryWorkspace ".lls-log"
            $semanticOutput = & $luaExe `
                "--check=$entryWorkspace" `
                "--check_format=pretty" `
                "--checklevel=Warning" `
                "--configpath=$configPath" `
                "--logpath=$entryLog" 2>&1

            $pendingSemanticHeader = $null
            foreach ($outputLineValue in @($semanticOutput)) {
                $outputLine = [regex]::Replace(
                    [string]$outputLineValue,
                    "$([char]27)\[[0-9;]*m",
                    ""
                )
                if ($outputLine -match "^.+?:\d+:\d+ \[(Error|Warning|Information|Hint)\]") {
                    $pendingSemanticHeader = $outputLine
                }
                if ($outputLine -notmatch "\((undefined-global|undefined-field|missing-parameter|redundant-parameter|param-type-mismatch)\)") {
                    continue
                }
                if ($outputLine.TrimStart().StartsWith("-") -and $pendingSemanticHeader -ne $null) {
                    $outputLine = "$pendingSemanticHeader $($outputLine.Trim())"
                }
                $engineWorkspaceRoot = Join-Path $entryWorkspace "script\include"
                if ($outputLine.StartsWith($engineWorkspaceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                    continue
                }
                $mapped = $outputLine.Replace($entryWorkspace, $root)
                $mapped = $mapped.Replace("/", [System.IO.Path]::DirectorySeparatorChar)
                $diagnosticKey = $mapped
                if ($mapped -match "^(.*?):(\d+):\d+ .*\(([a-z0-9-]+)\)$") {
                    $diagnosticKey = "$($matches[1]):$($matches[2]):$($matches[3])"
                }
                $wasAdded = $semanticDiagnosticKeys.Add($diagnosticKey)
                if ($wasAdded) {
                    $semanticDiagnostics.Add($mapped)
                }
                if ($Verbose -and $wasAdded) {
                    Write-Host "[SEMANTIC] $mapped" -ForegroundColor Yellow
                }
            }
        }

        $semanticIssueCount = $semanticDiagnostics.Count
        if ($semanticIssueCount -gt 0) {
            Write-Host "[SEMANTIC ERROR]" -ForegroundColor Red
            foreach ($diagnostic in @($semanticDiagnostics | Sort-Object)) {
                Write-Host $diagnostic -ForegroundColor Red
            }
        }
        elseif ($Verbose) {
            Write-Host "[SEMANTIC OK] $($entryFiles.Count) include closure(s)" -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "Check complete: $($files.Count) Lua files, $externalIncludeCount engine includes, $semanticIssueCount semantic issues" -ForegroundColor Cyan

    if ($includeIssueCount -eq 0 -and $readIssueCount -eq 0 -and -not $syntaxIssue -and $semanticIssueCount -eq 0) {
        Write-Host "OK - Lua syntax, include closures, and Teardown API calls are valid." -ForegroundColor Green
        exit 0
    }

    Write-Host "FAILED - include issues: $includeIssueCount, read issues: $readIssueCount, syntax failure: $syntaxIssue, semantic issues: $semanticIssueCount" -ForegroundColor Red
    exit 1
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
