# Teardown Lua syntax and #include chain checker

param(
    [string]$Path = ".\Content Mod 2\script",
    [string]$LuaExecutable = "",
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

$root = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path).TrimEnd("\", "/")
$rootPrefix = $root + [System.IO.Path]::DirectorySeparatorChar
$luaExe = Find-LuaExecutable -RequestedPath $LuaExecutable
if ($luaExe -eq $null) {
    Write-Host "[ERROR] No Lua parser found." -ForegroundColor Red
    Write-Host "Install the VS Code Lua extension, install Lua, or pass -LuaExecutable <path>." -ForegroundColor Yellow
    exit 1
}

$strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$files = @(Get-ChildItem -LiteralPath $root -Filter *.lua -Recurse -File -ErrorAction Stop)
$graph = @{}
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
                    $externalIncludeCount++
                    if ($Verbose) {
                        Write-Host "[ENGINE INCLUDE] $(Get-RelativeSourcePath $fullPath):$lineNumber -> $includePath" -ForegroundColor DarkCyan
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

    Write-Host ""
    Write-Host "Check complete: $($files.Count) Lua files, $externalIncludeCount engine includes" -ForegroundColor Cyan

    if ($includeIssueCount -eq 0 -and $readIssueCount -eq 0 -and -not $syntaxIssue) {
        Write-Host "OK - Lua syntax and include chains are valid." -ForegroundColor Green
        exit 0
    }

    Write-Host "FAILED - include issues: $includeIssueCount, read issues: $readIssueCount, syntax failure: $syntaxIssue" -ForegroundColor Red
    exit 1
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
