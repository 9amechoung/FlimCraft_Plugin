# FlimCraft_Plugin installer: download FilmCraft, apply this repo's patches, build and run.
#
# From any terminal (downloads everything from GitHub):
#   irm https://raw.githubusercontent.com/9amechoung/FlimCraft_Plugin/main/install.ps1 | iex
# With options:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/9amechoung/FlimCraft_Plugin/main/install.ps1))) -Test
# From a clone of this repo (uses the local patches):
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 [-Test] [-NoRun] [-Target C:\path\filmcraft]
#
#   -Target  FilmCraft folder (default: .\filmcraft in the current folder)
#   -Test    run the patch's tests before starting
#   -NoRun   only clone and patch (no build)

param(
    [string]$Target = (Join-Path (Get-Location) 'filmcraft'),
    [switch]$Test,
    [switch]$NoRun
)

$ErrorActionPreference = 'Stop'
$repoRaw = 'https://raw.githubusercontent.com/9amechoung/FlimCraft_Plugin/main'
# relative to the PowerShell location (Windows PowerShell's cd doesn't move the process folder)
$Target = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Target)
$safe = $Target -replace '\\', '/'

# git in the FilmCraft folder. safe.directory is passed per command because drives that don't
# record file ownership (exFAT, FAT32) make git refuse the folder otherwise.
function Invoke-FcGit {
    $out = & git -c "safe.directory=$safe" -C $Target @args
    if ($LASTEXITCODE -ne 0) { throw "git $args failed ($LASTEXITCODE)" }
    $out
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git is not installed: https://git-scm.com' }

# Patches: next to this script when run from a clone, otherwise downloaded from GitHub.
$local = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'patches' } else { $null }
if ($local -and (Test-Path (Join-Path $local 'series'))) {
    $patchDir = $local
    $commit = (Get-Content (Join-Path $PSScriptRoot 'FILMCRAFT_COMMIT') -Raw).Trim()
    Write-Host "Using the patches in $patchDir"
} else {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $patchDir = Join-Path ([System.IO.Path]::GetTempPath()) "flimcraft-plugin-$PID"
    New-Item -ItemType Directory -Force $patchDir | Out-Null
    Write-Host "Downloading the patches from $repoRaw"
    $commit = (Invoke-RestMethod "$repoRaw/FILMCRAFT_COMMIT" -UseBasicParsing).Trim()
    Invoke-WebRequest "$repoRaw/patches/series" -OutFile (Join-Path $patchDir 'series') -UseBasicParsing
    foreach ($name in Get-Content (Join-Path $patchDir 'series')) {
        if ($name.Trim()) { Invoke-WebRequest "$repoRaw/patches/$($name.Trim())" -OutFile (Join-Path $patchDir $name.Trim()) -UseBasicParsing }
    }
}
$patches = @(Get-Content (Join-Path $patchDir 'series') | Where-Object { $_.Trim() } | ForEach-Object { Join-Path $patchDir $_.Trim() })

if (-not (Test-Path (Join-Path $Target '.git'))) {
    Write-Host "Cloning FilmCraft into $Target ..."
    & git clone https://github.com/storytold/filmcraft.git $Target
    if ($LASTEXITCODE -ne 0) { throw 'git clone failed' }
} else {
    Write-Host "Using the FilmCraft checkout in $Target"
    Invoke-FcGit fetch -q origin | Out-Null
}
if (Invoke-FcGit status --porcelain) {
    throw "$Target has uncommitted changes. Commit or stash them first, or pass another -Target."
}

Invoke-FcGit checkout -q -B flimcraft-plugin $commit | Out-Null
foreach ($p in $patches) {
    Write-Host "Applying $(Split-Path $p -Leaf)"
    Invoke-FcGit apply --whitespace=nowarn $p | Out-Null
}
Invoke-FcGit add -A | Out-Null
Invoke-FcGit -c user.name=FlimCraft_Plugin -c user.email=flimcraft-plugin@localhost commit -q -m 'FlimCraft_Plugin patches' | Out-Null
Write-Host "Patched: branch 'flimcraft-plugin' in $Target = FilmCraft $($commit.Substring(0, 7)) + $($patches.Count) patch(es)."

if ($NoRun -and -not $Test) { return }

# A fresh rustup install is not on PATH until a new terminal; use its default folder.
$cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
if (-not (Get-Command cargo -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $cargoBin 'cargo.exe'))) {
    $env:PATH = "$cargoBin;$env:PATH"
}
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    throw 'cargo (Rust) is not installed. Install it from https://rustup.rs and run this again.'
}
Push-Location $Target
try {
    if ($Test) {
        & cargo test -p filmcraft-audio-dsp -p filmcraft-project -p filmcraft-render
        if ($LASTEXITCODE -ne 0) { throw 'tests failed' }
    }
    if (-not $NoRun) {
        Write-Host 'Building and starting FilmCraft (the first build takes several minutes) ...'
        & cargo run --release -p filmcraft
    }
} finally {
    Pop-Location
}
