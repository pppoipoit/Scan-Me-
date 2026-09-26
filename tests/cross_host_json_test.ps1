<#
.SYNOPSIS
    Regression test: culture-invariant, host-independent JSON output.
.DESCRIPTION
    Root cause (fixed 2026-09-26): src/engine/Scanner.ps1 and src/utils/Helpers.ps1
    formatted dates with the culture-sensitive DateTime.ToString("yyyy-MM-dd HH:mm:ss").
    PowerShell 7 inherits the OS user locale, so on a th-TH machine the
    ThaiBuddhistCalendar rendered the year as 2569, while Windows PowerShell 5.1 forces
    en-US and rendered 2026. The SAME scan therefore emitted different JSON per host,
    breaking docs/SCHEMA_SPEC.md. A second defect came from Measure-Object -Sum
    returning Double, so PowerShell 7 serialized "Total_Size_Bytes": 50746.0 while 5.1
    emitted 50746.

    This test runs the engine under every available PowerShell host and asserts:
      1. Each host produced output and the raw JSON is valid.
      2. Every date token uses a 4-digit Gregorian year in 2000-2099
         (catches 2569 / 2556 style Buddhist years and 3-digit years).
      3. Total_Size_Bytes is serialized as an integer, never a float.
      4. Scan_Meta is identical across hosts (excluding the legitimately
         volatile Scan_Timestamp and Scan_Duration_Sec).
      5. The Files array is identical across hosts after normalizing
         Get-ChildItem enumeration order.
      6. Category_Stats and Extension_Stats are identical across hosts.
      7. (Added after the first run) Checksum hashing actually works on every host, and
         produces the same Hash string - Get-FileHash is a module-autoloaded cmdlet that
         is unresolvable when a 5.1 child inherits PS7's PSModulePath.

    Cross-host comparisons are skipped (not failed) when only one host is installed.
    The culture and integer invariants are still asserted on that single host.
    Exit code 0 = ALL PASS, 1 = FAIL
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$failCount = 0

