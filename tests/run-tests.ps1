<#
    Vanilla Appliances Extended test runner.

    Boots Project Zomboid's own Kahlua VM outside the game, stubs the parts of the
    game API the mod touches, and runs the specs in tests/specs against the real mod
    source. No game launch, no manual clicking.

    Inherited from QoL Compendium, so the internal globals and environment
    variables it passes to the harness still carry a QOLC_ prefix. They are
    internal names only; renaming them means touching pz_stubs.lua and
    TestRunner.java in step.

    Usage:  pwsh tests/run-tests.ps1
#>

$ErrorActionPreference = 'Stop'

function Find-GameDir {
    # An explicit override wins, for an install this does not know about.
    if ($env:QOLC_PZ_DIR) { return $env:QOLC_PZ_DIR }

    # Otherwise walk every Steam library listed in libraryfolders.vdf, then fall
    # back to the usual suspects. Beats hardcoding one machine's drive letter.
    $candidates = @()
    foreach ($steam in @("${env:ProgramFiles(x86)}\Steam", "$env:ProgramFiles\Steam")) {
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s*"([^"]+)"')) {
                $candidates += Join-Path ($m.Groups[1].Value -replace '\\\\', '\') 'steamapps\common\ProjectZomboid'
            }
        }
    }
    foreach ($drive in (Get-PSDrive -PSProvider FileSystem).Name) {
        $candidates += "${drive}:\SteamLibrary\steamapps\common\ProjectZomboid"
        $candidates += "${drive}:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
    }

    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c 'projectzomboid.jar')) { return $c }
    }
    throw "Could not find a Project Zomboid install. Set QOLC_PZ_DIR to its folder."
}

$GameDir  = Find-GameDir
$Jar      = Join-Path $GameDir 'projectzomboid.jar'
$Root     = Split-Path -Parent $PSScriptRoot
# The repository is laid out the way Steam expects a Workshop item, so the mod itself is
# several levels down. Everything below, and TestRunner, works from this one path.
$ModRoot  = Join-Path $Root 'VanillaAppliancesExtended\Contents\mods\VanillaAppliancesExtended'
$Harness  = Join-Path $PSScriptRoot 'harness'
$Specs    = Join-Path $PSScriptRoot 'specs'
$Build    = Join-Path $PSScriptRoot 'build'

