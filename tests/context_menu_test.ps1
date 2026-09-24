<#
.SYNOPSIS
    Verification test: the exported HTML tree's scanme:// context menu.
.DESCRIPTION
    Exports a fresh tree, extracts its JavaScript, and runs a Node DOM stub.
    Checks folder/file menu text, encoded protocol URLs for spaces, exclamation
    marks, and Unicode, requested close paths, and row-only native-menu
    suppression. Exit code 0 = ALL PASS, 1 = FAIL.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$failCount = 0

function Assert {
    param([string]$Name, [bool]$Ok, [string]$Detail = '')
    if ($Ok) { Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { Write-Host "  [FAIL] $Name  $Detail" -ForegroundColor Red; $script:failCount++ }
}

Write-Host '=== HTML Context Menu Verification Test ===' -ForegroundColor Cyan
. (Join-Path $root 'src\utils\Helpers.ps1')

$tmpHtml = Join-Path $PSScriptRoot '_tmp_context_menu_export.html'
$tmpJs = Join-Path $PSScriptRoot '_tmp_context_menu_script.js'
$harness = Join-Path $PSScriptRoot '_tmp_context_menu_harness.js'

try {
    $scan = Get-Content -Raw -LiteralPath (Join-Path $root 'output\latest_scan.json') | ConvertFrom-Json
    $exportOk = $false
    try {
        Export-ScanResultToHtmlTree -ScanResult $scan -OutputPath $tmpHtml
        $exportOk = Test-Path -LiteralPath $tmpHtml
    }
    catch { Write-Host "  export error: $($_.Exception.Message)" -ForegroundColor Red }
    Assert 'Export-ScanResultToHtmlTree runs' $exportOk

    $html = [System.IO.File]::ReadAllText($tmpHtml)
    Assert 'Generated HTML uses canonical scanme://open URL' ($html.Contains('scanme://open?path=') -and !$html.Contains('scanme://open/?path='))
    $match = [regex]::Match($html, '(?s)<script>(.*)</script>')
    Assert 'Script block found' $match.Success
    [System.IO.File]::WriteAllText($tmpJs, $match.Groups[1].Value, [System.Text.UTF8Encoding]::new($false))

    node --check $tmpJs
    Assert 'node --check parses generated JavaScript' ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"

    $harnessSource = @'
const fs = require("fs");
const src = fs.readFileSync(process.argv[2], "utf8");
function makeClassList(initial) {
  const values = new Set(initial || []);
  return {
    add: value => values.add(value), remove: value => values.delete(value),
    contains: value => values.has(value),
    toggle: value => values.has(value) ? values.delete(value) : values.add(value)
  };
}
const listeners = {};
const toastEl = { innerText: "", classList: makeClassList([]) };
const menuEl = {
  classList: makeClassList([]), style: {},
  setAttribute: (name, value) => { menuEl[name] = value; }
};
const openItem = { classList: makeClassList([]), textContent: "" };
const copyItem = { classList: makeClassList([]), textContent: String.fromCodePoint(0x1F4CB) + " Copy Path" };
const documentStub = {
  addEventListener: (name, handler) => (listeners[name] || (listeners[name] = [])).push(handler),
  getElementById: id => ({ toast: toastEl, contextMenu: menuEl, contextOpenItem: openItem, contextCopyItem: copyItem }[id] || null)
};
const windowStub = {
  location: { href: "" },
  addEventListener: (name, handler) => (listeners["window:" + name] || (listeners["window:" + name] = [])).push(handler)
};
globalThis.document = documentStub;
globalThis.window = windowStub;
globalThis.navigator = { clipboard: { writeText: value => ({ then: callback => callback() }) } };
globalThis.setTimeout = () => {};
function fire(name, event) { (listeners[name] || []).forEach(handler => handler(event)); }
function fireWindow(name, event) { (listeners["window:" + name] || []).forEach(handler => handler(event)); }
function makeRow(type, path) {
  const target = {
    classList: makeClassList([type === "folder" ? "folder-item" : "file-item"]),
    getAttribute: name => name === "data-path" ? path : null
  };
  const row = { closest: selector => selector === ".node-row" ? row : (selector === ".tree-item" ? target : null) };
  target.closest = selector => selector === ".tree-item" ? target : null;
  return row;
}
function contextEvent(target, state) {
  return { target, clientX: 123, clientY: 87, button: 2, preventDefault: () => { state.prevented = true; } };
}
function assert(condition, message) { if (!condition) throw new Error(message); }
function assertCanonicalProtocolUrl(path, label) {
  const expected = "scanme://open?path=" + encodeURIComponent(path);
  const url = buildOpenProtocolUrl(path);
  assert(url === expected, label + " URL mismatch: " + url);
  assert(!url.startsWith("scanme://open/?"), label + " URL contains extra slash: " + url);
  assert(decodeURIComponent(url.split("?path=")[1]) === path, label + " URL does not decode to path");
  return url;
}

eval(src);
assert(typeof buildOpenProtocolUrl === "function", "buildOpenProtocolUrl missing");
assert(typeof showContextMenu === "function", "showContextMenu missing");

const folderPath = "E:\\Project\\Scan Me!\\โฟล์";
const filePath = "E:\\Project\\Scan Me!\\โฟล์\\readme!.txt";
const folderState = { prevented: false };
fire("contextmenu", contextEvent(makeRow("folder", folderPath), folderState));
assert(folderState.prevented, "native menu was not suppressed for folder row");
assert(menuEl.classList.contains("show"), "folder menu did not open");
assert(openItem.textContent === String.fromCodePoint(0x1F4C2) + " Open Folder in Explorer", "folder item: " + JSON.stringify(openItem.textContent));
assert(copyItem.textContent.includes("Copy Path"), "Copy Path missing for folder");
openItem.onclick();
assertCanonicalProtocolUrl(folderPath, "folder");
assert(windowStub.location.href === "scanme://open?path=" + encodeURIComponent(folderPath), "folder URL: " + windowStub.location.href);
assert(!windowStub.location.href.startsWith("scanme://open/?"), "folder action URL contains extra slash: " + windowStub.location.href);
assert(toastEl.innerText.includes("register_protocol.ps1"), "Open toast missing registration help");

const fileState = { prevented: false };
fire("contextmenu", contextEvent(makeRow("file", filePath), fileState));
assert(fileState.prevented, "native menu was not suppressed for file row");
assert(menuEl.classList.contains("show"), "file menu did not open");
assert(openItem.textContent === String.fromCodePoint(0x1F4C4) + " Open File (default app)", "file item: " + JSON.stringify(openItem.textContent));
assert(copyItem.textContent.includes("Copy Path"), "Copy Path missing for file");
openItem.onclick();
assertCanonicalProtocolUrl(filePath, "file");
assert(windowStub.location.href === "scanme://open?path=" + encodeURIComponent(filePath), "file URL: " + windowStub.location.href);
assert(!windowStub.location.href.startsWith("scanme://open/?"), "file action URL contains extra slash: " + windowStub.location.href);
assert(decodeURIComponent(windowStub.location.href.split("path=")[1]) === filePath, "URL does not decode to file path");

fire("contextmenu", contextEvent(makeRow("folder", folderPath), { prevented: false }));
fire("keydown", { key: "Escape" });
assert(!menuEl.classList.contains("show"), "Escape did not close menu");
fire("contextmenu", contextEvent(makeRow("folder", folderPath), { prevented: false }));
fire("click", {});
assert(!menuEl.classList.contains("show"), "outside click did not close menu");
fire("contextmenu", contextEvent(makeRow("folder", folderPath), { prevented: false }));
fire("scroll", {});
assert(!menuEl.classList.contains("show"), "document scroll did not close menu");
fire("contextmenu", contextEvent(makeRow("folder", folderPath), { prevented: false }));
fireWindow("scroll", {});
assert(!menuEl.classList.contains("show"), "window scroll did not close menu");

const backgroundState = { prevented: false };
fire("contextmenu", contextEvent({ closest: () => null }, backgroundState));
assert(!backgroundState.prevented, "native menu was suppressed outside a tree row");

const unicodePath = "E:\\Project\\Scan Me!\\โฟล์\\ไฟล์.txt";
assertCanonicalProtocolUrl(unicodePath, "Unicode");
const specialFolderPath = "E:\\Project\\Scan Me!\\.vscode";
const specialFolderUrl = assertCanonicalProtocolUrl(specialFolderPath, ".vscode folder");
assert(specialFolderUrl.includes("Scan%20Me!%5C.vscode"), ".vscode path was not encoded correctly: " + specialFolderUrl);
console.log("context menu checks passed");
'@
    [System.IO.File]::WriteAllText($harness, $harnessSource, [System.Text.UTF8Encoding]::new($false))
    node $harness $tmpJs
    Assert 'Node DOM stub context-menu behavior' ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"

    # Regression test for the export guard: inject a second, malformed literal
    # while retaining the canonical declaration. This reproduces the user's
    # "both formats in one HTML" failure without modifying the real source file.
    Write-Host "`n=== HTML Protocol Export Guard Regression ===" -ForegroundColor Cyan
    $helperSourcePath = Join-Path $root 'src\utils\Helpers.ps1'
    $helperSource = [System.IO.File]::ReadAllText($helperSourcePath)
    $guardMarker = '    $htmlContent = $sbHtml.ToString()'
    if (!$helperSource.Contains($guardMarker)) {
        Assert 'Guard injection marker found' $false $guardMarker
    }
    else {
        $injectedHelperSource = $helperSource.Replace(
            $guardMarker,
            "    [void]`$sbHtml.AppendLine('scanme://open/?path=TEST_INJECTION')`r`n$guardMarker"
        )
        $guardTripped = $false
        $guardMessage = ''
        $guardOutput = Join-Path $PSScriptRoot '_tmp_malformed_protocol_export.html'
        Remove-Item -LiteralPath $guardOutput -Force -ErrorAction SilentlyContinue
        try {
            . ([scriptblock]::Create($injectedHelperSource))
            try {
                Export-ScanResultToHtmlTree -ScanResult $scan -OutputPath $guardOutput
            }
            catch {
                $guardTripped = $true
                $guardMessage = $_.Exception.Message
            }
            Assert 'Guard rejects malformed URL alongside canonical URL' $guardTripped $guardMessage
            Assert 'Guard blocks malformed output file' (!(Test-Path -LiteralPath $guardOutput))
        }
        finally {
            Remove-Item -LiteralPath $guardOutput -Force -ErrorAction SilentlyContinue
        }
    }
}
finally {
    Remove-Item -LiteralPath $tmpHtml, $tmpJs, $harness -Force -ErrorAction SilentlyContinue
}

if ($failCount -eq 0) {
    Write-Host "`nALL TESTS PASSED" -ForegroundColor Green
    exit 0
}
Write-Host "`n$failCount TEST(S) FAILED" -ForegroundColor Red
exit 1
