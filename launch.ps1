<#
.SYNOPSIS
  Build and launch gyotaku-app from source.
.PARAMETER Once
  Pass --once: no resident process, exits when the window closes.
.PARAMETER Window
  Pass --window: an ordinary window instead of the floating launcher panel.
.PARAMETER Background
  Pass --background: start resident with no window (summon with Alt+Shift+S).
.PARAMETER Release
  Build and run the release profile.
.PARAMETER NoBuild
  Skip cargo build and run what is already in target.
.EXAMPLE
  .\launch.ps1
  .\launch.ps1 -Window -Once
#>
[CmdletBinding()]
param(
    [switch]$Once,
    [switch]$Window,
    [switch]$Background,
    [switch]$Release,
    [switch]$NoBuild
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$profileDir = if ($Release) { 'release' } else { 'debug' }
$exe = Join-Path $root "target\$profileDir\gyotaku-app.exe"

# A running copy from this repo's target dir locks the exe, so the build
# fails with "Access is denied". Stop only that copy, never an installed one.
Get-Process -Name 'gyotaku-app' -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -and $_.Path.StartsWith((Join-Path $root 'target'), [StringComparison]::OrdinalIgnoreCase) } |
    ForEach-Object {
        Write-Host "Stopping running dev build (PID $($_.Id))"
        Stop-Process -Id $_.Id -Force
    }

if (-not $NoBuild) {
    $cargoArgs = @('build', '-p', 'gyotaku-app')
    if ($Release) { $cargoArgs += '--release' }
    Push-Location $root
    try {
        & cargo @cargoArgs
        if ($LASTEXITCODE -ne 0) { throw "cargo build failed (exit $LASTEXITCODE)" }
    } finally {
        Pop-Location
    }
}

if (-not (Test-Path $exe)) { throw "Not found: $exe (run without -NoBuild)" }

$appArgs = @()
if ($Once) { $appArgs += '--once' }
if ($Window) { $appArgs += '--window' }
if ($Background) { $appArgs += '--background' }

# A source build has no onnxruntime.dll beside the exe, so OCR tries a download
# (which can 404 or be blocked). Reuse the installed copy's library instead.
if (-not $env:ORT_DYLIB_PATH) {
    $installed = Join-Path $env:LOCALAPPDATA 'Programs\gyotaku\onnxruntime.dll'
    $beside = Join-Path (Split-Path $exe) 'onnxruntime.dll'
    if (-not (Test-Path $beside) -and (Test-Path $installed)) {
        $env:ORT_DYLIB_PATH = $installed
        Write-Host "Using ONNX Runtime from $installed"
    }
}

Write-Host "Launching $exe $($appArgs -join ' ')"
if ($appArgs.Count -gt 0) {
    Start-Process -FilePath $exe -ArgumentList $appArgs -WorkingDirectory $root
} else {
    Start-Process -FilePath $exe -WorkingDirectory $root
}
