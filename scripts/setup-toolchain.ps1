#requires -version 5.1
<#
.SYNOPSIS
    Install everything EffectCraft needs to build and pass `cargo xtask ci` on Windows.

.DESCRIPTION
    Installs, in order:
      1. rustup + a stable MSVC toolchain (rustfmt, clippy) - user level, no admin needed;
      2. the wasm32-unknown-unknown target (the `wasm` gate of `cargo xtask ci`);
      3. cargo-nextest 0.9.150 (the version .config/nextest.toml requires);
      4. Visual Studio 2022 Build Tools with the VCTools workload (MSVC linker +
         Windows SDK) - this one needs administrator rights and will show a UAC prompt.
    Optionally: ffprobe/ffmpeg as test oracles (the tests use them when present).

    Re-running is safe: every step checks first and skips what is already installed.

.PARAMETER SkipVs
    Do not try to install Visual Studio Build Tools (do this if they are installed
    somewhere this script cannot see, or if you install them by hand).

.PARAMETER SkipNextest
    Do not install cargo-nextest (`cargo xtask ci` then falls back to `cargo test`).

.PARAMETER WithFfmpeg
    Also install Gyan.FFmpeg (ffmpeg + ffprobe) for the export oracle tests.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-toolchain.ps1

.NOTES
    Run this in a normal (non-elevated) shell: the Build Tools step asks Windows for
    elevation itself, so the rest of the install keeps going into your user profile.
