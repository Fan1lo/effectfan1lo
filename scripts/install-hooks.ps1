#requires -version 5.1
<#
.SYNOPSIS
    Point this clone at the repository's git hooks (.githooks) and show the result.

.DESCRIPTION
    Git hooks are local configuration, so every clone has to enable them once.
    The hooks refuse commits on main and runs scripts/check.ps1 -Mode fast before
    every commit, plus block pushes to origin (this clone is a read-only fork).

.PARAMETER Disable
    Restore Git's default hook directory (no local checks).

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-hooks.ps1
#>
[CmdletBinding()]
param([switch]$Disable)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Find-Git {
    foreach ($candidate in @('C:\Program Files\Git\cmd\git.exe', 'C:\Program Files (x86)\Git\cmd\git.exe', (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe'))) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    $cmd = Get-Command 'git' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'git not found. Install Git for Windows (https://git-scm.com/download/win).'
}

$git = Find-Git

if ($Disable) {
    & $git config --local --unset core.hooksPath 2>$null
    Write-Host 'hooks disabled (core.hooksPath removed)' -ForegroundColor Yellow
    exit 0
}

foreach ($hook in @('pre-commit', 'pre-push')) {
    $path = Join-Path $root ".githooks/$hook"
    if (-not (Test-Path -LiteralPath $path)) { throw "missing hook: $path" }
}

& $git config --local core.hooksPath .githooks
if ($LASTEXITCODE -ne 0) { throw 'could not set core.hooksPath' }

# Git for Windows executes hooks through sh; LF line endings are mandatory.
foreach ($hook in @('pre-commit', 'pre-push')) {
    $path = Join-Path $root ".githooks/$hook"
    $text = [System.IO.File]::ReadAllText($path)
    if ($text -match "`r`n") {
        [System.IO.File]::WriteAllText($path, ($text -replace "`r`n", "`n"))
        Write-Host "normalised line endings: .githooks/$hook" -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host 'Git hooks installed.' -ForegroundColor Green
& $git config --get core.hooksPath
Write-Host ''
Write-Host 'pre-commit : blocks commits on main, runs scripts/check.ps1 -Mode fast'
Write-Host 'pre-push   : blocks pushes to origin (ALLOW_PUSH=1 overrides)'
Write-Host ''
Write-Host 'Emergency bypass (record the reason in PROGRESS.md): SKIP_CHECKS=1 git commit ...'
