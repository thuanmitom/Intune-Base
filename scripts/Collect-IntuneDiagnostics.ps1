#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Collects a full Intune/MDM diagnostic package using the in-box MdmDiagnosticsTool,
    and copies the IME logs alongside it.

.DESCRIPTION
    Wraps MdmDiagnosticsTool.exe (ships with Windows) to gather enrollment, provisioning,
    Autopilot and TPM data into a single zip. Also snapshots the Intune Management Extension
    logs so app/script troubleshooting data is in one place. This is the same collection the
    Intune admin center "Collect diagnostics" action runs under the hood.

.PARAMETER OutputFolder
    Folder to write the diagnostic package to. Defaults to C:\Temp\IntuneDiag.

.PARAMETER Areas
    MdmDiagnosticsTool areas to collect. Defaults to the common set.

.EXAMPLE
    .\Collect-IntuneDiagnostics.ps1

.EXAMPLE
    .\Collect-IntuneDiagnostics.ps1 -OutputFolder D:\Diag -Areas "DeviceEnrollment;Autopilot;TPM"

.NOTES
    Read-only / collection only. Safe to run on production devices.
#>
[CmdletBinding()]
param(
    [string]$OutputFolder = 'C:\Temp\IntuneDiag',
    [string]$Areas        = 'DeviceEnrollment;DeviceProvisioning;Autopilot;TPM'
)

$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$dest  = Join-Path $OutputFolder $stamp
New-Item -ItemType Directory -Path $dest -Force | Out-Null

Write-Host "[*] Output: $dest" -ForegroundColor Cyan

# 1. MdmDiagnosticsTool package
$zip  = Join-Path $dest "MDMDiag-$stamp.zip"
$tool = Join-Path $env:SystemRoot 'System32\MdmDiagnosticsTool.exe'
if (Test-Path $tool) {
    Write-Host "[*] Running MdmDiagnosticsTool (areas: $Areas)..." -ForegroundColor Cyan
    & $tool -area $Areas -zip $zip
    Write-Host "[+] MDM diagnostic zip: $zip" -ForegroundColor Green
} else {
    Write-Warning "MdmDiagnosticsTool.exe not found at $tool"
}

# 2. IME logs snapshot (apps / scripts / remediations)
$imeLogs = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
if (Test-Path $imeLogs) {
    $imeDest = Join-Path $dest 'IME-Logs'
    New-Item -ItemType Directory -Path $imeDest -Force | Out-Null
    Copy-Item "$imeLogs\*" $imeDest -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[+] IME logs copied to: $imeDest" -ForegroundColor Green
} else {
    Write-Warning "IME logs folder not found (device may have no Win32 apps/scripts assigned yet)."
}

# 3. Quick identity snapshot for context
$idFile = Join-Path $dest 'dsregcmd-status.txt'
dsregcmd /status | Out-File -FilePath $idFile -Encoding utf8
Write-Host "[+] dsregcmd /status saved to: $idFile" -ForegroundColor Green

Write-Host "`n[DONE] Collected diagnostics under $dest" -ForegroundColor Green
Write-Host "       Read IME logs with CMTrace or https://cmtrace.dev" -ForegroundColor DarkGray