#>
[CmdletBinding()]
param(
    [switch]$SkipVs,
    [switch]$SkipNextest,
    [switch]$WithFfmpeg
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$rustup = Join-Path $env:USERPROFILE '.cargo\bin\rustup.exe'
$rustc = Join-Path $env:USERPROFILE '.cargo\bin\rustc.exe'
$cargo = Join-Path $env:USERPROFILE '.cargo\bin\cargo.exe'
$nextestVersion = '0.9.150'

function Write-Step([string]$Text) {
    Write-Host ''
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-Ok([string]$Text) { Write-Host "    ok: $Text" -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Host "    warning: $Text" -ForegroundColor Yellow }
function Write-Err([string]$Text) { Write-Host "    error: $Text" -ForegroundColor Red }

function Test-Command([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# ---------------------------------------------------------------- 1. rustup
Write-Step 'Rust toolchain (rustup)'
if (Test-Path -LiteralPath $rustup) {
    Write-Ok "rustup already installed ($rustup)"
}
elseif (Test-Command 'rustup') {
    $rustup = (Get-Command 'rustup').Source
    Write-Ok "rustup already installed ($rustup)"
}
else {
    if (Test-Command 'winget') {
        Write-Host '    installing Rustlang.Rustup through winget...'
        winget install --id Rustlang.Rustup --exact --source winget --accept-package-agreements --accept-source-agreements --silent
        if ($LASTEXITCODE -ne 0) { Write-Warn "winget returned $LASTEXITCODE - falling back to rustup-init.exe" }
    }
    if (-not (Test-Path -LiteralPath $rustup)) {
        $installer = Join-Path $env:TEMP 'rustup-init.exe'
        Write-Host '    downloading rustup-init.exe...'
        Invoke-WebRequest -Uri 'https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe' -OutFile $installer -UseBasicParsing
        & $installer -y --default-host x86_64-pc-windows-msvc --default-toolchain stable --profile default --no-modify-path
        if ($LASTEXITCODE -ne 0) { Write-Err "rustup-init failed with $LASTEXITCODE"; exit 1 }
    }
    if (Test-Path -LiteralPath $rustup) { Write-Ok 'rustup installed' }
    elseif (Test-Command 'rustup') { $rustup = (Get-Command 'rustup').Source; Write-Ok 'rustup installed' }
    else { Write-Err 'rustup still missing'; exit 1 }
}

& $rustup default stable
& $rustup component add rustfmt clippy
if ($LASTEXITCODE -ne 0) { Write-Warn 'could not add rustfmt/clippy - check the network and rerun' }

# The project asks for Rust 1.95+ (edition 2024); rustup's stable must satisfy it.
$rustcVersion = & $rustc --version
Write-Host "    $rustcVersion"
if ($rustcVersion -match 'rustc (\d+)\.(\d+)') {
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    if ($major -lt 1 -or ($major -eq 1 -and $minor -lt 95)) {
        Write-Warn "Rust $major.$minor is older than the workspace's rust-version = 1.95; run: rustup update stable"
    }
}

# ------------------------------------------------------- 2. wasm32 target
Write-Step 'wasm32-unknown-unknown target'
$targets = & $rustup target list --installed
if ($targets -contains 'wasm32-unknown-unknown') {
    Write-Ok 'wasm32-unknown-unknown installed'
}
else {
    & $rustup target add wasm32-unknown-unknown
    if ($LASTEXITCODE -eq 0) { Write-Ok 'wasm32-unknown-unknown installed' } else { Write-Err 'wasm32 target install failed' }
}

# ------------------------------------------------------- 3. cargo-nextest
Write-Step "cargo-nextest $nextestVersion"
$cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
$nextest = Join-Path $cargoBin 'cargo-nextest.exe'
if ($SkipNextest) {
    Write-Warn 'skipped (-SkipNextest); cargo xtask ci will use cargo test'
}
elseif (Test-Path -LiteralPath $nextest) {
    $version = & $nextest nextest --version
    if ($version -match '(\d+\.\d+\.\d+)' -and ([version]$Matches[1] -ge [version]$nextestVersion)) {
        Write-Ok "cargo-nextest $($Matches[1]) present"
    }
    else {
        Write-Host "    upgrading cargo-nextest ($version) to $nextestVersion..."
        & $cargo install cargo-nextest --version $nextestVersion --locked
    }
}
else {
    Write-Host '    installing (this compiles for a few minutes)...'
    & $cargo install cargo-nextest --version $nextestVersion --locked
    if ($LASTEXITCODE -eq 0) { Write-Ok 'cargo-nextest installed' } else { Write-Err 'cargo-nextest install failed' }
}

# ------------------------------------------------- 4. MSVC linker + Windows SDK
Write-Step 'Visual Studio 2022 Build Tools (MSVC linker, Windows SDK)'
$vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
$vcTools = $null
if (Test-Path -LiteralPath $vswhere) {
    $vcTools = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vcTools) { $vcTools = $null }
}
if ($vcTools) {
    Write-Ok "MSVC toolset found in $vcTools"
}
elseif ($SkipVs) {
    Write-Warn 'no MSVC toolset found and -SkipVs was given; rustc will fail to link'
}
else {
    Write-Host '    not installed. Installing Microsoft.VisualStudio.2022.BuildTools (needs admin; Windows will ask).'
    Write-Host '    This downloads roughly 2-4 GB and takes 5-15 minutes.'
    $override = '--quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
    winget install --id Microsoft.VisualStudio.2022.BuildTools --exact --source winget --accept-package-agreements --accept-source-agreements --override $override
    if ($LASTEXITCODE -ne 0) {
        Write-Err "winget returned $LASTEXITCODE. Install by hand: https://visualstudio.microsoft.com/visual-cpp-build-tools/ (workload: Desktop development with C++)"
    }
}

# --------------------------------------------------------------- optional
if ($WithFfmpeg) {
    Write-Step 'ffmpeg / ffprobe (test oracles only)'
    if (Test-Command 'ffprobe') {
        Write-Ok 'ffprobe already on PATH'
    }
    else {
        winget install --id Gyan.FFmpeg --exact --source winget --accept-package-agreements --accept-source-agreements --silent
        Write-Warn 'open a new shell so PATH picks ffmpeg up'
    }
}

# --------------------------------------------------------------- verify
Write-Step 'Verification'
if (Test-Path -LiteralPath $cargo) {
    & $cargo --version
    Push-Location $root
    try {
        & $cargo check -p effectcraft-time
        if ($LASTEXITCODE -eq 0) { Write-Ok 'cargo check -p effectcraft-time passed (a linker works)' }
        else { Write-Err 'cargo check failed - see the output above (usually a missing MSVC toolset)' }
    }
    finally { Pop-Location }
}
else {
    Write-Err "cargo not found at $cargo"
}

Write-Host ''
Write-Host 'Next steps:' -ForegroundColor Cyan
Write-Host '  1. powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-hooks.ps1'
Write-Host '  2. powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1 -Mode fast'
Write-Host '  3. powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1 -Mode full   # first run builds everything'
