<#
.SYNOPSIS
    Diagnoses the Scan Me! scanme:// custom protocol registration and opener.
.DESCRIPTION
    Checks the current-user registry registration, verifies a supplied local path,
    invokes ScanMeOpener.ps1 in a child PowerShell process, and prints the opener
    log for inspection.
#>
[CmdletBinding()]
param(
    [string]$TestPath = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$protocolKey = 'HKCU:\Software\Classes\scanme'
$commandKey = Join-Path $protocolKey 'shell\open\command'
$openerPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath 'ScanMeOpener.ps1'))
$logFile = Join-Path -Path $env:TEMP -ChildPath 'scanme_opener.log'
$diagnosticFailed = $false

function Write-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Details = ''
    )

    if ($Passed) {
        Write-Host "[PASS] $Name" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] $Name $Details" -ForegroundColor Red
        $script:diagnosticFailed = $true
    }
}

Write-Host '=== Scan Me! Protocol Diagnostic ===' -ForegroundColor Cyan
Write-Host "Opener: $openerPath"
Write-Host "Log:    $logFile"

$protocolExists = Test-Path -LiteralPath $protocolKey
Write-Check 'HKCU protocol key exists' $protocolExists
if ($protocolExists) {
    try {
        $protocolProperties = Get-ItemProperty -LiteralPath $protocolKey -Name 'URL Protocol' -ErrorAction Stop
        $hasUrlProtocol = $protocolProperties.PSObject.Properties.Name -contains 'URL Protocol'
        Write-Check 'URL Protocol value exists' $hasUrlProtocol
    }
    catch {
        Write-Check 'URL Protocol value exists' $false $_.Exception.Message
    }

    try {
        $commandProperties = Get-ItemProperty -LiteralPath $commandKey -ErrorAction Stop
        $registeredCommand = [string]$commandProperties.'(default)'
        $hasRegisteredCommand = -not [string]::IsNullOrWhiteSpace($registeredCommand)
        Write-Check 'Registered command exists' $hasRegisteredCommand "Command: $registeredCommand"
        Write-Host "Registered command: $registeredCommand" -ForegroundColor DarkGray
    }
    catch {
        Write-Check 'Registered command exists' $false $_.Exception.Message
    }
}
else {
    Write-Host 'The protocol is not registered for the current user. Run tools\register_protocol.ps1.' -ForegroundColor Yellow
}

$resolvedTestPath = $null
try {
    $resolvedTestPath = (Resolve-Path -LiteralPath $TestPath -ErrorAction Stop).Path
    $pathExists = Test-Path -LiteralPath $resolvedTestPath -PathType Any -ErrorAction Stop
    Write-Check 'Test path exists' $pathExists "Path: $resolvedTestPath"
    if (!$pathExists) {
        $diagnosticFailed = $true
    }
}
catch {
    Write-Check 'Test path exists' $false $_.Exception.Message
}

if ($null -ne $resolvedTestPath) {
    $encodedPath = [System.Uri]::EscapeDataString($resolvedTestPath)
    $protocolUrl = "scanme://open?path=$encodedPath"
    $childArguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $openerPath + '" "' + $protocolUrl + '"'

    Write-Host "Testing opener URL: $protocolUrl" -ForegroundColor DarkGray
    try {
        $childProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList $childArguments -Wait -PassThru
        Write-Check 'Opener process completed successfully' ($childProcess.ExitCode -eq 0) "Exit code: $($childProcess.ExitCode)"
    }
    catch {
        Write-Check 'Opener process started and completed' $false $_.Exception.Message
    }
}

Write-Host "`n=== Opener log: $logFile ===" -ForegroundColor Cyan
if (Test-Path -LiteralPath $logFile -PathType Leaf) {
    try {
        Get-Content -LiteralPath $logFile
    }
    catch {
        Write-Host "Unable to read log: $($_.Exception.Message)" -ForegroundColor Red
        $diagnosticFailed = $true
    }
}
else {
    Write-Host 'Log file does not exist yet.' -ForegroundColor Yellow
    $diagnosticFailed = $true
}

if ($diagnosticFailed) {
    Write-Host "`nDIAGNOSTIC FOUND PROBLEMS." -ForegroundColor Red
    exit 1
}

Write-Host "`nDIAGNOSTIC PASSED." -ForegroundColor Green
exit 0
