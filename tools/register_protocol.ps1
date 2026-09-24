<#
.SYNOPSIS
    Registers the Scan Me! scanme:// URL protocol for the current user.
.DESCRIPTION
    Writes only HKCU\Software\Classes\scanme, so no administrator rights are
    required. Re-running this script updates the command idempotently. Use
    -DebugMode while diagnosing protocol launches to keep the PowerShell window
    open after a successful opener invocation.
#>
[CmdletBinding()]
param(
    [switch]$DebugMode
)

$ErrorActionPreference = 'Stop'

$protocolKey = 'HKCU:\Software\Classes\scanme'
$commandKey = Join-Path $protocolKey 'shell\open\command'
$openerPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath 'ScanMeOpener.ps1'))
$noExitOption = if ($DebugMode) { ' -NoExit' } else { '' }
$command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass' + $noExitOption + ' -File "' + $openerPath + '" "%1"'

New-Item -Path $protocolKey -Force | Out-Null
New-ItemProperty -Path $protocolKey -Name 'URL Protocol' -PropertyType String -Value '' -Force | Out-Null
New-Item -Path $commandKey -Force | Out-Null
Set-Item -Path $commandKey -Value $command

Write-Host "Registered scanme:// for the current user (no administrator rights required)." -ForegroundColor Green
Write-Host "Command: $command" -ForegroundColor DarkGray
if ($DebugMode) {
    Write-Host 'DEBUG MODE: -NoExit is enabled; close the PowerShell window manually when finished.' -ForegroundColor Yellow
}
else {
    Write-Host 'The first browser use may show an expected “Open this app / PowerShell?” confirmation.' -ForegroundColor Yellow
}
