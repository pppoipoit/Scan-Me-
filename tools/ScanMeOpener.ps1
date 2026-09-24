<#
.SYNOPSIS
    Scan Me! scanme:// custom protocol opener.
.DESCRIPTION
    Validates a scanme://open?path=... URL and opens only an existing local
    Windows folder or file. The folder action uses Explorer; the file action
    uses Invoke-Item so Windows opens the default application.
#>
$ErrorActionPreference = 'Stop'
$logFile = $null

function Write-OpenerLog {
    param([Parameter(Mandatory = $true)][string]$Message)

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    try {
        Add-Content -LiteralPath $logFile -Value "[$timestamp] $Message" -Encoding UTF8
    }
    catch {
        [Console]::Error.WriteLine("ScanMeOpener: Unable to write log '$logFile': $($_.Exception.Message)")
    }
}

try {
    $logFile = Join-Path -Path $env:TEMP -ChildPath 'scanme_opener.log'
    $argumentSummary = if ($args.Count -eq 0) { '<none>' } else { ($args | ForEach-Object { "[$_]" }) -join ', ' }
    Write-OpenerLog "START: ScanMeOpener received arguments: $argumentSummary"

    # The registered command supplies exactly one argument. Reject missing or extra
    # arguments before parsing so this script has no alternate actions.
    Write-OpenerLog "VALIDATION: argument count = $($args.Count); expected = 1"
    if ($args.Count -ne 1) {
        throw 'Expected exactly one scanme://open?path=... URL argument.'
    }

    $receivedProtocolUrl = [string]$args[0]
    Write-OpenerLog "RECEIVED URL: $receivedProtocolUrl"

    # Windows URI normalization inserts '/' after an authority when it dispatches
    # scanme://open?path=... as scanme://open/?path=.... Normalize only that known
    # transport form before strict validation; every other malformed URL still fails.
    $protocolUrl = $receivedProtocolUrl -replace '^scanme://open/\?path=', 'scanme://open?path='
    if ($protocolUrl -ne $receivedProtocolUrl) {
        Write-OpenerLog "NORMALIZED WINDOWS URL: $protocolUrl"
    }

    $isProtocolUrl = $protocolUrl -match '^scanme://open\?path=([^?#&]*)$'
    Write-OpenerLog "VALIDATION: URL format = $isProtocolUrl"
    if (!$isProtocolUrl) {
        throw 'The URL must be exactly scanme://open?path=<encoded-path>.'
    }

    $encodedPath = $Matches[1]
    Write-OpenerLog "PARSED ENCODED PATH: $encodedPath"
    $hasPath = ![string]::IsNullOrWhiteSpace($encodedPath)
    Write-OpenerLog "VALIDATION: path value is non-empty = $hasPath"
    if (!$hasPath) {
        throw 'The path query value is empty.'
    }

    $hasInvalidEncoding = $encodedPath -match '%(?![0-9A-Fa-f]{2})'
    $hasQueryDelimiter = $encodedPath -match '[?#&]'
    Write-OpenerLog "VALIDATION: invalid URL encoding = $hasInvalidEncoding; query delimiter = $hasQueryDelimiter"
    if ($hasInvalidEncoding -or $hasQueryDelimiter) {
        throw 'The path query contains invalid URL encoding or delimiters.'
    }

    try {
        $path = [System.Uri]::UnescapeDataString($encodedPath)
    }
    catch {
        Write-OpenerLog 'VALIDATION: URL decoding failed'
        throw 'The path query could not be URL-decoded.'
    }
    Write-OpenerLog "PARSED PATH: $path"

    # Require a fully-qualified Windows drive or UNC path; do not accept drive-relative,
    # root-relative, URI, wildcard, or otherwise ambiguous paths.
    $isAbsolutePath = $path -match '^(?:[A-Za-z]:\\|\\\\)'
    Write-OpenerLog "VALIDATION: absolute Windows path = $isAbsolutePath"
    if (!$isAbsolutePath) {
        throw 'The decoded path is not an absolute Windows path.'
    }

    $pathExists = Test-Path -LiteralPath $path -PathType Any -ErrorAction Stop
    Write-OpenerLog "VALIDATION: path exists = $pathExists; path = $path"
    if (!$pathExists) {
        throw "The path does not exist: $path"
    }

    $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
    $itemType = if ($item.PSIsContainer) { 'folder' } else { 'file' }
    Write-OpenerLog "VALIDATION: resolved item type = $itemType; full path = $($item.FullName)"

    if ($item.PSIsContainer) {
        $explorerPath = Join-Path -Path $env:WINDIR -ChildPath 'explorer.exe'
        Write-OpenerLog "OPENING: folder with $explorerPath; argument = $($item.FullName)"
        Start-Process -FilePath $explorerPath -ArgumentList ('"{0}"' -f $item.FullName) -ErrorAction Stop | Out-Null
    }
    else {
        Write-OpenerLog "OPENING: file with Invoke-Item: $($item.FullName)"
        Invoke-Item -LiteralPath $item.FullName -ErrorAction Stop
    }

    Write-OpenerLog "SUCCESS: Opened $path"
    Write-Host "SUCCESS: Opened $path" -ForegroundColor Green
    return
}
catch {
    $errorMessage = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($logFile)) {
        $logFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'scanme_opener.log'
    }
    Write-OpenerLog "FAILURE: $errorMessage"
    Write-OpenerLog "ERROR TYPE: $($_.Exception.GetType().FullName)"
    Write-OpenerLog "STACK TRACE: $($_.ScriptStackTrace)"

    Write-Host "ScanMeOpener ERROR: $errorMessage" -ForegroundColor Red
    Write-Host "Details were written to: $logFile" -ForegroundColor Red
    Write-Host 'Press any key to exit...' -ForegroundColor Yellow
    try { $null = Read-Host } catch { }
    exit 1
}

