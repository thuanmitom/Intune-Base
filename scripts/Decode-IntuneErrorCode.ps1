<#
.SYNOPSIS
    Decodes an Intune / Windows error code (portal decimal, hex, or signed int) into its
    hex form, plain-English Win32 text, and — for configuration-profile codes — the underlying
    SyncML status.

.DESCRIPTION
    Intune surfaces errors in several shapes:
      * A signed decimal in the portal (e.g. -2016345708)
      * A hex HRESULT (e.g. 0x87D10194)
      * A raw Win32 code (e.g. 5)
    This helper normalises the input, prints the hex, tries to resolve the Win32 message, and
    applies the config-profile rule (0x87D10000 + SyncML status) to reveal the SyncML code.

.PARAMETER Code
    The error code, as a string. Accepts decimal, signed decimal, or 0x-prefixed hex.

.EXAMPLE
    .\Decode-IntuneErrorCode.ps1 -Code -2016345708
    .\Decode-IntuneErrorCode.ps1 -Code 0x87D1041C
    .\Decode-IntuneErrorCode.ps1 -Code 0x80070005

.NOTES
    Offline. No network required. For the fullest lookup, cross-reference
    troubleshooting/error-code-reference.md.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Code
)

# --- Normalise input to a UInt32 ---
$u = $null
try {
    if ($Code -match '^0x') {
        $u = [uint32]("0x" + ($Code -replace '^0x','')) 
    } else {
        # Could be signed decimal (portal) or plain decimal
        $long = [int64]$Code
        if ($long -lt 0) { $long = $long + 4294967296 }  # wrap signed int32 -> uint32
        $u = [uint32]$long
    }
} catch {
    Write-Error "Could not parse '$Code' as a number."
    return
}

$hex = ('0x{0:X8}' -f $u)
Write-Host "`n===== Error Code Decode =====" -ForegroundColor Cyan
Write-Host ("  Input        : {0}" -f $Code)
Write-Host ("  Unsigned     : {0}" -f $u)
Write-Host ("  Hex          : {0}" -f $hex)

# --- Family hint ---
$family = switch -Regex ($hex) {
    '^0x8018'    { 'Enrollment / MDM (MENROLL) - check Event Viewer Event 76' ; break }
    '^0x87D1'    { 'Win32 app - check IME AppWorkload.log' ; break }
    '^0x87D3'    { 'Win32 app install/process phase - check AppWorkload.log' ; break }
    '^0x80072F'  { 'WinHTTP / certificate / TLS - sync & check-in' ; break }
    '^0x801C'    { 'Entra join / device registration - dsregcmd, AAD Operational log' ; break }
    default      { $null }
}
if ($family) { Write-Host ("  Family hint  : {0}" -f $family) -ForegroundColor Yellow }

# --- Config-profile rule: 0x87D10000 + SyncML status ---
# Use explicit UInt32 bases (hex literals > 0x7FFFFFFF are treated as signed Int32 by PowerShell,
# so compute the bounds with Convert to stay unsigned).
$cfgBase = [Convert]::ToUInt32('87D10000', 16)   # 2278621184
$cfgTop  = [Convert]::ToUInt32('87D1FFFF', 16)
if ($u -ge $cfgBase -and $u -le $cfgTop) {
    $syncml = [int]($u - $cfgBase)
    $meaning = switch ($syncml) {
        404 { 'CSP node not found / not applicable to this platform or Windows edition' }
        405 { 'Wrote to a read-only node' }
        418 { 'Node already exists' }
        500 { 'Server/CSP failure (often benign & transient on firewall settings right after boot)' }
        default { 'See SyncML status references' }
    }
    Write-Host ("  SyncML status: {0}  ->  {1}" -f $syncml, $meaning) -ForegroundColor Green
    Write-Host "               (Only valid if this is a CONFIGURATION PROFILE error. The 0x87D1xxxx" -ForegroundColor DarkGray
    Write-Host "                range is shared with Win32 app codes like 0x87D1041C - if this is an" -ForegroundColor DarkGray
    Write-Host "                app error, ignore the SyncML line and see the Win32 app table.)" -ForegroundColor DarkGray
}

# --- Win32 plain-English text (best effort) ---
# Reinterpret the UInt32 bits as Int32 (unchecked) so HRESULTs like 0x80070005 don't overflow
# a value cast. Win32Exception expects the signed HRESULT/Win32 integer.
try {
    $asInt32 = [BitConverter]::ToInt32([BitConverter]::GetBytes($u), 0)
    $msg = ([ComponentModel.Win32Exception]$asInt32).Message
    if ($msg -and $msg -notmatch 'Unknown error') {
        Write-Host ("  Win32 text   : {0}" -f $msg) -ForegroundColor Green
    }
} catch { }

Write-Host "`n  Cross-reference: troubleshooting/error-code-reference.md`n" -ForegroundColor DarkGray
