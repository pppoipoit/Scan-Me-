<#
.SYNOPSIS
    Scan Me! - Helper Functions & Utilities
.DESCRIPTION
    Provides hashing, metadata extraction, formatting, JSON/CSV export,
    and interactive HTML / Text Root Tree generation.
#>

function Format-FileSize {
    param (
        [Parameter(Mandatory = $true)]
        [Int64]$Bytes
    )
    if ($Bytes -ge 1GB) {
        return "$([math]::Round($Bytes / 1GB, 2)) GB"
    }
    elseif ($Bytes -ge 1MB) {
        return "$([math]::Round($Bytes / 1MB, 2)) MB"
    }
    elseif ($Bytes -ge 1KB) {
        return "$([math]::Round($Bytes / 1KB, 2)) KB"
    }
    else {
        return "$Bytes Bytes"
    }
}

# Contract-stable date formatter.
# DateTime.ToString(format) is CULTURE-SENSITIVE. Under a Thai (th-TH) locale the
# ThaiBuddhistCalendar renders the year as 2569 instead of 2026. PowerShell 7 inherits the
# OS user locale, while Windows PowerShell 5.1 forces en-US, so the raw overload made the
# SAME scan emit different years depending on the host and broke docs/SCHEMA_SPEC.md.
# Pinning InvariantCulture guarantees a Gregorian, host-independent value.
function Format-ScanDateTime {
    param (
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $Value,

        [Parameter(Mandatory = $false)]
        [string]$Format = "yyyy-MM-dd HH:mm:ss"
    )

    if ($null -eq $Value) { return "" }

    return ([datetime]$Value).ToString($Format, [System.Globalization.CultureInfo]::InvariantCulture)
}

# Contract-stable number formatter.
# PowerShell 7's ConvertTo-Json renders ANY whole-valued floating point number with a
# trailing ".0" ("0.0", "5.0") while Windows PowerShell 5.1 renders the same value as
# "0" and "5". That made the SAME scan emit different JSON per host for every rounded
# MB / duration value. JSON has no int-vs-float distinction, so emitting the integer
# literal is schema-valid for a "number" field and makes the output byte-identical.
# Genuinely fractional values (19.15) are returned unchanged and already match.
function ConvertTo-StableNumber {
    param (
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) { return $null }

    try {
        $d = [double]$Value
    }
    catch {
        return $Value
    }

    if ([double]::IsNaN($d) -or [double]::IsInfinity($d)) { return $Value }
    if ($d -eq [math]::Floor($d) -and [math]::Abs($d) -lt 2147483647) { return [int]$d }

    return $Value
}

function Get-FileChecksum {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [ValidateSet("MD5", "SHA256")]
        [string]$Algorithm = "MD5"
    )
    try {
        if (Test-Path -LiteralPath $FilePath) {
            $hash = Get-FileHash -LiteralPath $FilePath -Algorithm $Algorithm -ErrorAction Stop
            return $hash.Hash
        }
    }
    catch {
        return "ERROR_READING_HASH"
    }
    return ""
}

function Get-FileDetailedMetadata {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$FileInfo
    )
    
    $meta = [ordered]@{
        FileType        = $FileInfo.Extension.ToLower()
        IsReadOnly      = $FileInfo.IsReadOnly
        CreationTime    = Format-ScanDateTime -Value $FileInfo.CreationTime
        LastWriteTime   = Format-ScanDateTime -Value $FileInfo.LastWriteTime
        FileVersion     = $null
        ProductVersion  = $null
        CompanyName     = $null
        FileDescription = $null
        OriginalFileName= $null
    }

    if ($FileInfo.Extension -in @(".exe", ".dll", ".sys", ".msi")) {
        try {
            $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($FilePath)
            if ($versionInfo) {
                $meta.FileVersion      = $versionInfo.FileVersion
                $meta.ProductVersion   = $versionInfo.ProductVersion
                $meta.CompanyName      = $versionInfo.CompanyName
                $meta.FileDescription  = $versionInfo.FileDescription
                $meta.OriginalFileName = $versionInfo.OriginalFilename
            }
        }
        catch {
            # Ignore version read failures
        }
    }

    return $meta
}

