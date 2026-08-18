#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Forces an Intune check-in on BOTH channels: the native MDM (OMA-DM) channel and the
    Intune Management Extension (IME).

.DESCRIPTION
    The admin center "Sync" action and the OMA-DM PushLaunch task only trigger the MDM channel.
    They do NOT force the IME (apps / scripts). This script triggers the MDM channel by running
    the enrollment PushLaunch scheduled task(s), and forces the IME by restarting its service.

.EXAMPLE
    .\Force-IntuneSync.ps1

.NOTES
    Restarting the IME service is safe but will briefly interrupt any in-progress app install.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

# 1. MDM channel: run the PushLaunch scheduled task(s) under EnterpriseMgmt
Write-Host "[*] Triggering MDM (OMA-DM) sync via PushLaunch scheduled task(s)..." -ForegroundColor Cyan
$enrollTasks = Get-ScheduledTask -TaskPath '\Microsoft\Windows\EnterpriseMgmt\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.TaskName -like 'PushLaunch*' -or $_.TaskName -like 'Schedule*' }

if ($enrollTasks) {
    foreach ($t in $enrollTasks) {
        try {
            Start-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName
            Write-Host "    [+] Started: $($t.TaskPath)$($t.TaskName)" -ForegroundColor Green
        } catch {
            Write-Warning "    Could not start $($t.TaskName): $($_.Exception.Message)"
        }
    }
} else {
    Write-Warning "No EnterpriseMgmt enrollment tasks found. Is the device enrolled?"
    Write-Host "    Tip: Settings > Accounts > Access work or school > Info > Sync" -ForegroundColor DarkGray
}

# 2. IME channel: restart the Intune Management Extension service
$svc = Get-Service -Name 'IntuneManagementExtension' -ErrorAction SilentlyContinue
if ($svc) {
    Write-Host "[*] Restarting IntuneManagementExtension service to force IME check-in..." -ForegroundColor Cyan
    Restart-Service -Name 'IntuneManagementExtension' -Force
    Write-Host "    [+] IME service restarted." -ForegroundColor Green
} else {
    Write-Warning "IntuneManagementExtension service not found (no Win32 apps/scripts assigned yet?)."
}

Write-Host "`n[DONE] Both channels triggered. Watch:" -ForegroundColor Green
Write-Host "   MDM     -> Event Viewer > DeviceManagement-Enterprise-Diagnostics-Provider" -ForegroundColor DarkGray
Write-Host "   IME     -> C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AppWorkload.log" -ForegroundColor DarkGray