function Find-Jdk {
    $candidates = @(
        'C:\Program Files\Eclipse Adoptium\jdk-*\bin',
        'C:\Program Files\*\jdk*\bin',
        'C:\Program Files\JetBrains\*\jbr\bin'
    )
    foreach ($pattern in $candidates) {
        $hit = Get-ChildItem $pattern -ErrorAction SilentlyContinue |
               Where-Object { Test-Path (Join-Path $_.FullName 'javac.exe') } |
               Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    throw "No JDK with javac found. The JRE bundled with the game cannot compile the runner."
}

# --- preflight -------------------------------------------------------------

if (-not (Test-Path $Jar)) { throw "Game jar not found at $Jar" }
$JdkBin = Find-Jdk
$Javac  = Join-Path $JdkBin 'javac.exe'
$Java   = Join-Path $JdkBin 'java.exe'

$VersionFile = Join-Path $env:USERPROFILE 'Zomboid\version.txt'
$Build42 = if (Test-Path $VersionFile) { (Get-Content $VersionFile | Select-Object -First 1) } else { 'unknown' }

Write-Host "Game    $GameDir"
Write-Host "Build   $Build42"
Write-Host "JDK     $JdkBin"
Write-Host ""

# --- compile the runner ----------------------------------------------------

New-Item -ItemType Directory -Force -Path $Build | Out-Null
$RunnerSrc = Join-Path $Harness 'TestRunner.java'
$RunnerCls = Join-Path $Build 'TestRunner.class'

if (-not (Test-Path $RunnerCls) -or (Get-Item $RunnerSrc).LastWriteTime -gt (Get-Item $RunnerCls).LastWriteTime) {
    Write-Host "Compiling test runner..."
    & $Javac -nowarn -cp $Jar -d $Build $RunnerSrc
    if ($LASTEXITCODE -ne 0) { throw "Failed to compile TestRunner.java" }
}

# --- assemble the load order -----------------------------------------------
# Stubs first, then translations, then the real PZAPI, then the library, then the
# mod under test, then the specs. Order matters: each layer depends on the last.

$LoadFiles = @()
$LoadFiles += Join-Path $Harness 'pz_stubs.lua'
$LoadFiles += Get-ChildItem (Join-Path $ModRoot '42\media\lua\shared\Translate\EN') -Filter *.json -ErrorAction SilentlyContinue |
              ForEach-Object { $_.FullName }
$LoadFiles += Join-Path $GameDir 'media\lua\client\PZAPI\ModOptions.lua'
$LoadFiles += Join-Path $Harness 'test_lib.lua'
# shared before client, the order the game itself uses. Translate holds .json so it is
# excluded by the .lua filter and loaded earlier.
$SharedLua = Join-Path $ModRoot '42\media\lua\shared'
if (Test-Path $SharedLua) {
    $LoadFiles += Get-ChildItem $SharedLua -Filter *.lua -Recurse |
                  Sort-Object Name | ForEach-Object { $_.FullName }
}

$LoadFiles += Get-ChildItem (Join-Path $ModRoot '42\media\lua\client') -Filter *.lua -Recurse |
              Sort-Object Name | ForEach-Object { $_.FullName }

# Singleplayer loads all three trees, so the harness does too. In a multiplayer
# client this one would not load, which is why balance logic belongs here.
$ServerLua = Join-Path $ModRoot '42\media\lua\server'
if (Test-Path $ServerLua) {
    $LoadFiles += Get-ChildItem $ServerLua -Filter *.lua -Recurse |
                  Sort-Object Name | ForEach-Object { $_.FullName }
}
# The mod source is common to every pass. Only the specs and the mod list change.
$ModFiles = $LoadFiles

foreach ($f in $ModFiles) {
    if (-not (Test-Path $f)) { throw "Missing file in load order: $f" }
}

# --- run -------------------------------------------------------------------
# Kahlua resolves stdlib.lua against the working directory, so run from the game dir.

# The exit code comes back through a script variable rather than the return value,
# because everything a PowerShell function writes to the output stream is part of what it
# returns. Returning the code would swallow the whole test report into it.
$script:PassCode = 0

function Invoke-Pass {
    param([string]$SpecDir, [string]$OtherMods)

    $files = $ModFiles + (Get-ChildItem $SpecDir -Filter *_spec.lua | Sort-Object Name |
             ForEach-Object { $_.FullName })

    $env:QOLC_MODS = $OtherMods
    Push-Location $GameDir
    try {
        & $Java -cp "$Jar;$Build" TestRunner $GameDir $ModRoot @files
        $script:PassCode = $LASTEXITCODE
    } finally {
        Pop-Location
        $env:QOLC_MODS = $null
    }
}

Invoke-Pass -SpecDir $Specs -OtherMods ''
$code = $script:PassCode

# Some guards decide at file scope whether a feature installs itself at all, so they can
# only be exercised by loading the whole mod again beside the mod they stand down for.
# One pass per such mod, each with its own specs.
$ConflictRoot = Join-Path $PSScriptRoot 'specs-conflicts'
if (Test-Path $ConflictRoot) {
    foreach ($dir in Get-ChildItem $ConflictRoot -Directory | Sort-Object Name) {
        Write-Host ""
        Write-Host "--- second pass, also loaded: $($dir.Name) ---"
        Write-Host ""

        Invoke-Pass -SpecDir $dir.FullName -OtherMods $dir.Name
        if ($script:PassCode -ne 0) { $code = $script:PassCode }
    }
}

exit $code
