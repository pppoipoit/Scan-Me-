<#
.SYNOPSIS
    Verification test: dropdown toggle buttons in the exported interactive HTML tree.
.DESCRIPTION
    Root cause (fixed): src/utils/Helpers.ps1:750 used PS backtick-escaped quotes inside a
    single-quoted string, emitting invalid JS. The whole <script> block failed to parse so
    toggleNode() was undefined and every dropdown arrow (plus Expand/Collapse/search/copy)
    was dead when clicked in the exported HTML file.
    Asserts:
      1. Export-ScanResultToHtmlTree runs from current source
      2. Extracted <script> passes `node --check` (parse / no SyntaxError)
      3. Functional: toggleNode & toggleRow open-close the children dropdown (Node DOM stub)
      4. No PS-backtick artifact (`") leaked into generated JS
      5. No *.html left in output\ contains the broken pattern
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

Write-Host "=== HTML Export Dropdown Verification Test ===" -ForegroundColor Cyan

# --- 1) Fresh export from current source ---
Write-Host "[1/5] Exporting fresh HTML from latest_scan.json..." -ForegroundColor Yellow
. (Join-Path $root 'src\utils\Helpers.ps1')
$tmpHtml  = Join-Path $PSScriptRoot '_tmp_dropdown_export.html'
$tmpJs    = Join-Path $PSScriptRoot '_tmp_dropdown_script.js'
$harness  = Join-Path $PSScriptRoot '_tmp_dropdown_harness.js'
$scan = Get-Content -Raw -LiteralPath (Join-Path $root 'output\latest_scan.json') | ConvertFrom-Json
$exportOk = $false
try {
    Export-ScanResultToHtmlTree -ScanResult $scan -OutputPath $tmpHtml
    $exportOk = Test-Path -LiteralPath $tmpHtml
} catch {
    Write-Host "  export error: $($_.Exception.Message)" -ForegroundColor Red
}
Assert "Export-ScanResultToHtmlTree runs" $exportOk

# --- 2) Extract <script> and parse with node ---
Write-Host "[2/5] node --check on extracted <script>..." -ForegroundColor Yellow
$html = [System.IO.File]::ReadAllText($tmpHtml)
$m = [regex]::Match($html, '(?s)<script>(.*)</script>')
Assert "Script block found" $m.Success
[System.IO.File]::WriteAllText($tmpJs, $m.Groups[1].Value, [System.Text.UTF8Encoding]::new($false))
node --check $tmpJs
Assert "node --check parses (no SyntaxError)" ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"

# --- 3) Functional toggle test (Node + DOM stub) ---
Write-Host "[3/5] Functional: toggleNode/toggleRow open-close..." -ForegroundColor Yellow
$hs = @'
const fs = require("fs");
const src = fs.readFileSync(process.argv[2], "utf8");
eval(src);
function mkCls(init) { const s = new Set(init); return { toggle: c => s.has(c) ? s.delete(c) : s.add(c), add: c => s.add(c), remove: c => s.delete(c), contains: c => s.has(c) }; }
if (typeof toggleNode !== "function" || typeof toggleRow !== "function") { console.error("toggleNode/toggleRow undefined"); process.exit(2); }
const container = { classList: mkCls([]) };
const btn = { classList: mkCls([]), closest: sel => sel === ".folder-item" ? parentLi : null };
const parentLi = { querySelector: sel => sel === ":scope > .children-container" ? container : (sel === ":scope > .node-row > .toggle-btn" ? btn : null) };
toggleNode(btn);
if (!container.classList.contains("collapsed")) { console.error("1st toggle: expected .collapsed"); process.exit(3); }
toggleNode(btn);
if (container.classList.contains("collapsed")) { console.error("2nd toggle: expected open"); process.exit(4); }
const nameSpan = { closest: sel => sel === ".folder-item" ? parentLi : null };
toggleRow(nameSpan);
if (!container.classList.contains("collapsed")) { console.error("toggleRow did not collapse"); process.exit(5); }
console.log("toggleNode/toggleRow OK");
'@
[System.IO.File]::WriteAllText($harness, $hs, [System.Text.UTF8Encoding]::new($false))
node $harness $tmpJs
Assert "toggleNode/toggleRow dropdown works" ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"

# --- 4) No PS-backtick artifact anywhere ---
Write-Host "[4/5] No PS-backtick artifact in generated JS..." -ForegroundColor Yellow
$broken = 'name.replace(reg, "<span class=`"highlight`">$1</span>");'
Assert "Fresh export is clean" (-not $html.Contains($broken))
$bad = @(Get-ChildItem -LiteralPath (Join-Path $root 'output') -Filter '*.html' |
         Where-Object { [System.IO.File]::ReadAllText($_.FullName).Contains($broken) })
Assert "No broken *.html remains in output\" ($bad.Count -eq 0) (($bad | ForEach-Object Name) -join ', ')

# --- 5) Cleanup + summary ---
Write-Host "[5/5] Cleanup temp files..." -ForegroundColor Yellow
Remove-Item -LiteralPath $tmpHtml, $tmpJs, $harness -Force -ErrorAction SilentlyContinue

if ($failCount -eq 0) {
    Write-Host "`nALL TESTS PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n$failCount TEST(S) FAILED" -ForegroundColor Red
    exit 1
}
