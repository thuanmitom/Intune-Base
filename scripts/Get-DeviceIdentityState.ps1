<#
.SYNOPSIS
    Parses `dsregcmd /status` into the fields that matter for Intune troubleshooting and
    highlights likely identity problems.

.DESCRIPTION
    Reads join type (cloud-native / hybrid / registered), TPM protection, and PRT health.
    Flags a stale PRT (AzureAdPrtUpdateTime older than ~4 hours), which is a frequent root
    cause behind sync, sign-in and Conditional Access failures.

.EXAMPLE
    .\Get-DeviceIdentityState.ps1

.NOTES
    Read-only. Safe on production devices. No admin rights required for the summary.
#>
[CmdletBinding()]
param()

$raw = dsregcmd /status
$fields = @{}
foreach ($line in $raw) {
    if ($line -match '^\s*([A-Za-z0-9_ ]+?)\s*:\s*(.+?)\s*$') {
        $fields[$matches[1].Trim()] = $matches[2].Trim()
    }
}

function Get-Field($name) { if ($fields.ContainsKey($name)) { $fields[$name] } else { 'N/A' } }

$azureAdJoined  = Get-Field 'AzureAdJoined'
$domainJoined   = Get-Field 'DomainJoined'
$workplace      = Get-Field 'WorkplaceJoined'
$prt            = Get-Field 'AzureAdPrt'
$prtUpdate      = Get-Field 'AzureAdPrtUpdateTime'
$tpm            = Get-Field 'TpmProtected'

# Derive join type
$joinType = switch -Regex ("$azureAdJoined|$domainJoined") {
    'YES\|YES' { 'Hybrid Entra joined' ; break }
    'YES\|NO'  { 'Cloud-native (Entra joined)' ; break }
    default    { if ($workplace -eq 'YES') { 'Entra registered (BYOD)' } else { 'Not joined / unknown' } }
}

Write-Host "`n===== Device Identity Summary =====" -ForegroundColor Cyan
Write-Host ("  Join type            : {0}" -f $joinType)
Write-Host ("  AzureAdJoined        : {0}" -f $azureAdJoined)
Write-Host ("  DomainJoined         : {0}" -f $domainJoined)
Write-Host ("  WorkplaceJoined      : {0}" -f $workplace)
Write-Host ("  TpmProtected         : {0}" -f $tpm)
Write-Host ("  AzureAdPrt           : {0}" -f $prt)
Write-Host ("  AzureAdPrtUpdateTime : {0}" -f $prtUpdate)

Write-Host "`n===== Flags =====" -ForegroundColor Cyan
if ($prt -ne 'YES') {
    Write-Host "  [!] No PRT. SSO/compliance claims will fail. Lock/unlock, check the Entra device object, check TPM." -ForegroundColor Yellow
} else {
    # Try to parse the PRT update time and flag if older than ~4h
    $parsed = $null
    if ([datetime]::TryParse($prtUpdate, [ref]$parsed)) {
        $age = (Get-Date) - $parsed
        if ($age.TotalHours -gt 4) {
            Write-Host ("  [!] PRT last refreshed {0:N1}h ago (> 4h). PRT may be failing to refresh." -f $age.TotalHours) -ForegroundColor Yellow
            Write-Host "      Try: lock/unlock the device; confirm the Entra device object is enabled; check TPM." -ForegroundColor DarkGray
        } else {
            Write-Host ("  [+] PRT fresh ({0:N1}h old)." -f $age.TotalHours) -ForegroundColor Green
        }
    } else {
        Write-Host "  [+] PRT present (could not parse update time)." -ForegroundColor Green
    }
}
if ($tpm -ne 'YES') {
    Write-Host "  [!] Device key not TPM-protected. Check TPM 2.0 health (tpmtool getdeviceinformation)." -ForegroundColor Yellow
}

Write-Host "`n  Full output: dsregcmd /status" -ForegroundColor DarkGray
Write-Host "  See docs/08-identity-prt.md for interpretation.`n" -ForegroundColor DarkGray