function Export-ScanResultToJson {
    param (
        [Parameter(Mandatory = $true)]
        [object]$ScanData,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    $parentDir = Split-Path -Path $OutputPath -Parent
    if ($parentDir -and !(Test-Path -Path $parentDir)) {
        New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
    }

    $json = $ScanData | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($OutputPath, $json, [System.Text.Encoding]::UTF8)
}

function Export-ScanResultToCsv {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Files,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    $parentDir = Split-Path -Path $OutputPath -Parent
    if ($parentDir -and !(Test-Path -Path $parentDir)) {
        New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
    }

    $flatList = foreach ($item in $Files) {
        [PSCustomObject]@{
            Category_Folder = $item.Category_Folder
            File_Name       = $item.File_Name
            Extension       = $item.Extension
            Size_Formatted  = $item.Size_Formatted
            Size_Bytes      = $item.Size_Bytes
            Size_MB         = $item.Size_MB
            Hash            = if ($item.Hash) { $item.Hash } else { "" }
            IsDuplicate     = if ($item.IsDuplicate) { "Yes" } else { "No" }
            FileVersion     = if ($item.Metadata -and $item.Metadata.FileVersion) { $item.Metadata.FileVersion } else { "" }
            CompanyName     = if ($item.Metadata -and $item.Metadata.CompanyName) { $item.Metadata.CompanyName } else { "" }
            Full_Path       = $item.Full_Path
            LastModified    = $item.LastModified
        }
    }
    $flatList | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
}

# --- Tree Data Builder ---
function Build-FolderTreeHierarchy {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Files,
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    # Normalize separators to Windows backslash so every FullPath built from this root is Windows-style
    $RootPath = $RootPath.Replace('/', '\')

    $rootNode = [ordered]@{
        Name     = (Split-Path -Path $RootPath -Leaf)
        FullPath = $RootPath
        Type     = "directory"
        Size     = [int64]0
        Folders  = [ordered]@{}
        Files    = [System.Collections.Generic.List[object]]::new()
    }
    if ([string]::IsNullOrEmpty($rootNode.Name)) {
        $rootNode.Name = $RootPath
    }

    foreach ($f in $Files) {
        $rel = [string]$f.Relative_Path
        # Explicit [char[]] separator: PS7 would bind a plain string to Split(string[]) and
        # split only on the literal "\/" (flattening the tree); char[] works in PS5.1 and PS7
        $parts = $rel.Split([char[]]@('\', '/'), [System.StringSplitOptions]::RemoveEmptyEntries)
        
        $currNode = $rootNode
        $accumPath = $RootPath
        
        if ($parts.Length -gt 1) {
            for ($i = 0; $i -lt ($parts.Length - 1); $i++) {
                $folderName = $parts[$i]
                $accumPath = Join-Path -Path $accumPath -ChildPath $folderName
                if (!$currNode.Folders.Contains($folderName)) {
                    $currNode.Folders[$folderName] = [ordered]@{
                        Name     = $folderName
                        FullPath = $accumPath
                        Type     = "directory"
                        Size     = [int64]0
                        Folders  = [ordered]@{}
                        Files    = [System.Collections.Generic.List[object]]::new()
                    }
                }
                $currNode = $currNode.Folders[$folderName]
            }
        }

        $currNode.Files.Add($f)
    }

    # Recursive size calculator
    function Calculate-NodeSize($node) {
        $total = [int64]0
        foreach ($file in $node.Files) {
            $total += [int64]$file.Size_Bytes
        }
        foreach ($sub in $node.Folders.Values) {
            $total += Calculate-NodeSize $sub
        }
        $node.Size = $total
        return $total
    }

    [void](Calculate-NodeSize $rootNode)
    return $rootNode
}

# --- Export to Plain Text Tree ---
function Export-ScanResultToTextTree {
    param (
        [Parameter(Mandatory = $true)]
        [object]$ScanResult,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $parentDir = Split-Path -Path $OutputPath -Parent
    if ($parentDir -and !(Test-Path -Path $parentDir)) {
        New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
    }

    $targetFolder = $ScanResult.Scan_Meta.Target_Folder
    $treeRoot = Build-FolderTreeHierarchy -Files $ScanResult.Files -RootPath $targetFolder
    
    $sb = [System.Text.StringBuilder]::new()
    $formattedRootSize = Format-FileSize -Bytes $treeRoot.Size
    [void]$sb.AppendLine("$($treeRoot.Name)/  [$formattedRootSize]  ($targetFolder)")

    # Define tree connector strings using Unicode chars
    $cBranch = "$([char]0x251C)$([char]0x2500)$([char]0x2500) "
    $cLeaf   = "$([char]0x2514)$([char]0x2500)$([char]0x2500) "
    $cPipe   = "$([char]0x2502)   "
    $cSpace  = "    "

    function Render-TextNode($node, $prefix) {
        $folderKeys = @($node.Folders.Keys)
        $fileList = @($node.Files)
        $totalItems = $folderKeys.Count + $fileList.Count
        $itemIndex = 0

        # Render Subfolders
        foreach ($k in $folderKeys) {
            $itemIndex++
            $isLast = ($itemIndex -eq $totalItems)
            $connector = if ($isLast) { $cLeaf } else { $cBranch }
            $childPrefix = if ($isLast) { "$prefix$cSpace" } else { "$prefix$cPipe" }
            
            $sub = $node.Folders[$k]
            $subSize = Format-FileSize -Bytes $sub.Size
            [void]$sb.AppendLine("$prefix$connector[Folder] $($sub.Name)/  [$subSize]")
            Render-TextNode -node $sub -prefix $childPrefix
        }

        # Render Files
        foreach ($f in $fileList) {
            $itemIndex++
            $isLast = ($itemIndex -eq $totalItems)
            $connector = if ($isLast) { $cLeaf } else { $cBranch }
            $sizeStr = if ($f.Size_Formatted) { $f.Size_Formatted } else { Format-FileSize -Bytes $f.Size_Bytes }
            $dupTag = if ($f.IsDuplicate) { " [DUPLICATE]" } else { "" }
            [void]$sb.AppendLine("$prefix$connector[File] $($f.File_Name)  ($sizeStr)$dupTag")
        }
    }

    Render-TextNode -node $treeRoot -prefix ""
    [System.IO.File]::WriteAllText($OutputPath, $sb.ToString(), [System.Text.Encoding]::UTF8)
}

# --- Export to Interactive HTML Tree ---
function Export-ScanResultToHtmlTree {
    param (
        [Parameter(Mandatory = $true)]
        [object]$ScanResult,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $parentDir = Split-Path -Path $OutputPath -Parent
    if ($parentDir -and !(Test-Path -Path $parentDir)) {
        New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
    }

    $targetFolder = ([string]$ScanResult.Scan_Meta.Target_Folder).Replace('/', '\')
    $meta = $ScanResult.Scan_Meta
    $treeRoot = Build-FolderTreeHierarchy -Files $ScanResult.Files -RootPath $targetFolder

    # Shared icon resolver (returns the HTML entity used by the DOM rows). The embedded
    # copy-tree model decodes the same entity so copied text matches the visible icons.
    function Get-HtmlTreeIconEntity {
        param ([string]$Ext)
        switch ($Ext.ToLower()) {
            # Executables & Scripts
            { $_ -in @(".exe", ".msi", ".bat", ".cmd", ".com", ".scr") } { return "&#9889;" }
            # Archives
            { $_ -in @(".zip", ".rar", ".7z", ".tar", ".gz", ".bz2", ".xz", ".tgz", ".tar.gz") } { return "&#128230;" }
            # Code files
            { $_ -in @(".js", ".ts", ".py", ".ps1", ".json", ".html", ".css", ".cpp", ".c", ".cs", ".java", ".go", ".rs", ".rb", ".php", ".sh", ".vb", ".swift", ".kt", ".scala", ".r", ".m", ".pl") } { return "&#128187;" }
            # Documents
            { $_ -in @(".pdf", ".docx", ".xlsx", ".pptx", ".txt", ".md", ".csv", ".doc", ".xls", ".ppt", ".rtf", ".odt", ".ods", ".odp") } { return "&#128209;" }
            # Images & Media
            { $_ -in @(".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".tiff", ".svg", ".ico", ".mp4", ".mp3", ".wav", ".avi", ".mov", ".mkv", ".flac", ".aac", ".ogg") } { return "&#127912;" }
            # Fonts
            { $_ -in @(".ttf", ".otf", ".woff", ".woff2", ".eot") } { return "&#128214;" }
            # Config & Data
            { $_ -in @(".xml", ".yaml", ".yml", ".toml", ".ini", ".cfg", ".conf", ".config", ".env") } { return "&#128206;" }
            # Database
            { $_ -in @(".sql", ".db", ".sqlite", ".mdb", ".accdb") } { return "&#128247;" }
            # Default file icon
            default { return "&#128196;" }
        }
    }

    # Builds the embedded JSON data model walked by copyEntireTreeText(). Contains the FULL
    # tree (every path, size, item count, icon, version) independent of UI expand/collapse.
    function Build-CopyTreeModel {
        param ($node)
        $children = [System.Collections.Generic.List[object]]::new()
        foreach ($k in @($node.Folders.Keys)) {
            $children.Add((Build-CopyTreeModel -node $node.Folders[$k]))
        }
        foreach ($f in @($node.Files)) {
            $sizeStr = if ($f.Size_Formatted) { [string]$f.Size_Formatted } else { Format-FileSize -Bytes $f.Size_Bytes }
            $ver = $null
            if ($f.Metadata -and ($f.Metadata.ProductVersion -or $f.Metadata.FileVersion)) {
                $ver = if ($f.Metadata.ProductVersion) { [string]$f.Metadata.ProductVersion } else { [string]$f.Metadata.FileVersion }
            }
            $children.Add([PSCustomObject]@{
                name    = [string]$f.File_Name
                path    = ([string]$f.Full_Path).Replace('/', '\')
                type    = "file"
                size    = $sizeStr
                icon    = [System.Net.WebUtility]::HtmlDecode((Get-HtmlTreeIconEntity -Ext ([string]$f.Extension)))
                version = $ver
            })
        }
        return [PSCustomObject]@{
            name     = [string]$node.Name
            path     = ([string]$node.FullPath).Replace('/', '\')
            type     = "directory"
            size     = Format-FileSize -Bytes $node.Size
            icon     = [System.Net.WebUtility]::HtmlDecode("&#128193;")
            count    = [int]($node.Folders.Count + $node.Files.Count)
            children = $children
        }
    }

    # Compressed JSON embedded in the <script> block. Escape '<' so a literal "</script>"
    # inside any file/folder name cannot terminate the script block early.
    $copyTreeJson = ConvertTo-Json -InputObject (Build-CopyTreeModel -node $treeRoot) -Depth 100 -Compress
    $copyTreeJson = $copyTreeJson.Replace('<', '\u003C')

    # Helper function to generate HTML nodes recursively
    function Render-HtmlNode($node, $depth) {
        $sbNode = [System.Text.StringBuilder]::new()
        $folderKeys = @($node.Folders.Keys)
        $fileList = @($node.Files)

        [void]$sbNode.AppendLine("<ul class='tree-list'>")

        # Folders
        foreach ($k in $folderKeys) {
            $sub = $node.Folders[$k]
            $subSize = Format-FileSize -Bytes $sub.Size
            $childCount = $sub.Folders.Count + $sub.Files.Count
            # Normalize '/' -> '\' (Windows), HTML-encode for the data attribute,
            # then escape '\' separately for the existing JS string literal.
            $pathAttr = [System.Net.WebUtility]::HtmlEncode(([string]$sub.FullPath).Replace('/', '\'))
            $escPath = $pathAttr.Replace('\', '\\')
            $escName = [System.Net.WebUtility]::HtmlEncode($sub.Name)

            [void]$sbNode.AppendLine("<li class='tree-item folder-item' data-name='$escName' data-path='$pathAttr'>")
            [void]$sbNode.AppendLine("  <div class='node-row'>")
            [void]$sbNode.AppendLine("    <button class='toggle-btn' onclick='toggleNode(this)'>&#9660;</button>")
            [void]$sbNode.AppendLine("    <span class='icon'>&#128193;</span>")
            [void]$sbNode.AppendLine("    <span class='item-name folder-name' onclick='toggleRow(this)'>$escName</span>")
            [void]$sbNode.AppendLine("    <span class='badge size-badge'>$subSize</span>")
            [void]$sbNode.AppendLine("    <span class='badge count-badge'>$childCount items</span>")
            [void]$sbNode.AppendLine("    <button class='copy-btn' onclick='copyPath(this, `"$escPath`")' title='Copy Full Path'>&#128203; Copy Path</button>")
            [void]$sbNode.AppendLine("  </div>")
            
            $innerHtml = Render-HtmlNode -node $sub -depth ($depth + 1)
            [void]$sbNode.AppendLine("  <div class='children-container'>$innerHtml</div>")
            [void]$sbNode.AppendLine("</li>")
        }

        # Files
        foreach ($f in $fileList) {
            $sizeStr = if ($f.Size_Formatted) { $f.Size_Formatted } else { Format-FileSize -Bytes $f.Size_Bytes }
            # Normalize '/' -> '\' (Windows), HTML-encode for the data attribute,
            # then escape '\' separately for the existing JS string literal.
            $pathAttr = [System.Net.WebUtility]::HtmlEncode(([string]$f.Full_Path).Replace('/', '\'))
            $escPath = $pathAttr.Replace('\', '\\')
            $escName = [System.Net.WebUtility]::HtmlEncode($f.File_Name)
            $ext = $f.Extension.ToLower()
            
            # Shared icon resolver (same mapping drives the embedded copy-tree model)
            $icon = Get-HtmlTreeIconEntity -Ext $ext

            $dupBadge = if ($f.IsDuplicate) { "<span class='badge dup-badge'>&#9888; Duplicate</span>" } else { "" }
            $verBadge = ""
            if ($f.Metadata -and ($f.Metadata.ProductVersion -or $f.Metadata.FileVersion)) {
                $ver = if ($f.Metadata.ProductVersion) { $f.Metadata.ProductVersion } else { $f.Metadata.FileVersion }
                $verBadge = "<span class='badge ver-badge'>v$ver</span>"
            }

            [void]$sbNode.AppendLine("<li class='tree-item file-item' data-name='$escName' data-path='$pathAttr'>")
            [void]$sbNode.AppendLine("  <div class='node-row'>")
            [void]$sbNode.AppendLine("    <span class='spacer'></span>")
            [void]$sbNode.AppendLine("    <span class='icon'>$icon</span>")
            [void]$sbNode.AppendLine("    <span class='item-name file-name'>$escName</span>")
            [void]$sbNode.AppendLine("    <span class='badge size-badge'>$sizeStr</span>")
            [void]$sbNode.AppendLine("    $dupBadge")
            [void]$sbNode.AppendLine("    $verBadge")
            [void]$sbNode.AppendLine("    <button class='copy-btn' onclick='copyPath(this, `"$escPath`")' title='Copy Full Path'>&#128203; Copy Path</button>")
            [void]$sbNode.AppendLine("  </div>")
            [void]$sbNode.AppendLine("</li>")
        }

        [void]$sbNode.AppendLine("</ul>")
        return $sbNode.ToString()
    }

    $treeBody = Render-HtmlNode -node $treeRoot -depth 0
    $escRootName = [System.Net.WebUtility]::HtmlEncode($treeRoot.Name)
    $escRootPath = [System.Net.WebUtility]::HtmlEncode($targetFolder)

    $sbHtml = [System.Text.StringBuilder]::new()
    [void]$sbHtml.AppendLine('<!DOCTYPE html>')
    [void]$sbHtml.AppendLine('<html lang="en">')
    [void]$sbHtml.AppendLine('<head>')
    [void]$sbHtml.AppendLine('  <meta charset="UTF-8">')
    [void]$sbHtml.AppendLine('  <meta name="viewport" content="width=device-width, initial-scale=1.0">')
    [void]$sbHtml.AppendLine("  <title>Scan Me! - Root Tree: $escRootName</title>")
    [void]$sbHtml.AppendLine('  <style>')
    [void]$sbHtml.AppendLine('    :root {')
    [void]$sbHtml.AppendLine('      --bg: #0F172A;')
    [void]$sbHtml.AppendLine('      --card-bg: #1E293B;')
    [void]$sbHtml.AppendLine('      --border: #334155;')
    [void]$sbHtml.AppendLine('      --text: #F8FAFC;')
    [void]$sbHtml.AppendLine('      --text-muted: #94A3B8;')
    [void]$sbHtml.AppendLine('      --cyan: #06B6D4;')
    [void]$sbHtml.AppendLine('      --cyan-hover: #38BDF8;')
    [void]$sbHtml.AppendLine('      --green: #10B981;')
    [void]$sbHtml.AppendLine('      --purple: #8B5CF6;')
    [void]$sbHtml.AppendLine('      --rose: #F43F5E;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    * { box-sizing: border-box; margin: 0; padding: 0; }')
    [void]$sbHtml.AppendLine('    body {')
    [void]$sbHtml.AppendLine("      font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, sans-serif;")
    [void]$sbHtml.AppendLine('      background-color: var(--bg);')
    [void]$sbHtml.AppendLine('      color: var(--text);')
    [void]$sbHtml.AppendLine('      line-height: 1.5;')
    [void]$sbHtml.AppendLine('      padding: 24px;')
    [void]$sbHtml.AppendLine('      user-select: text;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .header {')
    [void]$sbHtml.AppendLine('      background: linear-gradient(135deg, #1E293B 0%, #0F172A 100%);')
    [void]$sbHtml.AppendLine('      border: 1px solid var(--border);')
    [void]$sbHtml.AppendLine('      border-radius: 12px;')
    [void]$sbHtml.AppendLine('      padding: 20px 24px;')
    [void]$sbHtml.AppendLine('      margin-bottom: 20px;')
    [void]$sbHtml.AppendLine('      display: flex;')
    [void]$sbHtml.AppendLine('      flex-wrap: wrap;')
    [void]$sbHtml.AppendLine('      justify-content: space-between;')
    [void]$sbHtml.AppendLine('      align-items: center;')
    [void]$sbHtml.AppendLine('      gap: 16px;')
    [void]$sbHtml.AppendLine('      box-shadow: 0 4px 20px rgba(0,0,0,0.3);')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .title-group h1 {')
    [void]$sbHtml.AppendLine('      font-size: 22px;')
    [void]$sbHtml.AppendLine('      font-weight: 800;')
    [void]$sbHtml.AppendLine('      background: linear-gradient(90deg, #06B6D4, #3B82F6, #8B5CF6);')
    [void]$sbHtml.AppendLine('      -webkit-background-clip: text;')
    [void]$sbHtml.AppendLine('      -webkit-text-fill-color: transparent;')
    [void]$sbHtml.AppendLine('      display: flex;')
    [void]$sbHtml.AppendLine('      align-items: center;')
    [void]$sbHtml.AppendLine('      gap: 10px;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .title-group p {')
    [void]$sbHtml.AppendLine('      color: var(--text-muted);')
    [void]$sbHtml.AppendLine('      font-size: 13px;')
    [void]$sbHtml.AppendLine('      margin-top: 4px;')
    [void]$sbHtml.AppendLine('      word-break: break-all;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .stats-bar {')
    [void]$sbHtml.AppendLine('      display: flex;')
    [void]$sbHtml.AppendLine('      gap: 12px;')
    [void]$sbHtml.AppendLine('      flex-wrap: wrap;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .stat-pill {')
    [void]$sbHtml.AppendLine('      background: #0F172A;')
    [void]$sbHtml.AppendLine('      border: 1px solid var(--border);')
    [void]$sbHtml.AppendLine('      padding: 6px 14px;')
    [void]$sbHtml.AppendLine('      border-radius: 20px;')
    [void]$sbHtml.AppendLine('      font-size: 12.5px;')
    [void]$sbHtml.AppendLine('      font-weight: 600;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .stat-pill span { color: var(--cyan); }')
    [void]$sbHtml.AppendLine('    .toolbar {')
    [void]$sbHtml.AppendLine('      background: var(--card-bg);')
    [void]$sbHtml.AppendLine('      border: 1px solid var(--border);')
    [void]$sbHtml.AppendLine('      border-radius: 10px;')
    [void]$sbHtml.AppendLine('      padding: 12px 18px;')
    [void]$sbHtml.AppendLine('      margin-bottom: 16px;')
    [void]$sbHtml.AppendLine('      display: flex;')
    [void]$sbHtml.AppendLine('      flex-wrap: wrap;')
    [void]$sbHtml.AppendLine('      align-items: center;')
    [void]$sbHtml.AppendLine('      justify-content: space-between;')
    [void]$sbHtml.AppendLine('      gap: 12px;')
    [void]$sbHtml.AppendLine('      position: sticky;')
    [void]$sbHtml.AppendLine('      top: 10px;')
    [void]$sbHtml.AppendLine('      z-index: 100;')
    [void]$sbHtml.AppendLine('      box-shadow: 0 4px 16px rgba(0,0,0,0.4);')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .search-box {')
    [void]$sbHtml.AppendLine('      flex: 1;')
    [void]$sbHtml.AppendLine('      min-width: 250px;')
    [void]$sbHtml.AppendLine('      max-width: 450px;')
    [void]$sbHtml.AppendLine('      position: relative;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .search-box input {')
    [void]$sbHtml.AppendLine('      width: 100%;')
    [void]$sbHtml.AppendLine('      background: #0F172A;')
    [void]$sbHtml.AppendLine('      border: 1px solid var(--border);')
    [void]$sbHtml.AppendLine('      color: var(--text);')
    [void]$sbHtml.AppendLine('      padding: 8px 12px 8px 36px;')
    [void]$sbHtml.AppendLine('      border-radius: 8px;')
    [void]$sbHtml.AppendLine('      font-size: 13px;')
    [void]$sbHtml.AppendLine('      outline: none;')
    [void]$sbHtml.AppendLine('      transition: border-color 0.2s;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .search-box input:focus {')
    [void]$sbHtml.AppendLine('      border-color: var(--cyan);')
    [void]$sbHtml.AppendLine('      box-shadow: 0 0 0 2px rgba(6, 182, 212, 0.2);')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .search-icon {')
    [void]$sbHtml.AppendLine('      position: absolute;')
    [void]$sbHtml.AppendLine('      left: 12px;')
    [void]$sbHtml.AppendLine('      top: 50%;')
    [void]$sbHtml.AppendLine('      transform: translateY(-50%);')
    [void]$sbHtml.AppendLine('      color: var(--text-muted);')
    [void]$sbHtml.AppendLine('      font-size: 14px;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .btn-group {')
    [void]$sbHtml.AppendLine('      display: flex;')
    [void]$sbHtml.AppendLine('      gap: 8px;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    button.btn {')
    [void]$sbHtml.AppendLine('      background: #334155;')
    [void]$sbHtml.AppendLine('      color: #FFF;')
    [void]$sbHtml.AppendLine('      border: 1px solid #475569;')
    [void]$sbHtml.AppendLine('      padding: 7px 14px;')
    [void]$sbHtml.AppendLine('      border-radius: 6px;')
    [void]$sbHtml.AppendLine('      font-size: 12.5px;')
    [void]$sbHtml.AppendLine('      font-weight: 600;')
    [void]$sbHtml.AppendLine('      cursor: pointer;')
    [void]$sbHtml.AppendLine('      transition: all 0.2s;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    button.btn:hover {')
    [void]$sbHtml.AppendLine('      background: #475569;')
    [void]$sbHtml.AppendLine('      border-color: var(--cyan);')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    button.btn-primary {')
    [void]$sbHtml.AppendLine('      background: linear-gradient(135deg, #10B981, #059669);')
    [void]$sbHtml.AppendLine('      border: none;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    button.btn-primary:hover { opacity: 0.9; }')
    [void]$sbHtml.AppendLine('    .tree-container {')
    [void]$sbHtml.AppendLine('      background: var(--card-bg);')
    [void]$sbHtml.AppendLine('      border: 1px solid var(--border);')
    [void]$sbHtml.AppendLine('      border-radius: 12px;')
    [void]$sbHtml.AppendLine('      padding: 20px;')
    [void]$sbHtml.AppendLine('      overflow-x: auto;')
    [void]$sbHtml.AppendLine('      overflow-y: auto;')
    [void]$sbHtml.AppendLine('      max-height: 78vh;')
    [void]$sbHtml.AppendLine('      box-shadow: 0 4px 20px rgba(0,0,0,0.25);')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .tree-list {')
    [void]$sbHtml.AppendLine('      list-style: none;')
    [void]$sbHtml.AppendLine('      padding-left: 24px;')
    [void]$sbHtml.AppendLine('      margin: 0;')
    [void]$sbHtml.AppendLine('      white-space: nowrap;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .tree-container > .tree-list {')
    [void]$sbHtml.AppendLine('      padding-left: 0;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .tree-item {')
    [void]$sbHtml.AppendLine('      margin: 3px 0;')
    [void]$sbHtml.AppendLine('      position: relative;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .node-row {')
    [void]$sbHtml.AppendLine('      display: inline-flex;')
    [void]$sbHtml.AppendLine('      align-items: center;')
    [void]$sbHtml.AppendLine('      padding: 4px 10px;')
    [void]$sbHtml.AppendLine('      border-radius: 6px;')
    [void]$sbHtml.AppendLine('      transition: background 0.15s;')
    [void]$sbHtml.AppendLine('      cursor: default;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .node-row:hover {')
    [void]$sbHtml.AppendLine('      background: rgba(51, 65, 85, 0.6);')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .toggle-btn {')
    [void]$sbHtml.AppendLine('      background: none;')
    [void]$sbHtml.AppendLine('      border: none;')
    [void]$sbHtml.AppendLine('      color: var(--cyan);')
    [void]$sbHtml.AppendLine('      font-size: 11px;')
    [void]$sbHtml.AppendLine('      cursor: pointer;')
    [void]$sbHtml.AppendLine('      width: 20px;')
    [void]$sbHtml.AppendLine('      height: 20px;')
    [void]$sbHtml.AppendLine('      display: inline-flex;')
    [void]$sbHtml.AppendLine('      align-items: center;')
    [void]$sbHtml.AppendLine('      justify-content: center;')
    [void]$sbHtml.AppendLine('      border-radius: 4px;')
    [void]$sbHtml.AppendLine('      margin-right: 4px;')
    [void]$sbHtml.AppendLine('      user-select: none;')
    [void]$sbHtml.AppendLine('      transition: transform 0.2s;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .toggle-btn.collapsed {')
    [void]$sbHtml.AppendLine('      transform: rotate(-90deg);')
    [void]$sbHtml.AppendLine('      color: var(--text-muted);')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .spacer {')
    [void]$sbHtml.AppendLine('      width: 24px;')
    [void]$sbHtml.AppendLine('      display: inline-block;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .icon {')
    [void]$sbHtml.AppendLine('      font-size: 15px;')
    [void]$sbHtml.AppendLine('      margin-right: 8px;')
    [void]$sbHtml.AppendLine('      user-select: none;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .item-name {')
    [void]$sbHtml.AppendLine('      font-size: 13.5px;')
    [void]$sbHtml.AppendLine('      font-weight: 500;')
    [void]$sbHtml.AppendLine('      margin-right: 12px;')
    [void]$sbHtml.AppendLine('      user-select: text;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .folder-name {')
    [void]$sbHtml.AppendLine('      color: #38BDF8;')
    [void]$sbHtml.AppendLine('      font-weight: 650;')
    [void]$sbHtml.AppendLine('      cursor: pointer;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .folder-name:hover {')
    [void]$sbHtml.AppendLine('      text-decoration: underline;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .file-name {')
    [void]$sbHtml.AppendLine('      color: #F8FAFC;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .badge {')
    [void]$sbHtml.AppendLine('      font-size: 11px;')
    [void]$sbHtml.AppendLine('      padding: 2px 7px;')
    [void]$sbHtml.AppendLine('      border-radius: 4px;')
    [void]$sbHtml.AppendLine('      margin-right: 8px;')
    [void]$sbHtml.AppendLine('      font-weight: 600;')
    [void]$sbHtml.AppendLine('      user-select: none;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .size-badge {')
    [void]$sbHtml.AppendLine('      background: #0F172A;')
    [void]$sbHtml.AppendLine('      color: #A78BFA;')
    [void]$sbHtml.AppendLine('      border: 1px solid #334155;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .count-badge {')
    [void]$sbHtml.AppendLine('      background: #0F172A;')
    [void]$sbHtml.AppendLine('      color: #34D399;')
    [void]$sbHtml.AppendLine('      border: 1px solid #334155;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .dup-badge {')
    [void]$sbHtml.AppendLine('      background: rgba(244, 63, 94, 0.2);')
    [void]$sbHtml.AppendLine('      color: #FB7185;')
    [void]$sbHtml.AppendLine('      border: 1px solid #F43F5E;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .ver-badge {')
    [void]$sbHtml.AppendLine('      background: rgba(6, 182, 212, 0.2);')
    [void]$sbHtml.AppendLine('      color: #38BDF8;')
    [void]$sbHtml.AppendLine('      border: 1px solid #06B6D4;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .copy-btn {')
    [void]$sbHtml.AppendLine('      opacity: 0;')
    [void]$sbHtml.AppendLine('      background: #334155;')
    [void]$sbHtml.AppendLine('      color: #CBD5E1;')
    [void]$sbHtml.AppendLine('      border: 1px solid #475569;')
    [void]$sbHtml.AppendLine('      border-radius: 4px;')
    [void]$sbHtml.AppendLine('      font-size: 10.5px;')
    [void]$sbHtml.AppendLine('      padding: 2px 8px;')
    [void]$sbHtml.AppendLine('      cursor: pointer;')
    [void]$sbHtml.AppendLine('      margin-left: 8px;')
    [void]$sbHtml.AppendLine('      transition: opacity 0.2s, background 0.2s;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .node-row:hover .copy-btn {')
    [void]$sbHtml.AppendLine('      opacity: 1;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .copy-btn:hover {')
    [void]$sbHtml.AppendLine('      background: var(--cyan);')
    [void]$sbHtml.AppendLine('      color: #000;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .children-container.collapsed {')
    [void]$sbHtml.AppendLine('      display: none;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .highlight {')
    [void]$sbHtml.AppendLine('      background: rgba(245, 158, 11, 0.35);')
    [void]$sbHtml.AppendLine('      color: #FDE68A;')
    [void]$sbHtml.AppendLine('      border-radius: 2px;')
    [void]$sbHtml.AppendLine('      padding: 0 2px;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    #toast {')
    [void]$sbHtml.AppendLine('      position: fixed;')
    [void]$sbHtml.AppendLine('      bottom: 24px;')
    [void]$sbHtml.AppendLine('      right: 24px;')
    [void]$sbHtml.AppendLine('      background: #10B981;')
    [void]$sbHtml.AppendLine('      color: #FFF;')
    [void]$sbHtml.AppendLine('      padding: 10px 20px;')
    [void]$sbHtml.AppendLine('      border-radius: 8px;')
    [void]$sbHtml.AppendLine('      font-size: 13px;')
    [void]$sbHtml.AppendLine('      font-weight: 600;')
    [void]$sbHtml.AppendLine('      box-shadow: 0 4px 16px rgba(0,0,0,0.4);')
    [void]$sbHtml.AppendLine('      opacity: 0;')
    [void]$sbHtml.AppendLine('      transform: translateY(20px);')
    [void]$sbHtml.AppendLine('      transition: all 0.25s ease;')
    [void]$sbHtml.AppendLine('      z-index: 1000;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    #toast.show {')
    [void]$sbHtml.AppendLine('      opacity: 1;')
    [void]$sbHtml.AppendLine('      transform: translateY(0);')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    #contextMenu {')
    [void]$sbHtml.AppendLine('      position: fixed;')
    [void]$sbHtml.AppendLine('      display: none;')
    [void]$sbHtml.AppendLine('      min-width: 230px;')
    [void]$sbHtml.AppendLine('      padding: 6px;')
    [void]$sbHtml.AppendLine('      background: #0F172A;')
    [void]$sbHtml.AppendLine('      border: 1px solid #475569;')
    [void]$sbHtml.AppendLine('      border-radius: 8px;')
    [void]$sbHtml.AppendLine('      box-shadow: 0 10px 30px rgba(0,0,0,0.55);')
    [void]$sbHtml.AppendLine('      z-index: 2000;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    #contextMenu.show {')
    [void]$sbHtml.AppendLine('      display: block;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .context-menu-item {')
    [void]$sbHtml.AppendLine('      display: block;')
    [void]$sbHtml.AppendLine('      width: 100%;')
    [void]$sbHtml.AppendLine('      padding: 8px 10px;')
    [void]$sbHtml.AppendLine('      background: transparent;')
    [void]$sbHtml.AppendLine('      border: 0;')
    [void]$sbHtml.AppendLine('      color: var(--text);')
    [void]$sbHtml.AppendLine('      text-align: left;')
    [void]$sbHtml.AppendLine('      font: inherit;')
    [void]$sbHtml.AppendLine('      font-size: 12.5px;')
    [void]$sbHtml.AppendLine('      cursor: pointer;')
    [void]$sbHtml.AppendLine('      border-radius: 5px;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    .context-menu-item:hover {')
    [void]$sbHtml.AppendLine('      background: #334155;')
    [void]$sbHtml.AppendLine('      color: var(--cyan-hover);')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    #contextMenu .divider {')
    [void]$sbHtml.AppendLine('      height: 1px;')
    [void]$sbHtml.AppendLine('      margin: 5px 4px;')
    [void]$sbHtml.AppendLine('      background: #334155;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('  </style>')
    [void]$sbHtml.AppendLine('</head>')
    [void]$sbHtml.AppendLine('<body>')
    [void]$sbHtml.AppendLine('  <div class="header">')
    [void]$sbHtml.AppendLine('    <div class="title-group">')
    [void]$sbHtml.AppendLine('      <h1>&#128193; Scan Me! Root Tree</h1>')
    [void]$sbHtml.AppendLine("      <p>Target: $escRootPath</p>")
    [void]$sbHtml.AppendLine('    </div>')
    [void]$sbHtml.AppendLine('    <div class="stats-bar">')
    [void]$sbHtml.AppendLine("      <div class=`"stat-pill`">Total Files: <span>$($meta.Total_Files)</span></div>")
    [void]$sbHtml.AppendLine("      <div class=`"stat-pill`">Total Size: <span>$($meta.Total_Size_Human)</span></div>")
    [void]$sbHtml.AppendLine("      <div class=`"stat-pill`">Scanned: <span>$($meta.Scan_Timestamp)</span></div>")
    [void]$sbHtml.AppendLine('    </div>')
    [void]$sbHtml.AppendLine('  </div>')
    [void]$sbHtml.AppendLine('  <div class="toolbar">')
    [void]$sbHtml.AppendLine('    <div class="search-box">')
    [void]$sbHtml.AppendLine('      <span class="search-icon">&#128269;</span>')
    [void]$sbHtml.AppendLine('      <input type="text" id="searchInput" placeholder="Search file or folder name in tree..." oninput="filterTree()">')
    [void]$sbHtml.AppendLine('    </div>')
    [void]$sbHtml.AppendLine('    <div class="btn-group">')
    [void]$sbHtml.AppendLine('      <button class="btn" onclick="expandAll()" title="Expand all folders">&#9660; Expand All</button>')
    [void]$sbHtml.AppendLine('      <button class="btn" onclick="collapseAll()" title="Collapse all folders">&#9654; Collapse All</button>')
    [void]$sbHtml.AppendLine('      <button class="btn btn-primary" onclick="copyEntireTreeText()" title="Copy entire tree as text">&#128203; Copy Tree Text</button>')
    [void]$sbHtml.AppendLine('    </div>')
    [void]$sbHtml.AppendLine('  </div>')
    [void]$sbHtml.AppendLine('  <div class="tree-container" id="treeContainer">')
    [void]$sbHtml.AppendLine($treeBody)
    [void]$sbHtml.AppendLine('  </div>')
    [void]$sbHtml.AppendLine('  <div id="toast">Path copied to clipboard!</div>')
    [void]$sbHtml.AppendLine('  <div id="contextMenu" role="menu" aria-hidden="true">')
    [void]$sbHtml.AppendLine('    <button class="context-menu-item" id="contextOpenItem" type="button"></button>')
    [void]$sbHtml.AppendLine('    <button class="context-menu-item" id="contextCopyItem" type="button">&#128203; Copy Path</button>')
    [void]$sbHtml.AppendLine('  </div>')
    [void]$sbHtml.AppendLine('  <script>')
    [void]$sbHtml.AppendLine("    const TREE_DATA = $copyTreeJson;")
    [void]$sbHtml.AppendLine('    function toggleNode(btn) {')
    [void]$sbHtml.AppendLine('      const parentLi = btn.closest(".folder-item");')
    [void]$sbHtml.AppendLine('      const container = parentLi.querySelector(":scope > .children-container");')
    [void]$sbHtml.AppendLine('      if (container) {')
    [void]$sbHtml.AppendLine('        container.classList.toggle("collapsed");')
    [void]$sbHtml.AppendLine('        btn.classList.toggle("collapsed");')
    [void]$sbHtml.AppendLine('      }')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    function toggleRow(nameSpan) {')
    [void]$sbHtml.AppendLine('      const parentLi = nameSpan.closest(".folder-item");')
    [void]$sbHtml.AppendLine('      const btn = parentLi.querySelector(":scope > .node-row > .toggle-btn");')
    [void]$sbHtml.AppendLine('      if (btn) toggleNode(btn);')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    function expandAll() {')
    [void]$sbHtml.AppendLine('      document.querySelectorAll(".children-container").forEach(el => el.classList.remove("collapsed"));')
    [void]$sbHtml.AppendLine('      document.querySelectorAll(".toggle-btn").forEach(el => el.classList.remove("collapsed"));')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    function collapseAll() {')
    [void]$sbHtml.AppendLine('      document.querySelectorAll(".children-container").forEach(el => el.classList.add("collapsed"));')
    [void]$sbHtml.AppendLine('      document.querySelectorAll(".toggle-btn").forEach(el => el.classList.add("collapsed"));')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    function copyPath(btn, path) {')
    [void]$sbHtml.AppendLine('      const winPath = String(path || "").replace(/\//g, "\\");')
    [void]$sbHtml.AppendLine('      navigator.clipboard.writeText(winPath).then(() => {')
    [void]$sbHtml.AppendLine('        showToast("Copied: " + winPath);')
    [void]$sbHtml.AppendLine('      });')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    function showToast(msg) {')
    [void]$sbHtml.AppendLine('      const t = document.getElementById("toast");')
    [void]$sbHtml.AppendLine('      t.innerText = msg;')
    [void]$sbHtml.AppendLine('      t.classList.add("show");')
    [void]$sbHtml.AppendLine('      setTimeout(() => { t.classList.remove("show"); }, 2200);')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    const OPEN_PROTOCOL_PREFIX = "scanme://open?path=";')
    [void]$sbHtml.AppendLine('    function buildOpenProtocolUrl(path) {')
    [void]$sbHtml.AppendLine('      const winPath = String(path || "").replace(/\//g, "\\");')
    [void]$sbHtml.AppendLine('      return OPEN_PROTOCOL_PREFIX + encodeURIComponent(winPath);')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    let contextMenuTarget = null;')
    [void]$sbHtml.AppendLine('    function closeContextMenu() {')
    [void]$sbHtml.AppendLine('      const menu = document.getElementById("contextMenu");')
    [void]$sbHtml.AppendLine('      if (menu) {')
    [void]$sbHtml.AppendLine('        menu.classList.remove("show");')
    [void]$sbHtml.AppendLine('        menu.setAttribute("aria-hidden", "true");')
    [void]$sbHtml.AppendLine('      }')
    [void]$sbHtml.AppendLine('      contextMenuTarget = null;')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    function openSelectedPath(path) {')
    [void]$sbHtml.AppendLine('      if (!path) return;')
    [void]$sbHtml.AppendLine('      closeContextMenu();')
    [void]$sbHtml.AppendLine('      showToast("Opening… If nothing happens, the protocol is not registered yet. Run tools\\register_protocol.ps1 once (see README).");')
    [void]$sbHtml.AppendLine('      window.location.href = buildOpenProtocolUrl(path);')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    function showContextMenu(event, row) {')
    [void]$sbHtml.AppendLine('      closeContextMenu();')
    [void]$sbHtml.AppendLine('      const target = row.closest(".tree-item");')
    [void]$sbHtml.AppendLine('      if (!target) return;')
    [void]$sbHtml.AppendLine('      const isFolder = target.classList.contains("folder-item");')
    [void]$sbHtml.AppendLine('      const path = target.getAttribute("data-path") || "";')
    [void]$sbHtml.AppendLine('      const menu = document.getElementById("contextMenu");')
    [void]$sbHtml.AppendLine('      const openItem = document.getElementById("contextOpenItem");')
    [void]$sbHtml.AppendLine('      if (!menu || !openItem) return;')
    [void]$sbHtml.AppendLine('      contextMenuTarget = target;')
    [void]$sbHtml.AppendLine('      openItem.textContent = isFolder ? "\u{1F4C2} Open Folder in Explorer" : "\u{1F4C4} Open File (default app)";')
    [void]$sbHtml.AppendLine('      openItem.onclick = () => openSelectedPath(contextMenuTarget && contextMenuTarget.getAttribute("data-path"));')
    [void]$sbHtml.AppendLine('      const copyItem = document.getElementById("contextCopyItem");')
    [void]$sbHtml.AppendLine('      if (copyItem) copyItem.onclick = () => {')
    [void]$sbHtml.AppendLine('        const selected = contextMenuTarget;')
    [void]$sbHtml.AppendLine('        closeContextMenu();')
    [void]$sbHtml.AppendLine('        copyPath(null, selected && selected.getAttribute("data-path"));')
    [void]$sbHtml.AppendLine('      };')
    [void]$sbHtml.AppendLine('      menu.style.left = event.clientX + "px";')
    [void]$sbHtml.AppendLine('      menu.style.top = event.clientY + "px";')
    [void]$sbHtml.AppendLine('      menu.classList.add("show");')
    [void]$sbHtml.AppendLine('      menu.setAttribute("aria-hidden", "false");')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    function initContextMenu() {')
    [void]$sbHtml.AppendLine('      if (typeof document === "undefined" || !document.addEventListener) return;')
    [void]$sbHtml.AppendLine('      document.addEventListener("contextmenu", (event) => {')
    [void]$sbHtml.AppendLine('        const row = event.target && event.target.closest ? event.target.closest(".node-row") : null;')
    [void]$sbHtml.AppendLine('        if (row) {')
    [void]$sbHtml.AppendLine('          event.preventDefault();')
    [void]$sbHtml.AppendLine('          showContextMenu(event, row);')
    [void]$sbHtml.AppendLine('        } else {')
    [void]$sbHtml.AppendLine('          closeContextMenu();')
    [void]$sbHtml.AppendLine('        }')
    [void]$sbHtml.AppendLine('      });')
    [void]$sbHtml.AppendLine('      document.addEventListener("click", () => closeContextMenu());')
    [void]$sbHtml.AppendLine('      document.addEventListener("keydown", (event) => {')
    [void]$sbHtml.AppendLine('        if (event.key === "Escape") closeContextMenu();')
    [void]$sbHtml.AppendLine('      });')
    [void]$sbHtml.AppendLine('      document.addEventListener("scroll", closeContextMenu, true);')
    [void]$sbHtml.AppendLine('      if (typeof window !== "undefined" && window.addEventListener) window.addEventListener("scroll", closeContextMenu, true);')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    initContextMenu();')
    [void]$sbHtml.AppendLine('    function copyEntireTreeText() {')
    [void]$sbHtml.AppendLine('      // Walk the embedded data model (TREE_DATA), NOT the DOM, so the copied text')
    [void]$sbHtml.AppendLine('      // always contains the FULL tree (paths, sizes, counts) regardless of expand/collapse.')
    [void]$sbHtml.AppendLine('      const winPath = p => String(p || "").replace(/\//g, "\\");')
    [void]$sbHtml.AppendLine('      const formatNode = node => {')
    [void]$sbHtml.AppendLine('        const icon = node.icon || (node.type === "directory" ? "\u{1F4C1}" : "\u{1F4C4}");')
    [void]$sbHtml.AppendLine('        let details;')
    [void]$sbHtml.AppendLine('        if (node.type === "directory") {')
    [void]$sbHtml.AppendLine('          details = node.size + ", " + (node.count || 0) + " items";')
    [void]$sbHtml.AppendLine('        } else if (node.version) {')
    [void]$sbHtml.AppendLine('          details = node.size + ", v" + node.version;')
    [void]$sbHtml.AppendLine('        } else {')
    [void]$sbHtml.AppendLine('          details = node.size;')
    [void]$sbHtml.AppendLine('        }')
    [void]$sbHtml.AppendLine('        return icon + " " + winPath(node.path) + " (" + details + ")";')
    [void]$sbHtml.AppendLine('      };')
    [void]$sbHtml.AppendLine('      const lines = [formatNode(TREE_DATA)];')
    [void]$sbHtml.AppendLine('      const renderChildren = (node, prefix) => {')
    [void]$sbHtml.AppendLine('        const children = Array.isArray(node.children) ? node.children : [];')
    [void]$sbHtml.AppendLine('        children.forEach((child, i) => {')
    [void]$sbHtml.AppendLine('          const isLast = i === children.length - 1;')
    [void]$sbHtml.AppendLine('          lines.push(prefix + (isLast ? "\u2514\u2500\u2500 " : "\u251C\u2500\u2500 ") + formatNode(child));')
    [void]$sbHtml.AppendLine('          if (child.type === "directory") {')
    [void]$sbHtml.AppendLine('            renderChildren(child, prefix + (isLast ? "    " : "\u2502   "));')
    [void]$sbHtml.AppendLine('          }')
    [void]$sbHtml.AppendLine('        });')
    [void]$sbHtml.AppendLine('      };')
    [void]$sbHtml.AppendLine('      renderChildren(TREE_DATA, "");')
    [void]$sbHtml.AppendLine('      navigator.clipboard.writeText(lines.join("\n")).then(() => {')
    [void]$sbHtml.AppendLine('        showToast("Copied!");')
    [void]$sbHtml.AppendLine('      });')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('    function filterTree() {')
    [void]$sbHtml.AppendLine('      const q = document.getElementById("searchInput").value.trim().toLowerCase();')
    [void]$sbHtml.AppendLine('      const items = document.querySelectorAll(".tree-item");')
    [void]$sbHtml.AppendLine('      if (!q) {')
    [void]$sbHtml.AppendLine('        items.forEach(item => {')
    [void]$sbHtml.AppendLine('          item.style.display = "";')
    [void]$sbHtml.AppendLine('          const nameSpan = item.querySelector(".item-name");')
    [void]$sbHtml.AppendLine('          if (nameSpan) nameSpan.innerHTML = nameSpan.textContent;')
    [void]$sbHtml.AppendLine('        });')
    [void]$sbHtml.AppendLine('        return;')
    [void]$sbHtml.AppendLine('      }')
    [void]$sbHtml.AppendLine('      expandAll();')
    [void]$sbHtml.AppendLine('      items.forEach(item => {')
    [void]$sbHtml.AppendLine('        const name = item.getAttribute("data-name") || "";')
    [void]$sbHtml.AppendLine('        const nameSpan = item.querySelector(".item-name");')
    [void]$sbHtml.AppendLine('        if (name.toLowerCase().includes(q)) {')
    [void]$sbHtml.AppendLine('          item.style.display = "";')
    [void]$sbHtml.AppendLine('          const escQ = q.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");')
    [void]$sbHtml.AppendLine('          const reg = new RegExp("(" + escQ + ")", "gi");')
    [void]$sbHtml.AppendLine('          nameSpan.innerHTML = name.replace(reg, `<span class="highlight">$1</span>`);')
    [void]$sbHtml.AppendLine('          let p = item.parentElement.closest(".tree-item");')
    [void]$sbHtml.AppendLine('          while (p) {')
    [void]$sbHtml.AppendLine('            p.style.display = "";')
    [void]$sbHtml.AppendLine('            p = p.parentElement.closest(".tree-item");')
    [void]$sbHtml.AppendLine('          }')
    [void]$sbHtml.AppendLine('        } else {')
    [void]$sbHtml.AppendLine('          const hasMatchingChild = item.querySelector(`.tree-item[data-name*="${q}"]`);')
    [void]$sbHtml.AppendLine('          if (!hasMatchingChild) {')
    [void]$sbHtml.AppendLine('            item.style.display = "none";')
    [void]$sbHtml.AppendLine('          } else {')
    [void]$sbHtml.AppendLine('            item.style.display = "";')
    [void]$sbHtml.AppendLine('          }')
    [void]$sbHtml.AppendLine('        }')
    [void]$sbHtml.AppendLine('      });')
    [void]$sbHtml.AppendLine('    }')
    [void]$sbHtml.AppendLine('  </script>')
    [void]$sbHtml.AppendLine('</body>')
    [void]$sbHtml.AppendLine('</html>')

    $htmlContent = $sbHtml.ToString()

    # There must be exactly one protocol declaration, shared by folder and file
    # actions. Validate every emitted 'scanme://open' reference, not just one
    # known prefix, so a second folder/file template cannot bypass this guard.
    $canonicalProtocolPrefix = 'scanme://open?path='
    $protocolReferences = [regex]::Matches($htmlContent, [regex]::Escape('scanme://open'))
    if ($protocolReferences.Count -ne 1) {
        throw "HTML export must contain exactly one scanme://open protocol declaration; found $($protocolReferences.Count)."
    }
    foreach ($protocolReference in $protocolReferences) {
        $tailStart = $protocolReference.Index + $protocolReference.Length
        $protocolTail = $htmlContent.Substring($tailStart)
        if (!$protocolTail.StartsWith($canonicalProtocolPrefix.Substring('scanme://open'.Length), [System.StringComparison]::Ordinal)) {
            throw "HTML export contains a malformed scanme protocol URL near index $($protocolReference.Index)."
        }
    }
    if ($protocolReferences[0].Index -lt 0 -or !$htmlContent.Contains($canonicalProtocolPrefix)) {
        throw "HTML export does not contain the canonical $canonicalProtocolPrefix URL prefix."
    }

    [System.IO.File]::WriteAllText($OutputPath, $htmlContent, [System.Text.Encoding]::UTF8)
}