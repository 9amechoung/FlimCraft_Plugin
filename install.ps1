# FlimCraft_Plugin installer: download FilmCraft, apply this repo's patches, build and run.
#
# Easiest: download install.cmd into the folder FilmCraft should go to and double-click it.
# From any terminal (downloads everything from GitHub):
#   irm https://raw.githubusercontent.com/9amechoung/FlimCraft_Plugin/main/install.ps1 | iex
# With options:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/9amechoung/FlimCraft_Plugin/main/install.ps1))) -Test
# From a clone of this repo (uses the local patches):
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 [-Test] [-NoRun] [-Target C:\path\filmcraft]
#
#   -Target      FilmCraft folder (default: .\filmcraft in the current folder)
#   -Test        run the patch's tests before starting
#   -NoRun       only clone and patch (no build)
#   -Yes         install missing tools (Git, Rust, C++ build tools) without asking
#   -NoShortcut  don't create the desktop and Start menu shortcuts

param(
    [string]$Target = (Join-Path (Get-Location) 'filmcraft'),
    [switch]$Test,
    [switch]$NoRun,
    [switch]$Yes,
    [switch]$NoShortcut
)

$ErrorActionPreference = 'Stop'
$repoRaw = 'https://raw.githubusercontent.com/9amechoung/FlimCraft_Plugin/main'
$minRust = [version]'1.95'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
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

# --- prerequisites -------------------------------------------------------------------------

# Programs installed while this script runs are not on this terminal's PATH yet.
function Update-Path {
    $env:PATH = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine'),
        [Environment]::GetEnvironmentVariable('Path', 'User'),
        (Join-Path $env:USERPROFILE '.cargo\bin')
    ) -join ';'
}

function Confirm-Install([string]$what) {
    if ($Yes) { return }
    $answer = Read-Host "$what is not installed. Install it now? [Y/n]"
    if ($answer -and $answer -notmatch '^(y|yes)$') { throw "$what is required. Install it and run this again." }
}

function Install-WithWinget([string]$id, [string[]]$extra = @()) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget is not available to install $id. Install 'App Installer' from the Microsoft Store, or install $id by hand."
    }
    & winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements @extra
    # winget returns non-zero when the package is already installed; the check after this decides
    Update-Path
}

function Assert-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) { return }
    Confirm-Install 'Git'
    Install-WithWinget 'Git.Git'
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git was installed but is not on PATH. Open a new terminal and run this again.' }
}

function Get-VcToolsPath {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path $vswhere)) { return $null }
    $component = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'Microsoft.VisualStudio.Component.VC.Tools.ARM64' } else { 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64' }
    & $vswhere -latest -products * -requires $component -property installationPath
}

function Assert-BuildTools {
    if (Get-VcToolsPath) { return }
    Confirm-Install 'Visual Studio C++ build tools (about 5 GB; Windows asks for administrator permission)'
    Install-WithWinget 'Microsoft.VisualStudio.2022.BuildTools' @('--override', '--wait --passive --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended')
    if (-not (Get-VcToolsPath)) { throw 'The C++ build tools are still missing. Install "Desktop development with C++" from https://visualstudio.microsoft.com/visual-cpp-build-tools/ and run this again.' }
}

function Assert-Rust {
    Update-Path
    if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
        Confirm-Install 'Rust'
        $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'aarch64' } else { 'x86_64' }
        $rustupInit = Join-Path ([System.IO.Path]::GetTempPath()) 'rustup-init.exe'
        Write-Host 'Downloading Rust (rustup) ...'
        Invoke-WebRequest "https://win.rustup.rs/$arch" -OutFile $rustupInit -UseBasicParsing
        & $rustupInit -y --default-toolchain stable --profile minimal
        if ($LASTEXITCODE -ne 0) { throw 'Installing Rust failed.' }
        Update-Path
    }
    if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) { throw 'Rust was installed but cargo is not on PATH. Open a new terminal and run this again.' }
    $have = [version](((& rustc --version) -split ' ')[1] -replace '-.*$', '')
    if ($have -lt $minRust) {
        if (-not (Get-Command rustup -ErrorAction SilentlyContinue)) { throw "Rust $have is too old; FilmCraft needs $minRust or newer." }
        Write-Host "Rust $have is older than $minRust; updating ..."
        & rustup update stable
        if ($LASTEXITCODE -ne 0) { throw 'rustup update failed.' }
    }
}

# --- patch ---------------------------------------------------------------------------------

Assert-Git

# Patches: next to this script when run from a clone, otherwise downloaded from GitHub.
$local = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'patches' } else { $null }
if ($local -and (Test-Path (Join-Path $local 'series'))) {
    $patchDir = $local
    $commit = (Get-Content (Join-Path $PSScriptRoot 'FILMCRAFT_COMMIT') -Raw).Trim()
    Write-Host "Using the patches in $patchDir"
} else {
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

# --- build and run -------------------------------------------------------------------------

Assert-BuildTools
Assert-Rust
Push-Location $Target
try {
    if ($Test) {
        $suites = @(
            @('-p', 'filmcraft-audio-dsp', '-p', 'filmcraft-project', '-p', 'filmcraft-render'),
            @('-p', 'filmcraft-engine', '--lib', 'project_tools'),
            @('-p', 'filmcraft-ui-egui', '--test', 'project_panel_ui', 'import_image_sequence')
        )
        foreach ($s in $suites) {
            & cargo test @s
            if ($LASTEXITCODE -ne 0) { throw 'tests failed' }
        }
    }
    if (-not $NoRun) {
        Write-Host 'Building FilmCraft (the first build takes several minutes) ...'
        & cargo build --release -p filmcraft
        if ($LASTEXITCODE -ne 0) { throw 'cargo build failed' }
    }
} finally {
    Pop-Location
}
if ($NoRun) { return }

$exe = Join-Path $Target 'target\release\filmcraft.exe'
if (-not $NoShortcut) {
    # "(Plugin)" keeps it apart from a FilmCraft installed with the official installer
    $shell = New-Object -ComObject WScript.Shell
    foreach ($dir in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))) {
        $lnk = $shell.CreateShortcut((Join-Path $dir 'FilmCraft (Plugin).lnk'))
        $lnk.TargetPath = $exe
        $lnk.WorkingDirectory = Split-Path $exe
        $lnk.IconLocation = "$exe,0"
        $lnk.Description = 'FilmCraft with the FlimCraft_Plugin patches'
        $lnk.Save()
    }
    Write-Host "Shortcuts: 'FilmCraft (Plugin)' on the desktop and in the Start menu."
}
Write-Host "Starting $exe"
Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe)
