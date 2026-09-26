<#
.SYNOPSIS
    Scan Me! - Core Scanning Engine
.DESCRIPTION
    Performs recursive directory scanning, categorization, metadata extraction,
    duplicate detection, and JSON/CSV export.
#>

param (
    [Parameter(Mandatory = $false)]
    [string]$TargetFolder,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile,

    [Parameter(Mandatory = $false)]
    [string[]]$Extensions = @("*.*"),

    [Parameter(Mandatory = $false)]
    [switch]$IncludeAllFiles,

    [Parameter(Mandatory = $false)]
    [switch]$CalculateHash,

    [Parameter(Mandatory = $false)]
    [ValidateSet("MD5", "SHA256")]
    [string]$HashAlgorithm = "MD5",

    [Parameter(Mandatory = $false)]
    [switch]$ExtractMetadata,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeHiddenFiles,

    [Parameter(Mandatory = $false)]
    [scriptblock]$OnProgressUpdate
)

$projectRoot = Split-Path -Path $PSScriptRoot -Parent | Split-Path -Parent
if ([string]::IsNullOrWhiteSpace($TargetFolder)) {
    $TargetFolder = $projectRoot
}
if ([string]::IsNullOrWhiteSpace($OutputFile)) {
    $OutputFile = Join-Path -Path $projectRoot -ChildPath "output\scan_result.json"
}

# Load Utilities
$utilsPath = Join-Path -Path $PSScriptRoot -ChildPath "..\utils\Helpers.ps1"
if (Test-Path -Path $utilsPath) {
    . $utilsPath
}

