<#
.SYNOPSIS
    Manually tests the Scan Me! custom protocol opener in a visible PowerShell window.
.DESCRIPTION
    Encodes a local folder or file path, invokes ScanMeOpener.ps1 with the same
    scanme:// URL used by the exported HTML tree, and keeps the child PowerShell
    window open so the user can inspect success or error output.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TestPath
)

$ErrorActionPreference = 'Stop'
$openerPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath 'ScanMeOpener.ps1'))
$resolvedPath = (Resolve-Path -LiteralPath $TestPath -ErrorAction Stop).Path
$encodedPath = [System.Uri]::EscapeDataString($resolvedPath)
$protocolUrl = "scanme://open?path=$encodedPath"
$childArguments = '-NoProfile -ExecutionPolicy Bypass -NoExit -File "' + $openerPath + '" "' + $protocolUrl + '"'

Write-Host '=== Scan Me! Protocol Opener Manual Test ===' -ForegroundColor Cyan
Write-Host "Test path: $resolvedPath"
Write-Host "Protocol URL: $protocolUrl"
Write-Host 'The opener is running in a separate PowerShell window. It will stay open on success; press a key if an error is shown.' -ForegroundColor Yellow

$childProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList $childArguments -Wait -PassThru
exit $childProcess.ExitCode
