# 🏗️ TECHNICAL SPEC — Scan Me! v1.0.0

> เอกสารเชิงเทคนิคที่อ้างอิงจากโค้ดจริงในรีโพเชอร์ (commit `a92841a` เป็นต้น)
> คู่กับ [`PRODUCT_SPEC_v1.0.md`](PRODUCT_SPEC_v1.0.md) (มุมมองผลิตภัณฑ์)
> และ [`SCHEMA_SPEC.md`](SCHEMA_SPEC.md) (สัญญาข้อมูล JSON)

---

## 1. Architecture Overview

Scan Me! เป็น **local-first desktop app** ที่ประกอบขึ้นจาก 4 ชั้น แต่ละชั้นทำหน้าที่เฉพาะ ไม่ซ้ำซ้อนกัน

```text
┌──────────────────────────────────────────────────────────────┐
│  1. SCANNER ENGINE      src/engine/Scanner.ps1              │
│     • Invoke-DirectoryScan (recursive, filtered)            │
│     • เก็บ state ใน $fileList / $hashLookup / 2x hashtable  │
│     • คืน [ordered]@{ Scan_Meta; Category_Stats;            │
│                        Extension_Stats; Files }              │
└───────────────────────────┬──────────────────────────────────┘
                            │  in-memory object (ไม่ใช่ไฟล์)
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  2. GUI LAYER            src/gui/MainWindow.xaml (WPF UI)   │
│                         + src/gui/MainWindow.ps1 (controller)│
│     • Dot-source Engine + Helpers เพื่อเรียกฟังก์ชัน       │
│     • เรียก Invoke-DirectoryScan พร้อม -ProgressCallback      │
│     • อัปเดต UI ผ่าน $window.Dispatcher.Invoke (ไม่ทำให้ UI ค้าง)│
│     • กรองผลแบบ live ด้วย Update-FilteredGrid               │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  3. EXPORTERS            src/utils/Helpers.ps1              │
│     • Export-ScanResultToJson    → JSON (ตาม SCHEMA_SPEC)    │
│     • Export-ScanResultToCsv     → CSV                       │
│     • Export-ScanResultToTextTree→ TXT tree (UTF-8)          │
│     • Export-ScanResultToHtmlTree→ HTML interactive          │
│     • Build-FolderTreeHierarchy   → โครงสร้างต้นไม้กลาง      │
└───────────────────────────┬──────────────────────────────────┘
                            │  (HTML export เท่านั้น)
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  4. PROTOCOL HANDLER     tools/ScanMeOpener.ps1             │
│     • รับ scanme://open?path=<encoded> จากเบราว์เซอร์        │
│     • validate URL → decode → ต้องเป็น absolute ที่มีอยู่จริง  │
│     • โฟลเดอร์ → explorer.exe / ไฟล์ → Invoke-Item           │
│     • log ทุกขั้นตอนลง %TEMP%\scanme_opener.log             │
└──────────────────────────────────────────────────────────────┘
```

### Data Flow ของหนึ่งรอบการสแกน

```text
ผู้ใช้กด Start Scan
   ↓ (MainWindow.ps1 อ่านค่าจาก control)
Invoke-DirectoryScan -TargetFolder ... -CalcHash ... -ProgressCallback {...}
   ↓
Get-ChildItem -Recurse (LiteralPath, เติม Force ถ้ารวม hidden)
   ↓
filter ด้วย extension (ถ้าไม่ใช่ All Files)
   ↓
วนลูป: hash (ถ้าเปิด) → ตรวจซ้ำ → metadata (ถ้าเปิด) → สร้าง PSCustomObject
   ↓ เรียก ProgressCallback ทุก 10 ไฟล์ เพื่ออัปเดต progress bar
$scanResult (ordered hashtable)
   ↓
MainWindow.ps1: แปลงเป็น grid object → Update-FilteredGrid → อัปเดตการ์ดสถิติ
   ↓
Export 3 ไฟล์อัตโนมัติ: latest_scan.json, latest_tree.html, latest_tree.txt
   ↓
ผู้ใช้กด Export เอง → SaveFileDialog → เขียนไฟล์ที่เลือก
```

---

## 2. Tech Stack Details

