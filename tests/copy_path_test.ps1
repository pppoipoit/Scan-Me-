<#
.SYNOPSIS
    Verification test: "Copy Path" button in the exported interactive HTML tree.
.DESCRIPTION
    Root cause (fixed): src/utils/Helpers.ps1 embedded paths into
    onclick='copyPath(this, "...")' without (a) normalizing '/' to Windows '\' and
    (b) escaping '\' for the JS string literal, and copyPath() copied the raw
    value as-is. Test exports with a forward-slashed Target_Folder (the reported
    bug input) and asserts:
      1. Export-ScanResultToHtmlTree runs from current source
      2. Extracted <script> passes `node --check` (parse / no SyntaxError)
      3. End-to-end: every onclick expression, evaluated browser-like (HTML entity
         decode + JS eval -> copyPath -> clipboard stub), yields a path that is:
           - absolute (X:\... or UNC \\...)
           - backslash-only (no '/')
           - single backslashes only (no doubled '\' => correctly JS-escaped)
         plus no lone/unescaped '\' inside the raw JS literal, plus copyPath()
         normalizes '/' -> '\' on its own.
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

Write-Host "=== Copy Path Backslash Verification Test ===" -ForegroundColor Cyan

# --- 1) Fresh export from current source, target forced to forward slashes ---
Write-Host "[1/4] Exporting fresh HTML (Target_Folder forced to '/')" -ForegroundColor Yellow
. (Join-Path $root 'src\utils\Helpers.ps1')
$tmpHtml = Join-Path $PSScriptRoot '_tmp_copy_path_export.html'
$tmpJs   = Join-Path $PSScriptRoot '_tmp_copy_path_script.js'
$harness = Join-Path $PSScriptRoot '_tmp_copy_path_harness.js'
$scan = Get-Content -Raw -LiteralPath (Join-Path $root 'output\latest_scan.json') | ConvertFrom-Json
# Reproduce the reported bug input: target folder typed with forward slashes
$scan.Scan_Meta.Target_Folder = ([string]$scan.Scan_Meta.Target_Folder).Replace('\', '/')
$exportOk = $false
try {
    Export-ScanResultToHtmlTree -ScanResult $scan -OutputPath $tmpHtml
    $exportOk = Test-Path -LiteralPath $tmpHtml
} catch {
    Write-Host "  export error: $($_.Exception.Message)" -ForegroundColor Red
}
Assert "Export-ScanResultToHtmlTree runs" $exportOk

# --- 2) Extract <script> and parse with node ---
Write-Host "[2/4] node --check on extracted <script>..." -ForegroundColor Yellow
$html = [System.IO.File]::ReadAllText($tmpHtml)
$m = [regex]::Match($html, '(?s)<script>(.*)</script>')
Assert "Script block found" $m.Success
[System.IO.File]::WriteAllText($tmpJs, $m.Groups[1].Value, [System.Text.UTF8Encoding]::new($false))
node --check $tmpJs
Assert "node --check parses (no SyntaxError)" ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"

# --- 3) End-to-end copyPath semantics (Node + clipboard stub) ---
Write-Host "[3/4] Evaluating every copyPath() onclick expression..." -ForegroundColor Yellow
$hs = @'
const fs = require("fs");
const jsSrc = fs.readFileSync(process.argv[2], "utf8");
const html  = fs.readFileSync(process.argv[3], "utf8");
eval(jsSrc);
if (typeof copyPath !== "function") { console.error("copyPath undefined"); process.exit(2); }

// Browser-like clipboard stub; thenable never fires showToast
let copied = null;
const navStub = { clipboard: { writeText: t => { copied = t; return { then: () => {} }; } } };
try { Object.defineProperty(globalThis, "navigator", { value: navStub, configurable: true, writable: true }); }
catch (e) { global.navigator = navStub; }

function decodeEntities(s) {
  return s.replace(/&#39;/g, "'").replace(/&quot;/g, '"').replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&");
}
function isAbsWin(p) { return /^[A-Za-z]:\\/.test(p) || p.indexOf("\\\\") === 0; }

let bad = 0, count = 0;
const re = /onclick='(copyPath\(this, ("(?:[^"\\]|\\.)*")\))'/g;
let mm;
while ((mm = re.exec(html)) !== null) {
  const full   = decodeEntities(mm[1]);   // copyPath(this, "...")
  const rawLit = mm[2];                   // "..." exactly as embedded
  // Requirement: no lone '\' inside the raw JS literal (every '\' must be part of a '\\')
  if (rawLit.replace(/\\\\/g, "").indexOf("\\") !== -1) {
    console.error("UNESCAPED BACKSLASH IN LITERAL: " + rawLit); bad++;
  }
  // Evaluate like the browser: HTML-entity decode -> JS eval -> copyPath -> clipboard
  copied = null;
  try { eval(full); } catch (e) { console.error("EVAL FAIL: " + full + " -> " + e.message); bad++; continue; }
  const p = copied;
  count++;
  if (typeof p !== "string") { console.error("copyPath did not copy: " + full); bad++; continue; }
  if (p.indexOf("/") !== -1) { console.error("FORWARD SLASH: " + JSON.stringify(p)); bad++; }
  if (!isAbsWin(p))          { console.error("NOT ABSOLUTE:   " + JSON.stringify(p)); bad++; continue; }
  // Strip legitimate root (drive "X:" or UNC "\\") then require single '\' separators only
  const rest = p.slice(2);
  if (rest.indexOf("\\\\") !== -1) { console.error("DOUBLED BACKSLASH: " + JSON.stringify(p)); bad++; }
}
if (count === 0) { console.error("NO copyPath LITERALS FOUND IN HTML"); bad++; }

// copyPath() itself must normalize '/' -> '\' before clipboard write
copied = null;
copyPath(null, "D:/Inst_Dev/Skill/9arm-skills-main");
if (copied !== "D:\\Inst_Dev\\Skill\\9arm-skills-main") { console.error("NORMALIZE FAIL: " + JSON.stringify(copied)); bad++; }
copied = null;
copyPath(null, "E:\\Project\\Scan Me!\\README.md");
if (copied !== "E:\\Project\\Scan Me!\\README.md") { console.error("ROUNDTRIP FAIL: " + JSON.stringify(copied)); bad++; }

console.log("copyPath expressions checked: " + count + ", failures: " + bad);
process.exit(bad ? 1 : 0);
'@
[System.IO.File]::WriteAllText($harness, $hs, [System.Text.UTF8Encoding]::new($false))
node $harness $tmpJs $tmpHtml
Assert "All copied paths absolute, backslash-only, correctly escaped" ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"

# --- 4) Cleanup + summary ---
Write-Host "[4/4] Cleanup temp files..." -ForegroundColor Yellow
Remove-Item -LiteralPath $tmpHtml, $tmpJs, $harness -Force -ErrorAction SilentlyContinue

if ($failCount -eq 0) {
    Write-Host "`nALL TESTS PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n$failCount TEST(S) FAILED" -ForegroundColor Red
    exit 1
}
