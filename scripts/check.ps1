#requires -version 5.1
<#
.SYNOPSIS
    Tiered local verification for the EffectCraft bug-fix campaign.

.DESCRIPTION
    -Mode fast  : changed crates only - cargo fmt --check, clippy -D warnings,
                  tests of the touched crates, then xtask layers + assets.
                  Warm this is a few minutes; it is what .githooks/pre-commit runs.
    -Mode full  : `cargo xtask ci` (fmt, workspace clippy, tests, pdf-deps, layers,
                  assets, wasm). Run before declaring a bug fixed.

    The script resolves git and cargo itself (neither has to be on PATH) and exits
    with 0 only when every stage passed.

.PARAMETER Mode
    fast (default) or full.

.PARAMETER Crate
    Package names to check instead of auto-detecting them from git.
    Example: -Crate effectcraft-render,effectcraft-engine

.PARAMETER SkipTests
    fast mode: skip the per-crate test run (fmt + clippy still run).

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1 -Mode full
#>
[CmdletBinding()]
param(
    [ValidateSet('fast', 'full')]
    [string]$Mode = 'fast',
    [string[]]$Crate = @(),
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Find-Tool {
    param([string]$Name, [string[]]$Candidates)
    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$cargo = Find-Tool 'cargo' @(
    (Join-Path $env:USERPROFILE '.cargo\bin\cargo.exe'),
    $(if ($env:CARGO_HOME) { Join-Path $env:CARGO_HOME 'bin\cargo.exe' } else { $null })
)
$git = Find-Tool 'git' @(
    'C:\Program Files\Git\cmd\git.exe',
    'C:\Program Files (x86)\Git\cmd\git.exe',
    (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe')
)

# Child processes (xtask itself shells out to git) need both tools on PATH.
foreach ($tool in @($cargo, $git)) {
    if ($tool) {
        $dir = Split-Path -Parent $tool
        if (($env:PATH -split ';') -notcontains $dir) { $env:PATH = "$dir;$env:PATH" }
    }
}

if (-not $cargo) {
    Write-Host 'check: cargo not found.' -ForegroundColor Red
    Write-Host '  Install the toolchain first: powershell -ExecutionPolicy Bypass -File scripts/setup-toolchain.ps1'
    exit 2
}

Write-Host "check: root    = $root"
Write-Host "check: cargo   = $cargo"
Write-Host "check: git     = $(if ($git) { $git } else { '<not found>' })"
Write-Host "check: mode    = $Mode"

function Get-ChangedPackages {
    param([string]$Git, [string]$Root)

    $files = New-Object System.Collections.Generic.List[string]
    if ($Git) {
        $base = $null
        $mergeBase = & $Git merge-base HEAD origin/main 2>$null
        if ($LASTEXITCODE -eq 0 -and $mergeBase) { $base = $mergeBase }
        if ($base) {
            foreach ($f in (& $Git diff --name-only $base 2>$null)) { if ($f) { $files.Add($f) } }
        }
        foreach ($f in (& $Git diff --name-only 2>$null)) { if ($f) { $files.Add($f) } }
        foreach ($f in (& $Git diff --name-only --cached 2>$null)) { if ($f) { $files.Add($f) } }
        foreach ($f in (& $Git ls-files --others --exclude-standard 2>$null)) { if ($f) { $files.Add($f) } }
    }

    $packages = New-Object System.Collections.Generic.List[string]
    $workspaceWide = $false
    foreach ($file in ($files | Sort-Object -Unique)) {
        $normalized = $file -replace '\\', '/'
        if ($normalized -eq 'Cargo.toml' -or $normalized -eq 'Cargo.lock' -or $normalized -eq 'rustfmt.toml' -or $normalized -eq 'clippy.toml') {
            $workspaceWide = $true
            continue
        }
        if ($normalized -match '^(crates|apps|xtask)/([^/]+)/') {
            $dir = "$($Matches[1])/$($Matches[2])"
            $toml = Join-Path $Root (Join-Path $dir 'Cargo.toml')
            if (-not (Test-Path -LiteralPath $toml)) { continue }
            $match = Select-String -LiteralPath $toml -Pattern '^\s*name\s*=\s*"([^"]+)"' | Select-Object -First 1
            if ($match) {
                $name = $match.Matches[0].Groups[1].Value
                if (-not $packages.Contains($name)) { $packages.Add($name) }
            }
        }
    }

    return [pscustomobject]@{ Packages = @($packages); WorkspaceWide = $workspaceWide }
}

$script:failed = New-Object System.Collections.Generic.List[string]

function Invoke-Stage {
    param([string]$Name, [string]$Exe, [string[]]$Arguments)
    Write-Host ''
    Write-Host "==> $Name" -ForegroundColor Cyan
    Write-Host "    $Exe $($Arguments -join ' ')" -ForegroundColor DarkGray
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) {
        $script:failed.Add($Name)
        Write-Host "==> $Name FAILED (exit $LASTEXITCODE)" -ForegroundColor Red
        return $false
    }
    return $true
}

$started = Get-Date

if ($Mode -eq 'full') {
    Invoke-Stage -Name 'cargo xtask ci' -Exe $cargo -Arguments @('xtask', 'ci') | Out-Null
}
else {
    $changed = Get-ChangedPackages -Git $git -Root $root
    $packages = @($changed.Packages)
    if ($Crate.Count -gt 0) { $packages = @($Crate); $changed.WorkspaceWide = $false }

    if ($packages.Count -gt 0) {
        $list = ($packages | ForEach-Object { "-p $_" }) -join ' '
        Write-Host "check: changed packages: $($packages -join ', ')"
    }
    else {
        Write-Host 'check: no crate changes detected (docs/scripts only) - skipping clippy and tests'
    }
    if ($changed.WorkspaceWide -and $packages.Count -eq 0) {
        Write-Host 'check: workspace manifest changed - clippy will run workspace-wide'
        $changed.WorkspaceWide = $true
    }

    Invoke-Stage -Name 'fmt' -Exe $cargo -Arguments @('fmt', '--all', '--', '--check') | Out-Null

    if ($packages.Count -gt 0) {
        $clippyArgs = New-Object System.Collections.Generic.List[string]
        $clippyArgs.AddRange([string[]]@('clippy'))
        foreach ($p in $packages) { $clippyArgs.Add('-p'); $clippyArgs.Add($p) }
        $clippyArgs.AddRange([string[]]@('--all-targets', '--', '-D', 'warnings'))
        Invoke-Stage -Name 'clippy (changed crates)' -Exe $cargo -Arguments $clippyArgs.ToArray() | Out-Null
    }
    elseif ($changed.WorkspaceWide) {
        Invoke-Stage -Name 'clippy (workspace)' -Exe $cargo -Arguments @('clippy', '--workspace', '--all-targets', '--', '-D', 'warnings') | Out-Null
    }

    if ($packages.Count -gt 0 -and -not $SkipTests) {
        $testArgs = New-Object System.Collections.Generic.List[string]
        $testArgs.AddRange([string[]]@('test'))
        foreach ($p in $packages) { $testArgs.Add('-p'); $testArgs.Add($p) }
        $testArgs.AddRange([string[]]@('--lib', '--bins', '--tests', '--no-fail-fast'))
        Invoke-Stage -Name 'tests (changed crates)' -Exe $cargo -Arguments $testArgs.ToArray() | Out-Null
    }

    Invoke-Stage -Name 'layers' -Exe $cargo -Arguments @('xtask', 'layers') | Out-Null
    Invoke-Stage -Name 'assets' -Exe $cargo -Arguments @('xtask', 'assets') | Out-Null
}

$elapsed = (Get-Date) - $started
Write-Host ''
if ($script:failed.Count -eq 0) {
    Write-Host ("check: GREEN ({0}) in {1:n1}s" -f $Mode, $elapsed.TotalSeconds) -ForegroundColor Green
    exit 0
}
Write-Host ("check: RED ({0}) in {1:n1}s - failed: {2}" -f $Mode, $elapsed.TotalSeconds, ($script:failed -join ', ')) -ForegroundColor Red
exit 1