| Layer | เทคโนโลยี | เหตุผล |
| :--- | :--- | :--- |
| **Language** | PowerShell 5.1+ / PowerShell 7+ | ไม่ต้องติดตั้งอะไร — มากับ Windows |
| **UI** | WPF (PresentationFramework, PresentationCore, WindowsBase) | ได้ modern UI + data binding โดยไม่ต้องมี NuGet |
| **Dialogs/Icons** | System.Windows.Forms, System.Drawing | ใช้ `FolderBrowserDialog` / `SaveFileDialog` / โหลดไอคอน |
| **P/Invoke** | `shell32.dll!SetCurrentProcessExplicitAppUserModelID` | ผูก taskbar icon ให้ถูกกับ `ScanMe.exe` (`DRKMTTR.ScanMe.1.0`) |
| **Runtime** | .NET Framework 4.x (AnyCPU) | รองรับ Windows 7 SP1 ขึ้นไป |
| **Exe build** | `csc.exe` (in-box .NET Framework C# compiler) | สร้าง WinExe launcher ไม่ต้องมี Visual Studio |
| **JSON** | `ConvertTo-Json` / `ConvertFrom-Json` | built-in (มีข้อควรระวังเรื่อง `Double` — ด้าล่าง) |

> **ชุด assembly ที่ `MainWindow.ps1` โหลด** (บรรทัดแรก):
> `PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing`
> ทั้งหมดเป็นของ in-box **ไม่มี NuGet / PSGallery เลย**

### ⚠️ Culture Invariance (บังคับใช้ทั้งโปรเจกต์)

| ปัญหา | พฤติกรรม | วิธีแก้ |
| :--- | :--- | :--- |
| ปี พ.ศ. | `DateTime.ToString("yyyy-MM-dd HH:mm:ss")` บน locale `th-TH` ให้ **2569** แทน 2026 (PS7 สืบทอด OS locale, PS 5.1 บังคับ `en-US`) | ใช้ **`Format-ScanDateTime`** ที่ pin `InvariantCulture` |
| เลข float ที่เป็นจำนวนเต็ม | `[math]::Round()` คืน `Double` → **PS7 เขียน `0.0` / `5.0`** แต่ 5.1 เขียน `0` / `5` (cast เป็น `[decimal]` **ไม่ช่วย**) | ครอบด้วย **`ConvertTo-StableNumber`** (whole → `[int]`, fractional → คงเดิม) |
| ผลรวมจาก `Measure-Object` | คืน `Double` → PS7 เขียน `50746.0` แต่ 5.1 เขียน `50746` | cast เป็น **`[int64]`** ก่อน serialize |

> JSON ไม่มีการแยก int/float ดังนั้นการเขียน `0` แทน `0.0` ใน field ที่สัญญาประกาศเป็น `number`
> จึงยังถูกต้องตาม schema และทำให้ผลลัพธ์ **เหมือนกันทุก host** จริง
> (ค่าที่มีทศนิยมจริง เช่น `19.15` ยังคงเป็น float และตรงกันทั้งสอง host)

> 📌 **กฎของโปรเจกต์:** ห้ามเรียก `DateTime.ToString(format)` แบบไม่ระบุ culture
> **ทุกครั้งที่แก้โค้ดที่แตะ output ต้องรัน `tests\cross_host_json_test.ps1` ซึ่งจะรันทั้ง
> `powershell.exe` และ `pwsh.exe` แล้ว diff JSON ให้อัตโนมัติ** (ดู `.clinerules` rule #6)

---


## 3. File Structure

```text
Scan Me!/
├── src/
│   ├── engine/Scanner.ps1        # Core engine: Invoke-DirectoryScan + CLI mode
│   ├── gui/
│   │   ├── MainWindow.xaml       # WPF layout (Dark Fluent theme) — 31KB
│   │   └── MainWindow.ps1        # GUI controller: events, threading, exports
│   └── utils/Helpers.ps1         # 9 functions: hash, metadata, 4 exporters, tree builder
├── config/default_config.json    # version, theme, presets, custom_extensions
├── docs/
│   ├── PRODUCT_SPEC_v1.0.md      # ← product scope & user workflows
│   ├── TECHNICAL_SPEC.md         # ← ไฟล์นี้
│   ├── SCHEMA_SPEC.md            # JSON data contract
│   ├── ARCHITECTURE.md           # icon / HTML / protocol notes
│   ├── HANDOFF.md                # session handoff (อ่านก่อนเริ่มงาน)
│   ├── KNOWN_ISSUES.md           # ISSUE-001 ✅ / ISSUE-002 open
│   ├── CURRENT_TASK.md           # งานที่ค้าง
│   ├── USER_GUIDE.md             # คู่มือใช้งาน
│   ├── EXTENSIONS_GUIDE.md       # วิธีเพิ่ม preset
│   ├── GITHUB_UPLOAD_GUIDE.md
│   └── RELEASE_NOTES_v1.0.0.md
├── tools/
│   ├── ScanMeOpener.ps1         # scanme:// protocol handler
│   ├── register_protocol.ps1     # เขียน HKCU\Software\Classes\scanme (idempotent)
│   ├── unregister_protocol.ps1   # ลบ key
│   ├── diagnose_protocol.ps1     # ตรวจ registration + เรียก opener + อ่าน log
│   └── test_opener.ps1           # เรียก opener แบบเห็นหน้าต่าง
├── tests/                        # 6 สคริปต์ตรวจสอบ (exit code 0 = PASS)
│   ├── context_menu_test.ps1     # scanme:// context menu (ใช้ Node DOM stub)
│   ├── copy_path_test.ps1        # Copy Path + backslash normalization
│   ├── copy_tree_text_test.ps1   # Copy Tree Text ครบทุกโฟลเดอร์
│   ├── html_dropdown_test.ps1    # JS syntax + toggle functions
│   ├── icon_test.ps1             # canonical icon ทั้ง 3 จุด
│   └── ui_dropdown_test.ps1      # CmbPresets ผ่าน UIAutomation
├── output/                       # generated: latest_scan.json / latest_tree.html|txt
├── assets/app.ico                # canonical icon (single source of truth)
├── ScanMe.exe                    # WinExe launcher (~54KB, AnyCPU)
├── run.bat                       # source launcher (ไม่ผ่าน .exe)
├── build_exe.ps1                 # compile launcher ด้วย csc.exe
├── build_icon.ps1                # จัดการ canonical icon
├── .clinerules / .cursorrules    # AI agent rules
└── .vscode/                      # launch.json, tasks.json, settings.json
```

> `.gitignore` ตัด `*.zip` ออก (release bundle ไม่ควรอยู่ใน git history)
> `output/` ถูก track ไว้ เพราะเป็นผลลัพธ์ตัวอย่างที่เอกสารอ้างอิง

---

## 4. Key Components

### 4.1 `src/engine/Scanner.ps1` — File scanning and metadata extraction

**Entry point เดียว:** `Invoke-DirectoryScan`

| พารามิเตอร์ | ชนิด | ค่าเริ่มต้น | หน้าที่ |
| :--- | :--- | :--- | :--- |
| `-TargetFolder` | string | โฟลเดอร์โปรเจกต์ | โฟลเดอร์ต้นทาง (ใช้ `LiteralPath` กันปัญหา wildcard ในชื่อพาธ) |
| `-Extensions` | string[] | `@("*.*")` | ลิสต์นามสกุล; คำนวณเป็น filter |
| `-IncludeAll` | bool | false | ข้ามการ filter ทั้งหมด |

### 4.2 `src/gui/MainWindow.xaml` + `MainWindow.ps1` — WPF GUI

**`MainWindow.ps1` (controller) ทำหน้าที่:**
- โหลด assembly + P/Invoke ผูก taskbar icon (`DRKMTTR.ScanMe.1.0`) — ทำ**ก่อน**แสดงหน้าต่างเสมอ
- resolve ไอคอนจาก 3 ตำแหน่งที่เป็นไปได้ (รองรับทั้งโหมด exe และ source) แล้วโหลดเป็น `BitmapFrame`
- `XamlReader.Load` → `FindName` ผูก control ทั้งหมด
- Dot-source `Helpers.ps1` + `Scanner.ps1` เพื่อเรียกฟังก์ชันชั้นล่าง
- อ่านค่าเริ่มต้นจาก `config/default_config.json`

**คอนโทรลที่ผูก event:** `BtnBrowseTarget`, `CmbPresets`, `ChkAllFiles`, `ChkDuplicateHash`,
`ChkExeMetadata`, `ChkHiddenFiles`, `TxtSearchFilter`, `BtnClearTable`, `BtnStartScan`,
`BtnExportJson`, `BtnExportCsv`, `BtnExportHtmlTree`, `BtnExportTxtTree`, `BtnOpenOutput`

**การทำให้ UI ไม่ค้าง (สำคัญ):**
- เรียก `$window.Dispatcher.Invoke(..., [DispatcherPriority]::Background, [action]{})` ก่อนเริ่มสแกน
- ใน progress callback ยิงกลับเข้า UI thread ด้วย `DispatcherPriority::Render`
- ผลลัพธ์ถูกเก็บใน `$global:CurrentScanResult` และ `$global:AllGridItems`

**`Update-FilteredGrid`** — live search: ค้นด้วย `Contains()` (ไม่ regex) จาก
`File_Name` · `Category_Folder` · `Extension` · `Full_Path` แบบ case-insensitive

**Export buttons** เริ่มต้นเป็น **disabled** และจะเปิดเมื่อสแกนสำเร็จเท่านั้น
(ป้องกันการ export ผลลัพธ์ `null`) — กด Clear ก็จะ disable อีกครั้ง

### 4.3 `src/utils/Helpers.ps1` — Export functions and utilities

ทั้งหมด 10 ฟังก์ชัน:

| Function | หน้าที่ |
| :--- | :--- |
| `Format-FileSize` | bytes → `"1.45 GB"` / `"512.00 KB"` / `"123 Bytes"` |
| `Format-ScanDateTime` | **culture-invariant** date → `"yyyy-MM-dd HH:mm:ss"` ด้วย `InvariantCulture` |
| `ConvertTo-StableNumber` | **host-stable** number: whole → `[int]`, fractional → คงเดิม (กัน PS7 เติม `.0`) |
| `Get-FileChecksum` | `Get-FileHash` แบบปลอดภัย; คืน `"ERROR_READING_HASH"` เมื่อล็อก/อ่านไม่ได้ |
| `Get-FileDetailedMetadata` | `FileVersionInfo` → version/company/description (เฉพาะ `.exe/.dll/.sys/.msi`) |
| `Export-ScanResultToJson` | เขียน JSON ตาม `SCHEMA_SPEC.md` (UTF-8) |
| `Export-ScanResultToCsv` | เขียน CSV แบนจาก `Files[]` |
| `Build-FolderTreeHierarchy` | สร้างโครงสร้างต้นไม้กลาง ใช้ร่วมกันทั้ง HTML และ TXT |
| `Export-ScanResultToTextTree` | ต้นไม้ UTF-8 พร้อมขนาดและแท็กซ้ำ |
| `Export-ScanResultToHtmlTree` | HTML dark theme + JS: toggle, search, icons, context menu, copy |

**จุดที่ต้องระวังใน `Export-ScanResultToHtmlTree` (เคยพังจริง):**
- **ห้ามใช้ backtick-escaped quote ใน single-quoted string** — เคยทำให้ JS parse error
  ทั้ง `<script>` block แล้วทุกปุ่ม (dropdown/expand/collapse/search/copy) ตายพร้อมกัน
  *(มี test `html_dropdown_test.ps1` ครอบไว้)*
- **path ใน `onclick='copyPath(this, "...")'` ต้อง escape `\`** และ normalize `/` → `\`
- **Copy Tree Text ต้องใช้ `TREE_DATA` JSON** ที่ embed ไว้ ไม่ใช่ `#treeContainer.innerText`
  เพราะ `innerText` ตัดโฟลเดอร์ที่ `display:none` (collapsed) ทิ้ง
  *(มี test `copy_tree_text_test.ps1` ครอบไว้)*

### 4.4 `tools/ScanMeOpener.ps1` — Custom protocol handler

รับ **exactly 1 argument** ในรูป `scanme://open?path=<encoded>` แล้วทำตามลำดับ:

| ขั้นตอน | การตรวจสอบ | ปฏิเสธเมื่อ |
| :--- | :--- | :--- |
| 1 | จำนวน argument == 1 | ไม่ใช่ 1 → throw |
| 2 | normalize `scanme://open/?path=` → `scanme://open?path=` | (Windows URI normalization ของ OS แทรก `/` เอง) |
| 3 | regex `^scanme://open\?path=([^?#&]*)$` | ไม่ตรงรูปแบบ |
| 4 | ค่าไม่ว่างเปล่า | path ว่าง |
| 5 | ไม่มี `%` ที่ไม่ใช่ hex 2 หลัก และไม่มี `? # &` | encoding ผิด / มี delimiter ปน |
| 6 | `UnescapeDataString` สำเร็จ | decode ไม่ได้ |
| 7 | พาธเป็น absolute (`[A-Za-z]:\` หรือ `\\`) | เป็น relative/URI/wildcard |
| 8 | `Test-Path -LiteralPath` | ไม่มีอยู่จริง |

---

## 5. Dependencies & Prerequisites

### ✅ Runtime (ต้องมี — มากับ Windows)

| สิ่งที่ต้องมี | Windows 11 / 10 | Windows 7 SP1 |
| :--- | :--- | :--- |
| .NET Framework 4.8 (**full**) | มากับเครื่อง | **ต้องติดตั้งเพิ่ม** |
| Windows PowerShell 5.1+ | มากับเครื่อง | ต้องติดตั้ง **WMF 5.1** |
| WPF assemblies | มากับ .NET | มากับ .NET 4.8 full |
| `csc.exe` (เฉพาะตอน build) | มากับ .NET Framework | มากับ .NET Framework |
| `Node.js` (เฉพาะเทสต์ `context_menu_test.ps1`) | ไม่บังคับ | ไม่บังคับ |

### ❌ ไม่ต้องมี (Zero External Dependencies)
- ไม่มี NuGet / PSGallery / PowerShell module ใด ๆ
- ไม่มี Python, Node.js (นอกจากตอนรันเทสต์), Electron, Docker
- ไม่ต้องต่อเน็ต ไม่มีบัญชีผู้ใช้ ไม่มี telemetry
- ไม่ต้องใช้สิทธิ์ Administrator (protocol ลงทะเบียนที่ `HKCU` เท่านั้น)

### ⚠️ ข้อยกเว้นสำคัญ
- **PowerShell 7 บน Windows 7** — Microsoft ไม่ release และไม่รองรับ
- **.NET Framework 4 Client Profile** — ตัด WPF ออก → ใช้ไม่ได้
  (อาการ: *"The type initializer for ... threw an exception"*)

---

## 6. Build Process

### 6.1 `build_exe.ps1` — Compile the launcher

1. หา `csc.exe`: ลอง `C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe`
   แล้ว fallback ไป `...\Framework\v4.0.30319\csc.exe` (32-bit)
   → ถ้าไม่เจอจริง ๆ ให้ error (ไม่มี Visual Studio ก็ build ได้ เพราะ csc มากับ .NET Framework)
2. เขียน C# source ลง `%TEMP%\ScanMe_Build.cs` (เขียน UTF-8) แล้วลบทิ้งหลัง compile
3. compile flag:
   ```text
   /target:winexe  /optimize+  /platform:anycpu
   /win32icon:"assets\app.ico"
   /out:"ScanMe.exe"  "source.cs"
   /r:System.dll  /r:System.Windows.Forms.dll
   ```
4. ถ้าไม่มี `assets\app.ico` → error ทันที (กันไอคอนหาย)

**สิ่งที่ launcher ทำ (`Program.Main`):**
1. `SetCurrentProcessExplicitAppUserModelID("DRKMTTR.ScanMe.1.0")` → taskbar icon ถูกต้อง
2. หา `src\gui\MainWindow.ps1` — ถ้าไม่เจอ แสดง MessageBox ชัดเจนว่า *"Please ensure the 'src' folder is in the same directory as ScanMe.exe"*
3. spawn `powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "<path>"`
   พร้อม `CreateNoWindow = true` และ env var `SCANME_EXE_PATH`
4. `WaitForExit()` แล้วจบกระบวนการ (ไม่มี console window ตอนรัน)
5. ครอบ try/catch → ถ้าพัง ให้ MessageBox สีแดงแทนการหายเงียบ

> **สำคัญ:** launcher เรียก `powershell.exe` (5.1) **โดยเจตนา** เพื่อให้ Win7 ทำงานได้
> ตัวเลข version ไม่ถูก hardcode และไม่มี payload ฝัง → ขนาดเล็กเป็นผลของการออกแบบ ไม่ใช่บั๊ก

### 6.2 `build_icon.ps1` — Canonical icon management
`assets\app.ico` คือ **single source of truth** ของไอคอนทั้งแอป (หน้าต่าง, taskbar, ScanMe.exe)
สคริปต์นี้จะรักษาไฟล์นี้เป็นผลลัพธ์ ไม่ใช่แทนที่ด้วย artwork ที่เก่ากว่า
(ต้นฉบับ `scan me!.ico` ยังอยู่ครบและไม่ถูกแก้)

> ⚠️ **Windows cache ไอคอน:** Explorer cache ไอคอนของ exe — หลัง build ใหม่ให้รัน
> `ie4uinit.exe -show` (หรือ restart Explorer) ก่อนตัดสินว่าไอคอนผิด

### 6.3 การรันแบบไม่ต้อง build
- `run.bat` → `powershell.exe -NoProfile -ExecutionPolicy Bypass -File src\gui\MainWindow.ps1`
  (ทางเลือดที่เร็วที่สุดสำหรับ dev — แก้ XAML แล้วเห็นผลทันที)

---

## 7. Testing Infrastructure

อยู่ใน `tests/*.ps1` — ทุกสคริปต์คืน **exit code 0 = PASS, 1 = FAIL** และมี `.SYNOPSIS`/`.DESCRIPTION`
ระบุ root cause ของบั๊กที่มันครอบไว้ (เขียนจากเหตุการณ์จริง ไม่ใช่เทสต์ทั่วไป)

| Test | ครอบคลุม | หมายเหตุ |
| :--- | :--- | :--- |
| `html_dropdown_test.ps1` | JS syntax + `toggleNode`/`expandAll`/`collapseAll` | กัน regression จาก quote escaping ที่ทำให้ทั้ง script block ตาย |
| `copy_path_test.ps1` | Copy Path + `/` → `\` normalization | ทดสอบด้วย target ที่มีช่องว่างและ `/` |
| `copy_tree_text_test.ps1` | Copy Tree Text ครบทุกโฟลเดอร์ (รวม collapsed) | กันการกลับไปใช้ `innerText` |
| `context_menu_test.ps1` | `scanme://` URL ของโฟลเดอร์/ไฟล์, encoding ของ ช่องว่าง/`!`/Unicode, row-only menu suppression | ใช้ **Node DOM stub** → ต้องมี Node.js |
| `icon_test.ps1` | ไอคอน canonical ทั้ง 3 จุด (XAML logo, P/Invoke ordering, exe icon) | export ไอคอน exe เป็น PNG แล้วเทียบกับ `assets\app.ico` |
| `ui_dropdown_test.ps1` | `CmbPresets` Expand/Collapse ผ่าน **System.Windows.Automation** | ต้องเปิดหน้าต่างจริง — เป็น UI integration test |
| `cross_host_json_test.ps1` | รัน engine ใต้ **ทุก PowerShell host** ที่มี แล้ว diff JSON | กันบั๊กปี พ.ศ. / float `.0` กลับมา (เจอบั๊กจริงตอนสร้างเทสต์นี้) |

### วิธีรัน
```powershell
# ทีละเทสต์
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\copy_path_test.ps1"

# ทั้งหมด (skip เทสต์ที่ต้องมี Node.js ถ้าไม่ได้ติดตั้ง)
Get-ChildItem .\tests\*.ps1 | ForEach-Object {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $_.FullName
    "{0,-30} exit={1}" -f $_.Name, $LASTEXITCODE
}
```

### ⚠️ ช่องว่างในการทดสอบปัจจุบัน
- ไม่มี test ครอบ `Scanner.ps1` โดยตรง (hash loop, relative-path stripping, statistics)
  → **ครอบแล้วบางส่วน** ผ่าน `cross_host_json_test.ps1` (duplicate detection + statistics + stability)
  ส่วน relative-path stripping ยังไม่มีเทสต์เฉพาะ
- ไม่มี test runner กลาง — ต้องรันทีละไฟล์ (ดู TC-006 ใน `docs/CURRENT_TASK.md`)
- ไม่มี unit test framework — ใช้แนวทาง script + exit code ล้วน

---

## 8. กฎการพัฒนาที่ต้องยึด (จาก `.clinerules`)

1. **Zero External Dependency** — ห้ามเพิ่ม module/NuGet/แพ็กเกจภายนอก
2. **Robust Path Handling** — ต้อง quote และใช้ `-LiteralPath` เสมอ (รองรับ `D:\Project\Scan Me!` และ long path)
3. **Encoding Standard** — export ทุกไฟล์ (JSON/CSV/MD) ต้องเป็น **UTF-8**
4. **Non-Blocking GUI** — งานยาวต้อง progress ได้และยกเลิกได้ โดยไม่ทำให้ UI ค้าง
5. **Modular Schema** — JSON output ต้องตรงตาม `SCHEMA_SPEC.md`
6. **Culture-Invariant Serialization (CRITICAL)** — ใช้ `Format-ScanDateTime` เสมอ;
   cast `Measure-Object -Sum` เป็น `[int64]`; แก้โค้ดที่แตะ output ต้องรันทั้ง
   `powershell.exe` และ `pwsh.exe` แล้ว diff JSON

---

<div align="center">

**Scan Me! v1.0.0 — Technical Spec** 🏗️
*Last updated: 2026-09-26 · commit `a92841a`*

</div>


แล้วจึงเปิด: โฟลเดอร์ → `explorer.exe "<path>"` · ไฟล์ → `Invoke-Item`
ทุกขั้นตอน log ลง `%TEMP%\scanme_opener.log`; ถ้าล้มเหลวจะแสดง error สีแดงและ
`Read-Host` ค้างไว้ให้อ่าน → `exit 1` (**ไม่ทำ action อื่นและไม่แตะเครือข่าย**)

**เครื่องมือประกอบ:** `register_protocol.ps1` (เขียน `HKCU\Software\Classes\scanme`,
idempotent, ไม่ต้องใช้แอดมิน, มี `-DebugMode`) · `unregister_protocol.ps1` ·
`diagnose_protocol.ps1` · `test_opener.ps1`


| `-CalcHash` | bool | false | เปิดการคำนวณ checksum (ช้าลงมาก) |
| `-HashAlgorithm` | enum | `MD5` | `MD5` หรือ `SHA256` |
| `-GetMeta` | bool | false | ดึง version info ของ `.exe/.dll/.sys/.msi` |
| `-HiddenFiles` | bool | false | เพิ่ม `-Force` ให้ `Get-ChildItem` |
| `-ProgressCallback` | scriptblock | — | เรียกทุก 10 ไฟล์ เพื่ออัปเดต UI |

**กลไกภายในของ loop ต่อไฟล์:**
1. คำนวณ `Category_Folder` = ชื่อโฟลเดอร์แม่
2. ตัด prefix ออกจาก `Full_Path` แบบ **case-insensitive + separator-normalized**
   *(เพราะ `String.Replace()` เป็น ordinal — ถ้า casing ของ target ต่างจาก filesystem จะตัดไม่ออก)*
3. ถ้า `$CalcHash` → `Get-FileChecksum`; ถ้า hash ซ้ำเดิม → `$isDuplicate = $true`
4. ถ้า `$GetMeta` → `Get-FileDetailedMetadata`
5. เพิ่มลง `$extensionSummary` แล้วสร้าง `PSCustomObject` ใส่ `$fileList`
6. เรียก `ProgressCallback` → อัปเดต progress bar

**ผลลัพธ์ (`$scanResult`)** — `[ordered]` เพื่อรักษาลำดับ key ใน JSON:
`Scan_Meta` (12 field) · `Category_Stats` · `Extension_Stats` · `Files[]`
→ สัญญาข้อมูลเต็มอยู่ที่ [`SCHEMA_SPEC.md`](SCHEMA_SPEC.md)

**CLI mode:** ถ้าไม่ได้ dot-source (`$MyInvocation.InvocationName -ne '.'`) สคริปต์จะรันเอง
แล้วแสดง `Write-Progress` และ export JSON → ใช้งาน headless ได้

