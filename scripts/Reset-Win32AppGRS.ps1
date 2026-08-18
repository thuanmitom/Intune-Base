#Requires -RunAsAdministrator
<#
.SYNOPSIS
    TEST DEVICES ONLY. Clears the Intune Management Extension Win32 app state and the Global
    Retry Schedule (GRS) cooldown, then restarts the IME so a failed Win32 app is re-evaluated
    immediately instead of waiting out the ~24h cooldown.

.DESCRIPTION
    After a failed install, the IME retries 3x at 5-minute intervals, then locks the app into a
    ~24h GRS cooldown, skipping it every sync. This script removes the cached Win32 app state
    under HKLM so the next check-in re-evaluates everything from scratch.

    IMPORTANT:
      * Clearing GRS only resets the RETRY TIMER. It does NOT fix the underlying failure —
        fix your detection rule / install command / return codes first.
      * The registry layout under Win32Apps shifts between IME versions. Run this on a TEST
        device, not in production.
      * This forces re-download and re-evaluation of ALL Win32 apps on the device.

.PARAMETER Confirm
    Safety switch. You must pass -IUnderstand to actually run the destructive step.

.EXAMPLE
    .\Reset-Win32AppGRS.ps1 -IUnderstand

.NOTES
    Community-documented behavior (Rudy Ooms / MSEndpointMgr). Verify against your build.
#>
[CmdletBinding()]
param(
    [switch]$IUnderstand
)

$regPath = 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps'
$service = 'IntuneManagementExtension'

if (-not $IUnderstand) {
    Write-Host @"
This will DELETE the cached Win32 app state under:
    $regPath
and restart the '$service' service. ALL Win32 apps will be re-evaluated and may re-download.

Run on a TEST device only. Re-run with -IUnderstand to proceed:
    .\Reset-Win32AppGRS.ps1 -IUnderstand
"@ -ForegroundColor Yellow
    return
}

$ErrorActionPreference = 'Stop'

# Backup the branch first
$backup = "C:\Temp\Win32Apps-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').reg"
New-Item -ItemType Directory -Path 'C:\Temp' -Force | Out-Null
Write-Host "[*] Backing up registry branch to $backup ..." -ForegroundColor Cyan
& reg.exe export 'HKLM\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps' $backup /y | Out-Null

Write-Host "[*] Stopping $service ..." -ForegroundColor Cyan
Stop-Service -Name $service -Force

Write-Host "[*] Removing Win32 app state (includes GRS cooldown keys) ..." -ForegroundColor Cyan
if (Test-Path $regPath) {
    Remove-Item "$regPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "    [+] Cleared." -ForegroundColor Green
} else {
    Write-Warning "    Path not found: $regPath (no Win32 apps cached?)"
}

Write-Host "[*] Starting $service ..." -ForegroundColor Cyan
Start-Service -Name $service

Write-Host "`n[DONE] Watch: C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AppWorkload.log" -ForegroundColor Green
Write-Host "       Backup saved at $backup" -ForegroundColor DarkGray
Write-Host "       Reminder: GRS reset != fix. Confirm your detection rule is correct." -ForegroundColor DarkGray
