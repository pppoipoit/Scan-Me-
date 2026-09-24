<#
.SYNOPSIS
    Scan Me! - WPF GUI Application Controller
.DESCRIPTION
    Launches the modern Fluent/Dark WPF GUI, manages UI events, multi-threaded scanning,
    live data grid filtering, JSON/CSV exports, and interactive HTML / TXT Root Tree exports.
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

if (-not ([System.Management.Automation.PSTypeName]'ScanMe.NativeMethods').Type) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

namespace ScanMe
{
    public static class NativeMethods
    {
        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        public static extern int SetCurrentProcessExplicitAppUserModelID(string appID);
    }
}
"@
}

$appUserModelId = "DRKMTTR.ScanMe.1.0"
$appUserModelResult = [ScanMe.NativeMethods]::SetCurrentProcessExplicitAppUserModelID($appUserModelId)

# Determine Directories
$scriptDir = $PSScriptRoot
$projectRoot = Split-Path -Path $scriptDir -Parent | Split-Path -Parent

# Resolve the canonical icon in both PowerShell and compiled-launcher modes.
$launcherExePath = $env:SCANME_EXE_PATH
$exeDirectory = if ($launcherExePath) {
    Split-Path -Path $launcherExePath -Parent
} else {
    [System.IO.Path]::GetDirectoryName([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
}
$canonicalIconPath = [System.IO.Path]::GetFullPath((Join-Path -Path $projectRoot -ChildPath "assets\app.ico"))
$appIconCandidates = @(
    (Join-Path -Path $exeDirectory -ChildPath "assets\app.ico"),
    (Join-Path -Path $PSScriptRoot -ChildPath "..\..\assets\app.ico"),
    $canonicalIconPath
)
$appIconPath = $appIconCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (!$appIconPath) {
    throw "Canonical application icon not found. Expected: $canonicalIconPath"
}
$appIconPath = [System.IO.Path]::GetFullPath($appIconPath)
$appIconUri = [System.Uri]::new($appIconPath, [System.UriKind]::Absolute)
$appIconImage = [System.Windows.Media.Imaging.BitmapFrame]::Create($appIconUri)
$startupLog = @(
    "Scan Me! startup diagnostics"
    "Logo source: $appIconPath"
    "AppUserModelID: $appUserModelId"
    "SetCurrentProcessExplicitAppUserModelID result: $appUserModelResult"
)
$startupLog | Write-Host

$xamlPath = Join-Path -Path $scriptDir -ChildPath "MainWindow.xaml"
$enginePath = Join-Path -Path $projectRoot -ChildPath "src\engine\Scanner.ps1"
$utilsPath = Join-Path -Path $projectRoot -ChildPath "src\utils\Helpers.ps1"
$configPath = Join-Path -Path $projectRoot -ChildPath "config\default_config.json"
$outputDir = Join-Path -Path $projectRoot -ChildPath "output"

if (!(Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

# Dot-source Helpers
if (Test-Path -Path $utilsPath) {
    . $utilsPath
}
if (Test-Path -Path $enginePath) {
    . $enginePath
}

# Read XAML
[xml]$xaml = Get-Content -Path $xamlPath -Raw -Encoding UTF8
$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)
$window.Icon = $appIconImage
$logo = $window.FindName("AppLogo")
if ($logo) {
    $logo.Source = $appIconImage
}

# Map UI Controls
$txtTargetFolder   = $window.FindName("TxtTargetFolder")
$btnBrowseTarget   = $window.FindName("BtnBrowseTarget")
$cmbPresets        = $window.FindName("CmbPresets")
$txtExtensions     = $window.FindName("TxtExtensions")
$chkAllFiles       = $window.FindName("ChkAllFiles")
$chkDuplicateHash  = $window.FindName("ChkDuplicateHash")
$chkExeMetadata    = $window.FindName("ChkExeMetadata")
$chkHiddenFiles    = $window.FindName("ChkHiddenFiles")

$lblTotalFiles     = $window.FindName("LblTotalFiles")
$lblTotalSize      = $window.FindName("LblTotalSize")
$lblCategoryCount  = $window.FindName("LblCategoryCount")
$lblDuplicateCount = $window.FindName("LblDuplicateCount")
$statusDot         = $window.FindName("StatusDot")
$statusText        = $window.FindName("StatusText")

$txtSearchFilter   = $window.FindName("TxtSearchFilter")
$lblRecordStatus   = $window.FindName("LblRecordStatus")
$btnClearTable     = $window.FindName("BtnClearTable")
$gridResults       = $window.FindName("GridResults")

$scanProgressBar   = $window.FindName("ScanProgressBar")
$lblProgressDetail = $window.FindName("LblProgressDetail")
$btnExportJson     = $window.FindName("BtnExportJson")
$btnExportCsv      = $window.FindName("BtnExportCsv")
$btnExportHtmlTree = $window.FindName("BtnExportHtmlTree")
$btnExportTxtTree  = $window.FindName("BtnExportTxtTree")
$btnOpenOutput     = $window.FindName("BtnOpenOutput")
$btnStartScan      = $window.FindName("BtnStartScan")

# State Storage
$global:CurrentScanResult = $null
$global:AllGridItems = [System.Collections.Generic.List[PSCustomObject]]::new()

# Load default configuration or set to project directory
$defaultFolder = $projectRoot
if (Test-Path -Path $configPath) {
    try {
        $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($config.default_target_folder -and (Test-Path -LiteralPath $config.default_target_folder)) {
            $defaultFolder = $config.default_target_folder
        }
    } catch {}
}
$txtTargetFolder.Text = $defaultFolder

# Event: Browse Folder
$btnBrowseTarget.Add_Click({
    $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
    $dialog.Description = "Select target folder to scan"
    if (Test-Path -LiteralPath $txtTargetFolder.Text) {
        $dialog.SelectedPath = $txtTargetFolder.Text
    }
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtTargetFolder.Text = $dialog.SelectedPath
    }
})

# Event: Preset Selection Changed
$cmbPresets.Add_SelectionChanged({
    $selected = $cmbPresets.SelectedItem.Content
    if ($selected -like "*All Files*") {
        $chkAllFiles.IsChecked = $true
        $txtExtensions.Text = "*.*"
    } elseif ($selected -like "*Installers*") {
        $chkAllFiles.IsChecked = $false
        $txtExtensions.Text = "*.exe, *.msi, *.zip, *.msix, *.rar, *.7z, *.iso"
    } elseif ($selected -like "*Code*") {
        $chkAllFiles.IsChecked = $false
        $txtExtensions.Text = "*.js, *.ts, *.py, *.ps1, *.json, *.html, *.css, *.cpp, *.c, *.cs, *.dart, *.yaml, *.md"
    } elseif ($selected -like "*Documents*") {
        $chkAllFiles.IsChecked = $false
        $txtExtensions.Text = "*.pdf, *.docx, *.doc, *.xlsx, *.xls, *.pptx, *.txt, *.csv"
    } elseif ($selected -like "*Media*") {
        $chkAllFiles.IsChecked = $false
        $txtExtensions.Text = "*.png, *.jpg, *.jpeg, *.gif, *.webp, *.mp4, *.mkv, *.mp3, *.wav"
    } elseif ($selected -like "*Custom*") {
        $chkAllFiles.IsChecked = $false
    }
})

# Event: Check All Files Checkbox Toggle
$chkAllFiles.Add_Checked({
    $txtExtensions.Text = "*.*"
})

# Filter Items in DataGrid
function Update-FilteredGrid {
    $filterText = $txtSearchFilter.Text.Trim().ToLower()
    if ([string]::IsNullOrEmpty($filterText)) {
        $gridResults.ItemsSource = $global:AllGridItems
        $lblRecordStatus.Text = "$($global:AllGridItems.Count) items listed"
    } else {
        $filtered = $global:AllGridItems | Where-Object {
            ($_.File_Name -and $_.File_Name.ToLower().Contains($filterText)) -or
            ($_.Category_Folder -and $_.Category_Folder.ToLower().Contains($filterText)) -or
            ($_.Extension -and $_.Extension.ToLower().Contains($filterText)) -or
            ($_.Full_Path -and $_.Full_Path.ToLower().Contains($filterText))
        }
        $gridResults.ItemsSource = [System.Collections.Generic.List[PSCustomObject]]::new($filtered)
        $lblRecordStatus.Text = "$($filtered.Count) of $($global:AllGridItems.Count) items matching filter"
    }
}

$txtSearchFilter.Add_TextChanged({
    Update-FilteredGrid
})

# Event: Clear Table
$btnClearTable.Add_Click({
    $global:AllGridItems.Clear()
    $global:CurrentScanResult = $null
    $gridResults.ItemsSource = $null
    $lblRecordStatus.Text = "0 items listed"
    $lblTotalFiles.Text = "0"
    $lblTotalSize.Text = "0 MB"
    $lblCategoryCount.Text = "0 Types"
    $lblDuplicateCount.Text = "0 (0 MB)"
    $btnExportJson.IsEnabled = $false
    $btnExportCsv.IsEnabled = $false
    $btnExportHtmlTree.IsEnabled = $false
    $btnExportTxtTree.IsEnabled = $false
    $scanProgressBar.Value = 0
    $lblProgressDetail.Text = "Cleared."
})

# Event: Start Scan
$btnStartScan.Add_Click({
    $targetPath = $txtTargetFolder.Text.Trim()
    if (![System.IO.Directory]::Exists($targetPath)) {
        [System.Windows.MessageBox]::Show("The target folder does not exist:`n$targetPath", "Target Not Found", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    # Lock UI controls
    $btnStartScan.IsEnabled = $false
    $statusText.Text = "Scanning in progress..."
    $statusDot.Fill = [System.Windows.Media.Brushes]::Orange
    $scanProgressBar.IsIndeterminate = $true
    $lblProgressDetail.Text = "Enumerating directories and files..."

    # Read UI parameters
    $includeAll = [bool]$chkAllFiles.IsChecked
    $extRaw = $txtExtensions.Text.Split(",; ") | Where-Object { ![string]::IsNullOrWhiteSpace($_) }
    $calcHash = [bool]$chkDuplicateHash.IsChecked
    $getMeta = [bool]$chkExeMetadata.IsChecked
    $includeHidden = [bool]$chkHiddenFiles.IsChecked

    # Dispatch Background Work
    [void]$window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})

    try {
        $scanOutput = Invoke-DirectoryScan `
            -TargetFolder $targetPath `
            -Extensions $extRaw `
            -IncludeAll $includeAll `
            -CalcHash $calcHash `
            -Algorithm "MD5" `
            -GetMeta $getMeta `
            -HiddenFiles $includeHidden `
            -ProgressCallback {
                param($curr, $total, $name)
                $scanProgressBar.IsIndeterminate = $false
                $scanProgressBar.Value = [math]::Round(($curr / $total) * 100)
                $lblProgressDetail.Text = "Scanning: $curr / $total ($name)"
                [void]$window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Render, [action]{})
            }

        # Extract dictionary result safely
        $result = $null
        if ($scanOutput -is [System.Array]) {
            foreach ($item in $scanOutput) {
                if ($item -and ($item -is [System.Collections.IDictionary] -or $item.PSObject.Properties['Scan_Meta'])) {
                    $result = $item
                }
            }
        } else {
            $result = $scanOutput
        }

        if (!$result) {
            throw "Invalid scan result returned by engine."
        }

        $global:CurrentScanResult = $result
        $global:AllGridItems.Clear()

        foreach ($f in $result.Files) {
            $duplicateBadge = if ($f.IsDuplicate) { "[DUPLICATE]" } else { "-" }
            $metaInfo = ""
            if ($f.Metadata) {
                if ($f.Metadata.ProductVersion) {
                    $metaInfo = "v$($f.Metadata.ProductVersion)"
                } elseif ($f.Metadata.FileVersion) {
                    $metaInfo = "v$($f.Metadata.FileVersion)"
                }
                if ($f.Metadata.CompanyName) {
                    $metaInfo += " ($($f.Metadata.CompanyName))"
                }
            }

            $gridObj = [PSCustomObject]@{
                Category_Folder = $f.Category_Folder
                File_Name       = $f.File_Name
                Extension       = $f.Extension
                Size_Formatted  = $f.Size_Formatted
                Size_MB         = $f.Size_MB
                DuplicateBadge  = $duplicateBadge
                MetaInfo        = $metaInfo
                LastModified    = $f.LastModified
                Full_Path       = $f.Full_Path
            }
            $global:AllGridItems.Add($gridObj)
        }

        # Update Grid & Stat Cards
        Update-FilteredGrid
        $meta = $result.Scan_Meta
        $lblTotalFiles.Text = [string]$meta.Total_Files
        $lblTotalSize.Text = [string]$meta.Total_Size_Human
        $lblCategoryCount.Text = "$($result.Category_Stats.Keys.Count) Folders / $($result.Extension_Stats.Keys.Count) Types"
        $lblDuplicateCount.Text = "$($meta.Duplicate_Files) ($($meta.Duplicate_Space_Wasted))"

        $statusText.Text = "Scan Complete ($($meta.Scan_Duration_Sec)s)"
        $statusDot.Fill = [System.Windows.Media.Brushes]::SpringGreen
        $scanProgressBar.Value = 100
        $lblProgressDetail.Text = "Finished scanning $($meta.Total_Files) files in $($meta.Scan_Duration_Sec) seconds."

        $btnExportJson.IsEnabled = $true
        $btnExportCsv.IsEnabled = $true
        $btnExportHtmlTree.IsEnabled = $true
        $btnExportTxtTree.IsEnabled = $true

        # Auto save results
        $autoJsonPath = Join-Path -Path $outputDir -ChildPath "latest_scan.json"
        Export-ScanResultToJson -ScanData $result -OutputPath $autoJsonPath

        $autoHtmlPath = Join-Path -Path $outputDir -ChildPath "latest_tree.html"
        Export-ScanResultToHtmlTree -ScanResult $result -OutputPath $autoHtmlPath

        $autoTxtPath = Join-Path -Path $outputDir -ChildPath "latest_tree.txt"
        Export-ScanResultToTextTree -ScanResult $result -OutputPath $autoTxtPath
    }
    catch {
        $statusText.Text = "Scan Error"
        $statusDot.Fill = [System.Windows.Media.Brushes]::Red
        $lblProgressDetail.Text = "Error: $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show("Error during scan:`n$($_.Exception.Message)", "Scan Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
    finally {
        $btnStartScan.IsEnabled = $true
        $scanProgressBar.IsIndeterminate = $false
    }
})

# Event: Export JSON
$btnExportJson.Add_Click({
    if (!$global:CurrentScanResult) { return }
    $dialog = [System.Windows.Forms.SaveFileDialog]::new()
    $dialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
    $dialog.FileName = "SkillTree_Scan_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $dialog.InitialDirectory = $outputDir
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Export-ScanResultToJson -ScanData $global:CurrentScanResult -OutputPath $dialog.FileName
        [System.Windows.MessageBox]::Show("Successfully exported JSON data to:`n$($dialog.FileName)", "JSON Exported", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

# Event: Export CSV
$btnExportCsv.Add_Click({
    if (!$global:CurrentScanResult) { return }
    $dialog = [System.Windows.Forms.SaveFileDialog]::new()
    $dialog.Filter = "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*"
    $dialog.FileName = "Scan_List_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $dialog.InitialDirectory = $outputDir
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Export-ScanResultToCsv -Files $global:CurrentScanResult.Files -OutputPath $dialog.FileName
        [System.Windows.MessageBox]::Show("Successfully exported CSV data to:`n$($dialog.FileName)", "CSV Exported", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

# Event: Export Interactive HTML Tree
$btnExportHtmlTree.Add_Click({
    if (!$global:CurrentScanResult) { return }
    $dialog = [System.Windows.Forms.SaveFileDialog]::new()
    $dialog.Filter = "Interactive HTML Tree (*.html)|*.html|All Files (*.*)|*.*"
    $dialog.FileName = "Scan_Tree_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    $dialog.InitialDirectory = $outputDir
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Export-ScanResultToHtmlTree -ScanResult $global:CurrentScanResult -OutputPath $dialog.FileName
        $resp = [System.Windows.MessageBox]::Show("Successfully exported Interactive HTML Tree to:`n$($dialog.FileName)`n`nWould you like to open it in your browser right now?", "HTML Tree Exported", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Information)
        if ($resp -eq [System.Windows.MessageBoxResult]::Yes) {
            [System.Diagnostics.Process]::Start($dialog.FileName)
        }
    }
})

# Event: Export Plain Text Tree
$btnExportTxtTree.Add_Click({
    if (!$global:CurrentScanResult) { return }
    $dialog = [System.Windows.Forms.SaveFileDialog]::new()
    $dialog.Filter = "Plain Text Tree (*.txt)|*.txt|Markdown Tree (*.md)|*.md|All Files (*.*)|*.*"
    $dialog.FileName = "Scan_Tree_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $dialog.InitialDirectory = $outputDir
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Export-ScanResultToTextTree -ScanResult $global:CurrentScanResult -OutputPath $dialog.FileName
        $resp = [System.Windows.MessageBox]::Show("Successfully exported Text Tree to:`n$($dialog.FileName)`n`nWould you like to open it in Notepad right now?", "Text Tree Exported", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Information)
        if ($resp -eq [System.Windows.MessageBoxResult]::Yes) {
            [System.Diagnostics.Process]::Start("notepad.exe", $dialog.FileName)
        }
    }
})

# Event: Open Output Folder
$btnOpenOutput.Add_Click({
    if (Test-Path -Path $outputDir) {
        [System.Diagnostics.Process]::Start("explorer.exe", $outputDir)
    }
})

# Show Application
$window.ShowDialog() | Out-Null