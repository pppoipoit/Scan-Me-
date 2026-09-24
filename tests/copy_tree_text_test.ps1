<#
.SYNOPSIS
    Verification test: "Copy Tree Text" button in the exported interactive HTML tree.
.DESCRIPTION
    Root cause (fixed): src/utils/Helpers.ps1 copyEntireTreeText() copied
    #treeContainer.innerText => (a) collapsed folders are display:none and dropped by
    innerText, (b) no full paths, (c) no tree structure characters.
    Fix: embed TREE_DATA (complete data model as compressed JSON) in the <script> block
    and walk that model instead of the DOM.
    Asserts:
      1. Export-ScanResultToHtmlTree runs from current source
      2. Extracted <script> passes `node --check`
      3. TREE_DATA embedded, parses as JSON, contains EVERY scanned file path
      4. Functional (Node; document stubbed ONLY for toast => DOM walk would throw):
         full backslash paths, tree chars, deeper indent for deeper nodes,
         folder "(size, N items)", file "(size)", exe "(size, vX)", toast "Copied!"
      5. Line count == 1 root + folders + files (full tree, independent of UI state)
      6. Forward-slash Target_Folder/Full_Path normalized to backslashes
    Exit code 0 = ALL PASS, 1 = FAIL
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$failCount = 0
function Assert { param([string]$Name, [bool]$Ok, [string]$Detail = '')
    if ($Ok) { Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else     { Write-Host "  [FAIL] $Name  $Detail" -ForegroundColor Red; $script:failCount++ } }

# Tree chars / icons as code points (repo convention: pure-ASCII source, encoding-safe)
$cBranch = "$([char]0x251C)$([char]0x2500)$([char]0x2500) "  # branch connector
$cLeaf   = "$([char]0x2514)$([char]0x2500)$([char]0x2500) "  # last connector
$cPipe   = "$([char]0x2502)   "                               # pipe + 3 spaces
$icoDir  = [System.Net.WebUtility]::HtmlDecode('&#128193;')   # folder icon
$icoExe  = [System.Net.WebUtility]::HtmlDecode('&#9889;')     # exe icon
$icoDoc  = [System.Net.WebUtility]::HtmlDecode('&#128209;')   # .md (docs) icon

function Get-ModelPaths($n) { $out = @($n.path); foreach ($c in $n.children) { $out += Get-ModelPaths $c }; return $out }
function Count-ModelNodes($n) { $c = 1; foreach ($ch in $n.children) { $c += Count-ModelNodes $ch }; return $c }

Write-Host "=== Copy Tree Text Verification Test ===" -ForegroundColor Cyan

# --- Shared harness: eval script, call copyEntireTreeText, capture clipboard + toast ---
$hs = @'
const fs = require("fs");
const jsSrc = fs.readFileSync(process.argv[2], "utf8");
const outPath = process.argv[3];
eval(jsSrc);
if (typeof copyEntireTreeText !== "function") { console.error("copyEntireTreeText undefined"); process.exit(2); }
let copied = null;
const toastEl = { innerText: "", classList: { add: () => {}, remove: () => {} } };
// document stub serves ONLY "toast". getElementById("treeContainer") => null, so the OLD
// DOM implementation (#treeContainer.innerText) would throw => proof the fix walks TREE_DATA.
const docStub = { getElementById: id => (id === "toast" ? toastEl : null) };
try { Object.defineProperty(globalThis, "document", { value: docStub, configurable: true, writable: true }); }
catch (e) { global.document = docStub; }
const navStub = { clipboard: { writeText: t => { copied = t; return { then: cb => cb() }; } } };
try { Object.defineProperty(globalThis, "navigator", { value: navStub, configurable: true, writable: true }); }
catch (e) { global.navigator = navStub; }
copyEntireTreeText();
if (typeof copied !== "string") { console.error("nothing copied"); process.exit(3); }
if (toastEl.innerText !== "Copied!") { console.error("toast=" + JSON.stringify(toastEl.innerText)); process.exit(4); }
if (copied.indexOf("/") !== -1) { console.error("forward slash in copied text"); process.exit(5); }
fs.writeFileSync(outPath, copied, "utf8");
console.log("lines=" + copied.split("\n").length + " toast=" + toastEl.innerText);
'@

# --- [1] Fresh export from current source ---
Write-Host "[1/6] Exporting fresh HTML from latest_scan.json..." -ForegroundColor Yellow
. (Join-Path $root 'src\utils\Helpers.ps1')
$tmpHtml  = Join-Path $PSScriptRoot '_tmp_copy_tree_export.html'
$tmpJs    = Join-Path $PSScriptRoot '_tmp_copy_tree_script.js'
$tmpTxt   = Join-Path $PSScriptRoot '_tmp_copy_tree_copied.txt'
$harness  = Join-Path $PSScriptRoot '_tmp_copy_tree_harness.js'
$miniHtml = Join-Path $PSScriptRoot '_tmp_copy_tree_mini.html'
$miniJs   = Join-Path $PSScriptRoot '_tmp_copy_tree_mini_script.js'
$miniTxt  = Join-Path $PSScriptRoot '_tmp_copy_tree_mini_copied.txt'
$scan = Get-Content -Raw -LiteralPath (Join-Path $root 'output\latest_scan.json') | ConvertFrom-Json
$exportOk = $false
try { Export-ScanResultToHtmlTree -ScanResult $scan -OutputPath $tmpHtml; $exportOk = Test-Path -LiteralPath $tmpHtml }
catch { Write-Host "  export error: $($_.Exception.Message)" -ForegroundColor Red }
Assert "Export-ScanResultToHtmlTree runs" $exportOk
[System.IO.File]::WriteAllText($harness, $hs, [System.Text.UTF8Encoding]::new($false))

# --- [2] node --check ---
Write-Host "[2/6] node --check on extracted <script>..." -ForegroundColor Yellow
$html = [System.IO.File]::ReadAllText($tmpHtml)
$m = [regex]::Match($html, '(?s)<script>(.*)</script>')
Assert "Script block found" $m.Success
[System.IO.File]::WriteAllText($tmpJs, $m.Groups[1].Value, [System.Text.UTF8Encoding]::new($false))
node --check $tmpJs
Assert "node --check parses (no SyntaxError)" ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"
Assert "Old DOM-based copy removed (container.innerText gone)" (-not $html.Contains('container.innerText'))

# --- [3] TREE_DATA embedded + complete ---
Write-Host "[3/6] Validating embedded TREE_DATA model..." -ForegroundColor Yellow
$mData = [regex]::Match($html, 'const TREE_DATA = (\{.*\});')
Assert "TREE_DATA embedded in <script>" $mData.Success
$model = $null
try { $model = $mData.Groups[1].Value | ConvertFrom-Json } catch { Write-Host "  parse error: $($_.Exception.Message)" -ForegroundColor Red }
Assert "TREE_DATA parses as JSON" ($null -ne $model)
$paths = @(); if ($model) { $paths = Get-ModelPaths $model }
$missing = @($scan.Files | Where-Object { [string]$_.Full_Path -notin $paths })
Assert "Model holds every scanned file path ($(@($scan.Files).Count) files)" ($missing.Count -eq 0) (($missing | ForEach-Object Full_Path) -join ', ')

# --- [4] Functional: copy full tree from model (no DOM available) ---
Write-Host "[4/6] copyEntireTreeText() end-to-end (Node, toast-only DOM stub)..." -ForegroundColor Yellow
node $harness $tmpJs $tmpTxt
Assert "Copied text produced, toast 'Copied!', no '/' (backslash-normalized)" ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"
$copiedText = if (Test-Path -LiteralPath $tmpTxt) { [System.IO.File]::ReadAllText($tmpTxt) } else { '' }
$lines = @($copiedText -split "`n")
$target = ([string]$scan.Scan_Meta.Target_Folder).Replace('/', '\')
Assert "Root line = folder icon + full target path" ($lines.Count -gt 0 -and $lines[0].StartsWith("$icoDir $target (")) $lines[0]
$notFound = @($scan.Files | Where-Object { -not $copiedText.Contains([string]$_.Full_Path) })
Assert "Every file full path present in copied text" ($notFound.Count -eq 0) (($notFound | ForEach-Object File_Name) -join ', ')
$folderLine = $lines | Where-Object { $_ -match [regex]::Escape("$target\src (") } | Select-Object -First 1
$fileLine   = $lines | Where-Object { $_ -match [regex]::Escape('src\utils\Helpers.ps1 (') } | Select-Object -First 1
Assert "Folder line with size + item count" ([bool]($folderLine -match ',\s*\d+\s*items\)$')) $folderLine
Assert "Nested file line with size" ([bool]($fileLine -match '\(\d+(\.\d+)?\s*(Bytes|KB|MB|GB)(,\s*v.+\))?\)$')) $fileLine
Assert "Tree branch/leaf/pipe chars present" ($copiedText.Contains($cBranch) -and $copiedText.Contains($cLeaf) -and $copiedText.Contains($cPipe))
if ($folderLine -and $fileLine) {
    $fIdx = $fileLine.IndexOf($cBranch); if ($fIdx -lt 0) { $fIdx = $fileLine.IndexOf($cLeaf) }
    $dIdx = $folderLine.IndexOf($cBranch); if ($dIdx -lt 0) { $dIdx = $folderLine.IndexOf($cLeaf) }
    Assert "Deeper node indented further than its folder" ($fIdx -gt $dIdx -and $dIdx -ge 0) "folder@$dIdx file@$fIdx"
} else { Assert "Deeper node indented further than its folder" $false 'folder/file line missing' }
if ($model) {
    Assert "Line count == 1 root + folders + files (FULL tree)" ($lines.Count -eq (Count-ModelNodes $model)) "got $($lines.Count), model $(Count-ModelNodes $model)"
}

# --- [5] Mini export: exe version + forward-slash normalization + exact line format ---
Write-Host "[5/6] Mini export: exe version, forward-slash normalization, exact format..." -ForegroundColor Yellow
$miniScan = [PSCustomObject]@{
    Scan_Meta = [PSCustomObject]@{ Target_Folder = 'D:/Inst_Dev/Skill/app'; Scan_Timestamp = '2026-09-24 12:00:00'; Total_Files = 3; Total_Size_Human = '1.51 MB' }
    Files = @(
        [PSCustomObject]@{ Category_Folder='app'; Relative_Path='bin\app.exe'; File_Name='app.exe'; Full_Path='D:/Inst_Dev/Skill/app/bin/app.exe'; Extension='.exe'; Size_Bytes=1572864; Size_Formatted='1.50 MB'; Hash=''; IsDuplicate=$false; Metadata=[PSCustomObject]@{ ProductVersion='1.2.3.4'; FileVersion='1.2.3.4'; CompanyName='ACME' } }
        [PSCustomObject]@{ Category_Folder='app'; Relative_Path='README.md'; File_Name='README.md'; Full_Path='D:\Inst_Dev\Skill\app\README.md'; Extension='.md'; Size_Bytes=4671; Size_Formatted='4.56 KB'; Hash=''; IsDuplicate=$false; Metadata=$null }
        [PSCustomObject]@{ Category_Folder='app'; Relative_Path='src/deep/nested.py'; File_Name='nested.py'; Full_Path='D:/Inst_Dev/Skill/app/src/deep/nested.py'; Extension='.py'; Size_Bytes=892; Size_Formatted='892 Bytes'; Hash=''; IsDuplicate=$false; Metadata=$null }
    )
}
$miniOk = $false
try { Export-ScanResultToHtmlTree -ScanResult $miniScan -OutputPath $miniHtml; $miniOk = Test-Path -LiteralPath $miniHtml }
catch { Write-Host "  mini export error: $($_.Exception.Message)" -ForegroundColor Red }
Assert "Mini export runs" $miniOk
$miniHtmlText = [System.IO.File]::ReadAllText($miniHtml)
$mm = [regex]::Match($miniHtmlText, '(?s)<script>(.*)</script>')
[System.IO.File]::WriteAllText($miniJs, $mm.Groups[1].Value, [System.Text.UTF8Encoding]::new($false))
node $harness $miniJs $miniTxt
Assert "Mini copy runs (toast 'Copied!', backslash-only)" ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"
$miniText = if (Test-Path -LiteralPath $miniTxt) { [System.IO.File]::ReadAllText($miniTxt) } else { '' }
$miniLines = @($miniText -split "`n")
Assert "Root line normalized to backslash target path" ($miniLines.Count -gt 0 -and $miniLines[0].StartsWith("$icoDir D:\Inst_Dev\Skill\app (")) $miniLines[0]
Assert "Exe line exact: icon + full path + size + version" $miniText.Contains("$icoExe D:\Inst_Dev\Skill\app\bin\app.exe (1.50 MB, v1.2.3.4)")
Assert "Docs line: icon + path + size" $miniText.Contains("$icoDoc D:\Inst_Dev\Skill\app\README.md (4.56 KB)")
Assert "Forward-slash Full_Path normalized to backslashes" (-not $miniText.Contains('D:/Inst_Dev'))
$pyLine = $miniLines | Where-Object { $_ -match [regex]::Escape('src\deep\nested.py (') } | Select-Object -First 1
Assert "Nested .py present at depth >= 2 (starts with pipe)" ([bool]($pyLine -and $pyLine.IndexOf($cPipe) -eq 0)) $pyLine

# --- [6] Cleanup + summary ---
Write-Host "[6/6] Cleanup temp files..." -ForegroundColor Yellow
Remove-Item -LiteralPath $tmpHtml, $tmpJs, $tmpTxt, $harness, $miniHtml, $miniJs, $miniTxt -Force -ErrorAction SilentlyContinue

if ($failCount -eq 0) { Write-Host "`nALL TESTS PASSED" -ForegroundColor Green; exit 0 }
else { Write-Host "`n$failCount TEST(S) FAILED" -ForegroundColor Red; exit 1 }