function Invoke-DirectoryScan {
    param (
        [string]$TargetFolder,
        [string[]]$Extensions,
        [bool]$IncludeAll,
        [bool]$CalcHash,
        [string]$Algorithm = "MD5",
        [bool]$GetMeta,
        [bool]$HiddenFiles,
        [scriptblock]$ProgressCallback
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    if (!(Test-Path -LiteralPath $TargetFolder)) {
        throw "Target folder does not exist: $TargetFolder"
    }

    $fileList = [System.Collections.Generic.List[PSCustomObject]]::new()
    $hashLookup = @{}
    $duplicateCount = 0
    $duplicateWastedBytes = [int64]0
    $categorySummary = @{}
    $extensionSummary = @{}

    # Determine filter list
    $filterList = if ($IncludeAll -or ($Extensions -contains "*.*") -or ($Extensions.Count -eq 0)) {
        @("*.*")
    } else {
        $Extensions | ForEach-Object { if ($_ -notlike "*.*") { "*.$_" } else { $_ } }
    }

    # Fetch Files
    $gciParams = @{
        LiteralPath = $TargetFolder
        Recurse     = $true
        File        = $true
        ErrorAction = 'SilentlyContinue'
    }

    if ($HiddenFiles) {
        $gciParams['Force'] = $true
    }

    $rawFiles = Get-ChildItem @gciParams

    # Filter by extensions if not all
    if (!$IncludeAll -and !($filterList -contains "*.*")) {
        $cleanExts = $filterList | ForEach-Object { $_.TrimStart('*').ToLower() }
        $rawFiles = $rawFiles | Where-Object { $cleanExts -contains $_.Extension.ToLower() }
    }

    $totalDiscovered = [int]($rawFiles.Count)
    $currentIndex = 0

    foreach ($file in $rawFiles) {
        $currentIndex++
        
        # Category Folder: Relative path or Immediate Parent Folder
        $catFolder = if ($file.Directory) { $file.Directory.Name } else { "Root" }
        # Case-insensitive, separator-normalized prefix strip. String.Replace() is ordinal
        # (case-sensitive), so a scan target whose casing differs from the filesystem's
        # canonical casing (e.g. 'e:' vs 'E:') used to leave an ABSOLUTE Relative_Path,
        # which Build-FolderTreeHierarchy then split into bogus E: > Project > ... folders.
        $targetNorm = ([string]$TargetFolder).Replace('/', '\').TrimEnd('\')
        $fullNorm = ([string]$file.FullName)
        $relPath = if ($fullNorm.StartsWith($targetNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
            $fullNorm.Substring($targetNorm.Length).TrimStart('\', '/')
        } else {
            # Fallback: keep previous behavior when the path is not under the target root
            $fullNorm.TrimStart('\', '/')
        }

        $fileSize = [int64]$file.Length
        $fileSizeMB = ConvertTo-StableNumber ([math]::Round($fileSize / 1MB, 2))
        $formattedSize = Format-FileSize -Bytes $fileSize
        $ext = $file.Extension.ToLower()
        if ([string]::IsNullOrWhiteSpace($ext)) { $ext = "(no extension)" }

        # Hash calculation (Optional)
        $fileHash = ""
        $isDuplicate = $false
        if ($CalcHash) {
            $fileHash = Get-FileChecksum -FilePath $file.FullName -Algorithm $Algorithm
            if (![string]::IsNullOrEmpty($fileHash) -and $fileHash -ne "ERROR_READING_HASH") {
                if ($hashLookup.ContainsKey($fileHash)) {
                    $isDuplicate = $true
                    $duplicateCount++
                    $duplicateWastedBytes += $fileSize
                    $hashLookup[$fileHash].Add($file.FullName)
                } else {
                    $list = [System.Collections.Generic.List[string]]::new()
                    $list.Add($file.FullName)
                    $hashLookup[$fileHash] = $list
                }
            }
        }

        # Metadata extraction (Optional)
        $metadata = $null
        if ($GetMeta) {
            $metadata = Get-FileDetailedMetadata -FilePath $file.FullName -FileInfo $file
        }

        # Category Aggregation
        if (!$categorySummary.ContainsKey($catFolder)) {
            $categorySummary[$catFolder] = @{ Count = 0; TotalBytes = [int64]0 }
        }
        $categorySummary[$catFolder].Count++
        $categorySummary[$catFolder].TotalBytes += $fileSize

        # Extension Aggregation
        if (!$extensionSummary.ContainsKey($ext)) {
            $extensionSummary[$ext] = @{ Count = 0; TotalBytes = [int64]0 }
        }
        $extensionSummary[$ext].Count++
        $extensionSummary[$ext].TotalBytes += $fileSize

        $itemObj = [PSCustomObject]@{
            Category_Folder = $catFolder
            Relative_Path   = $relPath
            File_Name       = $file.Name
            Full_Path       = $file.FullName
            Extension       = $ext
            Size_Bytes      = $fileSize
            Size_MB         = $fileSizeMB
            Size_Formatted  = $formattedSize
            Hash            = $fileHash
            IsDuplicate     = $isDuplicate
            Metadata        = $metadata
            LastModified    = Format-ScanDateTime -Value $file.LastWriteTime
        }

        $fileList.Add($itemObj)

        if ($ProgressCallback -and ($currentIndex % 10 -eq 0 -or $currentIndex -eq $totalDiscovered)) {
            [void](& $ProgressCallback $currentIndex $totalDiscovered $file.Name)
        }
    }

    $stopwatch.Stop()
    # Measure-Object -Sum returns Double, so PowerShell 7's ConvertTo-Json emits "50746.0"
    # while PowerShell 5.1 emitted "50746". The schema declares Total_Size_Bytes as an
    # integer, so pin the type before serialization to keep output host-independent.
    $totalBytes = [int64](($fileList | Measure-Object -Property Size_Bytes -Sum).Sum)
    if (!$totalBytes) { $totalBytes = [int64]0 }

    $scanResult = [ordered]@{
        Scan_Meta = [ordered]@{
            Target_Folder     = $TargetFolder
            Scan_Timestamp    = Format-ScanDateTime -Value (Get-Date)
            Scan_Duration_Sec = ConvertTo-StableNumber ([math]::Round($stopwatch.Elapsed.TotalSeconds, 2))
            Total_Files       = $fileList.Count
            Total_Size_Bytes  = $totalBytes
            Total_Size_MB     = ConvertTo-StableNumber ([math]::Round($totalBytes / 1MB, 2))
            Total_Size_Human  = Format-FileSize -Bytes $totalBytes
            Hash_Calculated   = [bool]$CalcHash
            Duplicate_Files   = $duplicateCount
            Duplicate_Space_Wasted = Format-FileSize -Bytes $duplicateWastedBytes
            Metadata_Extracted = [bool]$GetMeta
        }
        Category_Stats   = $categorySummary
        Extension_Stats  = $extensionSummary
        Files            = $fileList
    }

    return $scanResult
}

# Direct Execution Handler (CLI Mode)
$isDotSourced = ($MyInvocation.InvocationName -eq '.')
if (!$isDotSourced) {
    Write-Host "=== Scan Me! File Scanner ===" -ForegroundColor Cyan
    Write-Host "Target Folder: $TargetFolder" -ForegroundColor Yellow
    
    $result = Invoke-DirectoryScan `
        -TargetFolder $TargetFolder `
        -Extensions $Extensions `
        -IncludeAll $IncludeAllFiles `
        -CalcHash $CalculateHash `
        -Algorithm $HashAlgorithm `
        -GetMeta $ExtractMetadata `
        -HiddenFiles $IncludeHiddenFiles `
        -ProgressCallback {
            param($curr, $total, $name)
            Write-Progress -Activity "Scanning Folder..." -Status "Processed $curr of $total" -PercentComplete (($curr / $total) * 100)
        }

    Write-Host "`nScan Finished! Total files found: $($result.Scan_Meta.Total_Files) ($($result.Scan_Meta.Total_Size_Human))" -ForegroundColor Green
    
    if (![string]::IsNullOrEmpty($OutputFile)) {
        Export-ScanResultToJson -ScanData $result -OutputPath $OutputFile
        Write-Host "JSON Result saved to: $OutputFile" -ForegroundColor Green
    }
}