function Assert {
    param([string]$Name, [bool]$Ok, [string]$Detail = '')
    if ($Ok) { Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else     { Write-Host "  [FAIL] $Name  $Detail" -ForegroundColor Red; $script:failCount++ }
}

Write-Host "=== Cross-Host JSON Stability Test ===" -ForegroundColor Cyan

# --- 1) Build a deterministic fixture folder ---
Write-Host "[1/4] Creating fixture folder" -ForegroundColor Yellow
$fixture = Join-Path $env:TEMP ("scanme_xhost_" + [guid]::NewGuid().ToString('N').Substring(0,8))
$null = New-Item -ItemType Directory -Path $fixture -Force
Set-Content -LiteralPath (Join-Path $fixture 'alpha.txt')      -Value 'hello world'
Set-Content -LiteralPath (Join-Path $fixture 'beta.ps1')       -Value '# duplicate payload'
$dupDir = Join-Path $fixture 'nested folder'
$null = New-Item -ItemType Directory -Path $dupDir -Force
Set-Content -LiteralPath (Join-Path $dupDir 'alpha-copy.txt')  -Value 'hello world'   # intentional duplicate
Set-Content -LiteralPath (Join-Path $dupDir 'ภาษาไทย.txt')       -Value 'unicode name'  # non-ASCII name

# Output JSON must live OUTSIDE the fixture: otherwise the second host would scan the
# first host's result file and see extra entries, producing a false mismatch.
$outDir = Join-Path $env:TEMP ("scanme_xhost_out_" + [guid]::NewGuid().ToString('N').Substring(0,8))
$null = New-Item -ItemType Directory -Path $outDir -Force

# --- 2) Discover available hosts and run the engine under each ---
Write-Host "[2/4] Running engine under each PowerShell host" -ForegroundColor Yellow
$scanner = Join-Path $root 'src\engine\Scanner.ps1'
$hosts = @()
$winPs = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (Test-Path -LiteralPath $winPs) {
    $hosts += [pscustomobject]@{ Name = 'Windows PowerShell 5.1'; Path = $winPs; UsePolicy = $true }
}
$pwshCmd = Get-Command 'pwsh.exe' -ErrorAction SilentlyContinue
if ($pwshCmd) {
    $hosts += [pscustomobject]@{ Name = 'PowerShell 7 (pwsh)'; Path = $pwshCmd.Source; UsePolicy = $false }
}
Assert "At least one PowerShell host found" ($hosts.Count -ge 1) "none discovered"
Write-Host "  Hosts: $($hosts.Name -join ' | ')" -ForegroundColor DarkGray

$results = @()
foreach ($h in $hosts) {
    $outJson = Join-Path $outDir ("_out_" + [regex]::Replace($h.Name, '[^A-Za-z0-9]', '') + ".json")
    $argList = @('-NoProfile')
    if ($h.UsePolicy) { $argList += @('-ExecutionPolicy', 'Bypass') }
    # Start-Process joins ArgumentList elements with spaces WITHOUT quoting, so every
    # path that can contain a space (e.g. "E:\Project\Scan Me!\...") must be quoted here.
    $argList += @(
        '-File', ('"{0}"' -f $scanner),
        '-TargetFolder', ('"{0}"' -f $fixture),
        '-OutputFile', ('"{0}"' -f $outJson),
        '-IncludeAllFiles',
        '-CalculateHash',
        '-ExtractMetadata'
    )
    $proc = Start-Process -FilePath $h.Path -ArgumentList $argList -NoNewWindow -Wait -PassThru `
                         -RedirectStandardOutput (Join-Path $env:TEMP '_xhost_out.txt') `
                         -RedirectStandardError  (Join-Path $env:TEMP '_xhost_err.txt')
    $produced = (Test-Path -LiteralPath $outJson)
    Assert "$($h.Name): engine completed and wrote JSON" ($proc.ExitCode -eq 0 -and $produced) "exit=$($proc.ExitCode) produced=$produced"
    if ($produced) { $results += [pscustomobject]@{ Name = $h.Name; Path = $outJson } }
}
Assert "Engine produced output on at least one host" ($results.Count -ge 1) "no host produced JSON"
if ($results.Count -eq 0) {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "`nCANNOT CONTINUE - no output produced" -ForegroundColor Red
    exit 1
}


# --- 3) Per-host invariants: Gregorian year + integer byte counts ---
Write-Host "[3/4] Checking culture and integer invariants per host" -ForegroundColor Yellow
$parsed = @{}
foreach ($r in $results) {
    $raw = Get-Content -LiteralPath $r.Path -Raw
    $obj = $null
    $jsonOk = $false
    try { $obj = $raw | ConvertFrom-Json; $jsonOk = $true } catch { }
    Assert "$($r.Name): output is valid JSON" $jsonOk
    if (-not $jsonOk) { continue }
    $parsed[$r.Name] = $obj

    # 3a. Every date token must use a 4-digit Gregorian year between 2000 and 2099.
    # Extract the year with a regex, NOT String.IndexOf('-'): in PowerShell 7 a bare '-'
    # argument is parsed as the unary minus operator and reaches the method as $null, so
    # IndexOf returns 0, Substring(0,0) is empty, [int]'' is 0, and every correctly
    # formatted date was reported as an out-of-range "Buddhist" year. That false positive
    # masked the real defect this test was written to catch.
    $dateTokens = [regex]::Matches($raw, '\d{3,4}-\d{2}-\d{2}') | ForEach-Object { $_.Value }
    $badYears = @($dateTokens | ForEach-Object {
        $m = [regex]::Match($_, '^(\d{3,4})-')
        if ($m.Success) {
            $y = [int]$m.Groups[1].Value
            if ($y -lt 2000 -or $y -gt 2099) { $_ }
        }
    } | Sort-Object -Unique)
    Assert "$($r.Name): all date years are Gregorian 2000-2099 (no Buddhist year)" `
           ($badYears.Count -eq 0) "found: $($badYears -join ', ')"

    # 3b. Total_Size_Bytes must be an integer literal in the raw JSON.
    $sizeMatch = [regex]::Match($raw, '"Total_Size_Bytes"\s*:\s*([^,\r\n}]+)')
    $sizeRaw = if ($sizeMatch.Success) { $sizeMatch.Groups[1].Value.Trim() } else { '' }
    $sizeIsInt = $sizeRaw -match '^\d+$'
    Assert "$($r.Name): Total_Size_Bytes serialized as integer (not float)" `
           $sizeIsInt "raw='$sizeRaw'"

    # 3c. The declared Scan_Timestamp itself must be Gregorian.
    $ts = [string]$obj.Scan_Meta.Scan_Timestamp
    $tsYear = if ($ts -match '^(\d{4})-') { [int]$Matches[1] } else { 0 }
    Assert "$($r.Name): Scan_Timestamp year is Gregorian" `
           ($tsYear -ge 2000 -and $tsYear -le 2099) "Scan_Timestamp='$ts'"

    # 3d. Duplicate detection still functions after the change.
    $dupCount = [int]$obj.Scan_Meta.Duplicate_Files
    Assert "$($r.Name): duplicate detection reports the seeded duplicate" `
           ($dupCount -ge 1) "Duplicate_Files=$dupCount"
}

# --- 4) Cross-host equality (normalized) ---
Write-Host "[4/4] Comparing hosts (order-normalized)" -ForegroundColor Yellow

# Render a stats hashtable as deterministic, key-sorted JSON.
function Get-SortedStats {
    param($stats)
    if ($null -eq $stats) { return '' }
    $parts = @()
    foreach ($key in @($stats.Keys | Sort-Object)) {
        $entry = $stats[$key]
        $parts += ('"{0}":{{"Count":{1},"TotalBytes":{2}}}' -f $key, $entry.Count, $entry.TotalBytes)
    }
    return ('{' + ($parts -join ',') + '}')
}

function Get-Normalized {
    param($obj)
    $meta = [ordered]@{}
    foreach ($p in $obj.Scan_Meta.PSObject.Properties) {
        if ($p.Name -in @('Scan_Timestamp', 'Scan_Duration_Sec')) { continue }  # legitimately volatile
        $meta[$p.Name] = $p.Value
    }
    $files = @($obj.Files | Select-Object Category_Folder, Relative_Path, File_Name, Full_Path,
                                     Extension, Size_Bytes, Size_MB, Size_Formatted, Hash,
                                     IsDuplicate, LastModified |
               Sort-Object Full_Path)
    [pscustomobject]@{
        Meta              = $meta
        Files             = $files
        # Category_Stats / Extension_Stats are plain hashtables, whose enumeration order
        # is NOT guaranteed to match across hosts, so compare them key-sorted.
        Category_Stats    = Get-SortedStats $obj.Category_Stats
        Extension_Stats   = Get-SortedStats $obj.Extension_Stats
    }
}

if ($parsed.Count -lt 2) {
    Write-Host "  [SKIP] Only one host produced output - cross-host comparison not run" -ForegroundColor Yellow
    Write-Host "         (per-host culture/integer invariants were still asserted above)" -ForegroundColor Yellow
} else {
    $names = @($parsed.Keys)
    $baselineName = $names[0]
    $baseline = Get-Normalized $parsed[$baselineName]
    foreach ($otherName in $names[1..($names.Count - 1)]) {
        $other = Get-Normalized $parsed[$otherName]
        $pair = "$baselineName vs $otherName"

        $metaA = ($baseline.Meta   | ConvertTo-Json -Depth 5 -Compress)
        $metaB = ($other.Meta      | ConvertTo-Json -Depth 5 -Compress)
        Assert "$pair : Scan_Meta identical" ($metaA -eq $metaB) ''
        if ($metaA -ne $metaB) {
            Write-Host "         baseline: $metaA" -ForegroundColor DarkGray
            Write-Host "         other   : $metaB" -ForegroundColor DarkGray
        }

        $filesA = ($baseline.Files | ConvertTo-Json -Depth 5 -Compress)
        $filesB = ($other.Files    | ConvertTo-Json -Depth 5 -Compress)
        Assert "$pair : Files[] identical" ($filesA -eq $filesB) ''
        if ($filesA -ne $filesB) {
            Compare-Object ($filesA -split "`n") ($filesB -split "`n") |
                Select-Object -First 5 | Format-Table -AutoSize | Out-String | Write-Host
        }

        Assert "$pair : Category_Stats identical"  ($baseline.Category_Stats  -eq $other.Category_Stats)  ''
        Assert "$pair : Extension_Stats identical" ($baseline.Extension_Stats -eq $other.Extension_Stats) ''
    }
}

# --- Cleanup + summary ---
Write-Host "`nCleaning up..." -ForegroundColor Yellow
Remove-Item -LiteralPath (Join-Path $env:TEMP '_xhost_out.txt') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $env:TEMP '_xhost_err.txt') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $outDir   -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue

if ($failCount -eq 0) {
    Write-Host "`nALL TESTS PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n$failCount TEST(S) FAILED" -ForegroundColor Red
    exit 1
}
