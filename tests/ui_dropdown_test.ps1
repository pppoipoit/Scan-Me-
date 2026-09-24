<#
.SYNOPSIS
    UI Automation test for the Filter Preset ComboBox (CmbPresets).
    Mandated: Expand -> assert Expanded, Collapse -> assert Collapsed (System.Windows.Automation).
    Extra diagnostics: items rendered after Expand, and real mouse-click opens the dropdown
    (programmatic equivalent of checklist #4 Red-Background clickable-area check).
#>
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, UIAutomationClient, UIAutomationTypes, System.Windows.Forms
Add-Type @'
using System; using System.Runtime.InteropServices;
public class Native {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
}
'@

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$psScriptPath = Join-Path -Path $projectRoot -ChildPath "src\gui\MainWindow.ps1"
$results = New-Object System.Collections.Generic.List[string]
$failed = $false
function Assert($name, $cond, $detail) {
    if ($cond) { Write-Host "  PASS: $name ($detail)" -ForegroundColor Green; $script:results.Add("PASS  $name") }
    else { Write-Host "  FAIL: $name ($detail)" -ForegroundColor Red; $script:results.Add("FAIL  $name"); $script:failed = $true }
}

Write-Host "=== UI Automation ComboBox Dropdown Test ===" -ForegroundColor Cyan
Write-Host "App: $psScriptPath" -ForegroundColor Gray
Write-Host "`n[1/6] Starting application..." -ForegroundColor Yellow
$appProcess = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$psScriptPath`"" -PassThru -WindowStyle Hidden
Write-Host "[2/6] Waiting for main window (max 25s)..." -ForegroundColor Yellow
$mainWindow = $null; $startTime = Get-Date
while ($null -eq $mainWindow -and (Get-Date) -lt $startTime.AddSeconds(25)) {
    $mainWindow = Get-Process -Id $appProcess.Id -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }
    if ($null -eq $mainWindow) { Start-Sleep -Milliseconds 400 }
}
if ($null -eq $mainWindow) { Write-Host "FAIL: main window did not appear within 25s" -ForegroundColor Red; exit 1 }
Write-Host "  Main window HWND: $($mainWindow.MainWindowHandle)" -ForegroundColor Green

$rootElement = [System.Windows.Automation.AutomationElement]::FromHandle($mainWindow.MainWindowHandle)
Write-Host "[3/6] Locating ComboBox (CmbPresets)..." -ForegroundColor Yellow
$condCombo = [System.Windows.Automation.PropertyCondition]::new(
    [System.Windows.Automation.AutomationElementIdentifiers]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::ComboBox)
$comboBox = $rootElement.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condCombo)
if ($null -eq $comboBox) { Write-Host "FAIL: ComboBox not found in automation tree" -ForegroundColor Red; $appProcess.Kill(); exit 1 }
$comboRect = $comboBox.Current.BoundingRectangle
Write-Host "  ComboBox: Name='$($comboBox.Current.Name)' AutomationId='$($comboBox.Current.AutomationId)' Rect=$comboRect" -ForegroundColor Green

# --- Checklist #4 evidence: overlap / coverage probing (Red-Background equivalent) ---
$condExt = [System.Windows.Automation.PropertyCondition]::new(
    [System.Windows.Automation.AutomationElementIdentifiers]::AutomationIdProperty, "TxtExtensions")
$extElement = $rootElement.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condExt)
if ($null -ne $extElement) {
    $extRect = $extElement.Current.BoundingRectangle
    Write-Host "  TxtExtensions Rect=$extRect" -ForegroundColor Gray
    $overlap = ($extRect.Left -lt $comboRect.Right) -and ($comboRect.Left -lt $extRect.Right)
    Assert "No sibling overlap (Extensions TextBox vs ComboBox)" (-not $overlap) "overlap=$overlap"
}
# Probe the arrow/toggle zone (rightmost 40px of the combo): what is the topmost element there?
$probe = New-Object System.Windows.Point(($comboRect.Right - 12), ($comboRect.Top + ($comboRect.Height / 2)))
try {
    $hit = [System.Windows.Automation.AutomationElement]::FromPoint($probe)
    $hitDesc = "Name='$($hit.Current.Name)' AutoId='$($hit.Current.AutomationId)' Type=$($hit.Current.ControlType.ProgrammaticName)"
    Write-Host "  Hit-test at arrow point ($([int]$probe.X),$([int]$probe.Y)): $hitDesc" -ForegroundColor Gray
    $hitOk = ($null -ne $hit) -and (($hit.Current.AutomationId -eq "CmbPresets") -or ($hit.Current.AutomationId -eq "PART_ToggleButton") -or
             (($hit.Current.ControlType -eq [System.Windows.Automation.ControlType]::Button) -and ($hit.Current.ProcessId -eq $appProcess.Id)))
    Assert "Toggle area not covered by another element" $hitOk "topmost=$hitDesc"
} catch {
    Write-Host "  INFO: ElementFromPoint unavailable in this host ($($_.Exception.Message)); coverage verified via mouse-click tests instead." -ForegroundColor Yellow
}

# --- MANDATED TEST 1: UIA Expand -> assert Expanded ---
Write-Host "[4/6] MANDATED TEST: invoke Expand..." -ForegroundColor Yellow
$pattern = $comboBox.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern)
if ($null -eq $pattern) { Write-Host "FAIL: ComboBox does not support ExpandCollapsePattern" -ForegroundColor Red; $appProcess.Kill(); exit 1 }
Write-Host "  Initial ExpandCollapseState: $($pattern.Current.ExpandCollapseState)" -ForegroundColor Gray
try {
    $pattern.Expand()
    Start-Sleep -Milliseconds 700
    $state1 = $pattern.Current.ExpandCollapseState
    Assert "Expand -> Expanded" ($state1 -eq [System.Windows.Automation.ExpandCollapseState]::Expanded) "state=$state1"
} catch { Assert "Expand -> Expanded" $false "exception: $_" }

# Checklist #3: items must actually render inside the open popup (non-empty screen rects)
$itemCondition = [System.Windows.Automation.PropertyCondition]::new(
    [System.Windows.Automation.AutomationElementIdentifiers]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::ListItem)
$items = $comboBox.FindAll([System.Windows.Automation.TreeScope]::Descendants, $itemCondition)
$visibleItems = @($items | Where-Object { $_.Current.BoundingRectangle.Width -gt 0 })
Assert "Items render in dropdown (ItemsPresenter present)" ($visibleItems.Count -ge 1) "visibleItemCount=$($visibleItems.Count)/total=$($items.Count)"

# --- MANDATED TEST 2: UIA Collapse -> assert Collapsed ---
Write-Host "[5/6] MANDATED TEST: invoke Collapse..." -ForegroundColor Yellow
try {
    $pattern.Collapse()
    Start-Sleep -Milliseconds 500
    $state2 = $pattern.Current.ExpandCollapseState
    Assert "Collapse -> Collapsed" ($state2 -eq [System.Windows.Automation.ExpandCollapseState]::Collapsed) "state=$state2"
} catch { Assert "Collapse -> Collapsed" $false "exception: $_" }

# --- TEST 3: real mouse click on the toggle zone -> must open (reproduces the user's bug) ---
Write-Host "[6/6] Mouse-click test on toggle area (checklist #4)..." -ForegroundColor Yellow
[void][Native]::SetForegroundWindow($mainWindow.MainWindowHandle)
Start-Sleep -Milliseconds 300
[void][Native]::SetCursorPos([int]($comboRect.Right - 12), [int]($comboRect.Top + ($comboRect.Height / 2)))
Start-Sleep -Milliseconds 200
[Native]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)  # LEFTDOWN
Start-Sleep -Milliseconds 80
[Native]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)  # LEFTUP
Start-Sleep -Milliseconds 700
$state3 = $pattern.Current.ExpandCollapseState
Assert "Mouse click -> Expanded" ($state3 -eq [System.Windows.Automation.ExpandCollapseState]::Expanded) "state=$state3"

# --- TEST 4: click the TEXT/CONTENT zone (what a user actually clicks) ---
Write-Host "[T4] Mouse-click test on text/content zone (user's typical click)..." -ForegroundColor Yellow
try { $pattern.Collapse() } catch {}
Start-Sleep -Milliseconds 400
$stateBefore = $pattern.Current.ExpandCollapseState
[void][Native]::SetForegroundWindow($mainWindow.MainWindowHandle)
Start-Sleep -Milliseconds 200
$textProbeX = [int]($comboRect.Left + ($comboRect.Width * 0.3))
$textProbeY = [int]($comboRect.Top + ($comboRect.Height / 2))
[void][Native]::SetCursorPos($textProbeX, $textProbeY)
Start-Sleep -Milliseconds 200
[Native]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)  # LEFTDOWN
Start-Sleep -Milliseconds 80
[Native]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)  # LEFTUP
Start-Sleep -Milliseconds 700
$state4 = $pattern.Current.ExpandCollapseState
Assert "Text-zone click -> Expanded" ($state4 -eq [System.Windows.Automation.ExpandCollapseState]::Expanded) "before=$stateBefore after=$state4 at($textProbeX,$textProbeY)"

# --- TEST 5: outside-click close, then arrow click must REOPEN (state-sync / IsOpen TwoWay) ---
Write-Host "[T5] Outside-click close then arrow click must reopen..." -ForegroundColor Yellow
if ($pattern.Current.ExpandCollapseState -ne [System.Windows.Automation.ExpandCollapseState]::Expanded) {
    try { $pattern.Expand() } catch {}
    Start-Sleep -Milliseconds 500
}
if ($null -ne $extElement) {
    $extCenterX = [int]($extRect.Left + ($extRect.Width / 2))
    $extCenterY = [int]($extRect.Top + ($extRect.Height / 2))
    [void][Native]::SetCursorPos($extCenterX, $extCenterY)
    Start-Sleep -Milliseconds 200
    [Native]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [Native]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 600
    $state5 = $pattern.Current.ExpandCollapseState
    Assert "Outside click closes popup (StaysOpen=False)" ($state5 -eq [System.Windows.Automation.ExpandCollapseState]::Collapsed) "state=$state5"
    [void][Native]::SetForegroundWindow($mainWindow.MainWindowHandle)
    [void][Native]::SetCursorPos([int]($comboRect.Right - 12), [int]($comboRect.Top + ($comboRect.Height / 2)))
    Start-Sleep -Milliseconds 200
    [Native]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [Native]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 700
    $state6 = $pattern.Current.ExpandCollapseState
    Assert "Arrow click REOPENS after outside-close" ($state6 -eq [System.Windows.Automation.ExpandCollapseState]::Expanded) "state=$state6"
} else {
    Assert "Outside-click cycle (TxtExtensions found)" $false "TxtExtensions element not found"
}
try { $pattern.Collapse() } catch {}

# Cleanup
try { $pattern.Collapse() } catch {}
Start-Sleep -Milliseconds 300
Write-Host "`n=== RESULT SUMMARY ===" -ForegroundColor Cyan
$results | ForEach-Object {
    if ($_ -like "FAIL*") { Write-Host "  $_" -ForegroundColor Red } else { Write-Host "  $_" -ForegroundColor Green }
}
if ($failed) { Write-Host "`nTEST FAILED" -ForegroundColor Red; try { $appProcess.Kill() } catch {}; exit 1 }
Write-Host "`nALL TESTS PASSED" -ForegroundColor Green
try { $appProcess.Kill() } catch {}
exit 0

