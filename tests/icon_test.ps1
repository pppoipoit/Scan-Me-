<#
.SYNOPSIS
    Verification test for canonical Scan Me! icon unification.
.DESCRIPTION
    Automates:
      (a) XAML has no header lightning bolt/Path/Viewbox and has the 40x40 AppLogo Image.
      (b) Startup P/Invoke appears before the WPF window is shown, in both run modes.
      (c) ScanMe.exe associated icon exports to PNG and matches assets\app.ico
          at the same 32px rendered frame by SHA-256 pixel hash.
    Exit code 0 = ALL PASS, 1 = FAIL.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$failCount = 0

function Assert-Test {
    param([string]$Name, [bool]$Ok, [string]$Detail = '')
    if ($Ok) { Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { Write-Host "  [FAIL] $Name  $Detail" -ForegroundColor Red; $script:failCount++ }
}

function Get-PixelHash {
    param([System.Drawing.Bitmap]$Bitmap)
    $rect = [System.Drawing.Rectangle]::new(0, 0, $Bitmap.Width, $Bitmap.Height)
    $lock = $Bitmap.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $bytes = New-Object byte[] ($lock.Stride * $lock.Height)
        [System.Runtime.InteropServices.Marshal]::Copy($lock.Scan0, $bytes, 0, $bytes.Length)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '') }
        finally { $sha.Dispose() }
    }
    finally { $Bitmap.UnlockBits($lock) }
}

Write-Host '=== Canonical Icon Unification Test ===' -ForegroundColor Cyan
Add-Type -AssemblyName System.Drawing

$xamlPath = Join-Path $root 'src\gui\MainWindow.xaml'
$startupPath = Join-Path $root 'src\gui\MainWindow.ps1'
$buildPath = Join-Path $root 'build_exe.ps1'
$exePath = Join-Path $root 'ScanMe.exe'
$assetPath = Join-Path $root 'assets\app.ico'

# (a) Static XAML checks.
$xaml = [System.IO.File]::ReadAllText($xamlPath)
$headerMatch = [regex]::Match($xaml, '(?s)<!-- 1\. Header Section -->(.*?)<!-- 2\. Stat Cards Grid -->')
$header = if ($headerMatch.Success) { $headerMatch.Groups[1].Value } else { '' }
Assert-Test 'Header section found' $headerMatch.Success
Assert-Test 'No lightning bolt glyph in XAML' (-not $xaml.Contains('⚡'))
Assert-Test 'No Path or Viewbox in header' (-not ($header -match '<Path\b|<Viewbox\b'))
Assert-Test 'AppLogo Image exists at approximately 40x40' ($xaml -match '<Image\s+x:Name="AppLogo"\s+Width="40"\s+Height="40"')

# (b) Static startup ordering checks.
$startup = [System.IO.File]::ReadAllText($startupPath)
$build = [System.IO.File]::ReadAllText($buildPath)
$psInvoke = $startup.IndexOf('SetCurrentProcessExplicitAppUserModelID')
$psShow = $startup.IndexOf('$window.ShowDialog')
$buildInvoke = $build.IndexOf('SetCurrentProcessExplicitAppUserModelID(appUserModelId)')
$buildStart = $build.IndexOf('Process.Start(psi)')
Assert-Test 'PowerShell startup calls AppUserModelID before ShowDialog' ($psInvoke -ge 0 -and $psShow -gt $psInvoke) "invoke=$psInvoke show=$psShow"
Assert-Test 'Compiled launcher calls AppUserModelID before child start' ($buildInvoke -ge 0 -and $buildStart -gt $buildInvoke) "invoke=$buildInvoke start=$buildStart"
Assert-Test 'Canonical fallback chain is assets\app.ico' (($startup -match 'assets\\app\.ico') -and ($startup -match 'SCANME_EXE_PATH') -and ($startup -match '\$PSScriptRoot'))

# (c) Programmatic executable icon comparison.
$tempPng = Join-Path $env:TEMP ("ScanMe_icon_{0}.png" -f [guid]::NewGuid().ToString('N'))
$associatedIcon = $null
$associatedBitmap = $null
$canonicalIcon = $null
$canonicalBitmap = $null
$exportedBitmap = $null
try {
    Assert-Test 'Canonical assets\app.ico exists' (Test-Path -LiteralPath $assetPath) $assetPath
    Assert-Test 'ScanMe.exe exists' (Test-Path -LiteralPath $exePath) $exePath

    $associatedIcon = [System.Drawing.Icon]::ExtractAssociatedIcon($exePath)
    Assert-Test 'ExtractAssociatedIcon returned an icon' ($null -ne $associatedIcon)
    if (!$associatedIcon) { throw 'Associated icon extraction returned null.' }
    $associatedBitmap = $associatedIcon.ToBitmap()
    $associatedBitmap.Save($tempPng, [System.Drawing.Imaging.ImageFormat]::Png)
    $exportedBitmap = [System.Drawing.Bitmap]::FromFile($tempPng)

    # Icon(path, 32, 32) selects the same 32px frame used by ExtractAssociatedIcon.
    $canonicalIcon = [System.Drawing.Icon]::new($assetPath, 32, 32)
    $canonicalBitmap = $canonicalIcon.ToBitmap()
    $associatedHash = Get-PixelHash $exportedBitmap
    $canonicalHash = Get-PixelHash $canonicalBitmap
    Write-Host "  Associated icon: $($exportedBitmap.Width)x$($exportedBitmap.Height) pixelHash=$associatedHash"
    Write-Host "  Canonical app.ico: $($canonicalBitmap.Width)x$($canonicalBitmap.Height) pixelHash=$canonicalHash"
    Assert-Test 'Exported executable icon pixel hash matches app.ico' ($associatedHash -eq $canonicalHash) "associated=$associatedHash canonical=$canonicalHash"
}
catch {
    Assert-Test 'Icon extraction/export/comparison' $false $_.Exception.Message
}
finally {
    if ($exportedBitmap) { $exportedBitmap.Dispose() }
    if ($canonicalBitmap) { $canonicalBitmap.Dispose() }
    if ($associatedBitmap) { $associatedBitmap.Dispose() }
    if ($associatedIcon) { $associatedIcon.Dispose() }
    if ($canonicalIcon) { $canonicalIcon.Dispose() }
    Remove-Item -LiteralPath $tempPng -Force -ErrorAction SilentlyContinue
}

if ($failCount -eq 0) {
    Write-Host "`nALL TESTS PASSED" -ForegroundColor Green
    exit 0
}
Write-Host "`n$failCount TEST(S) FAILED" -ForegroundColor Red
exit 1