<#
.SYNOPSIS
    Removes the Scan Me! scanme:// URL protocol registration for the current user.
#>
$ErrorActionPreference = 'Stop'

$protocolKey = 'HKCU:\Software\Classes\scanme'
if (Test-Path -LiteralPath $protocolKey) {
    Remove-Item -LiteralPath $protocolKey -Recurse -Force
    Write-Host 'Removed HKCU\Software\Classes\scanme for the current user.' -ForegroundColor Green
}
else {
    Write-Host 'scanme:// is not registered for the current user; nothing to remove.' -ForegroundColor Yellow
}
