# Project Handoff — Scan Me!

**Last updated**: 2026-09-26 (Retrospective Spec for v1.0.0)
**Status**: ✅ Released — v1.0.0 shipped, docs corrected and expanded
**Owner**: DRKMTTR Studio (Tokenmee)

---

## Project Snapshot

### What this is
Scan Me! — Windows desktop application สำหรับสแกนโฟลเดอร์และแสดงโครงสร้างไฟล์แบบ Tree View พร้อมสถิติ, ตรวจสอบไฟล์ซ้ำ (MD5), และ export เป็น HTML/TXT/JSON/CSV

> ⚠️ **แก้ไขความเข้าใจผิดพลาดแล้ว (2026-09-26)** — เวอร์ชันก่อนหน้าของไฟล์นี้ระบุผิดว่าโปรเจกต์เป็น
> "QR Code / Barcode Scanner" ซึ่ง **ไม่จริง** ทั้งหมด ไม่มีโค้ดกล้อง ไม่มี webcamera overlay
> และไม่มีโมดูล barcode ในรีโพเชอร์ ผลิตภัณฑ์จริงคือ **File Scanner / Folder Tree Explorer**
> ตามที่อธิบายไว้ด้านบน โปรดอ้างอิง `README.md` เป็นแหล่งความจริงหลัก

### Tech Stack — ยืนยันจากไฟล์จริง

| Component | Technology | หมายเหตุ |
|---|---|---|
| Language | PowerShell + WPF | ไม่ใช่ Python — ไม่มี dependency ภายนอกเลย |
| UI Framework | WPF (Windows Presentation Foundation) | .NET Framework 4.x, XAML + PowerShell controller |
| Scanner Engine | `src/engine/Scanner.ps1` | PowerShell-based recursive file scanner (`Invoke-DirectoryScan`) |
| Utility Layer | `src/utils/Helpers.ps1` | Hashing, metadata, HTML/TXT/JSON/CSV exporters (9 functions) |
| Distribution | `ScanMe.exe` (54KB .NET 4.x WinExe launcher ที่ invokes PowerShell) | ยืนยันแล้วว่าเป็น WinExe จริง ไม่ใช่บั๊ก — ดู ISSUE-001 |
| Protocol Handler | `tools/ScanMeOpener.ps1` | Custom `scanme://open?path=` handler สำหรับ HTML context menu |
| Build | `build_exe.ps1` (csc.exe), `build_icon.ps1` | ใช้ in-box .NET Framework C# compiler |
| Docs | README, ARCHITECTURE, CHANGELOG, ROADMAP, PRODUCT_SPEC, TECHNICAL_SPEC, SCHEMA_SPEC | ครบกว่าโปรเจกต์อื่น |
| Rules | `.clinerules` (single file, 6 rules), `.cursorrules` | รองรับทั้ง Cline และ Cursor |

### ⚠️ สิ่งที่ต้องตรวจสอบในไฟล์จริง

1. ~~**ScanMe.exe ขนาด 5KB** — เล็กผิดปกติ~~ → ✅ **ปิดแล้ว ไม่ใช่บั๊ก**
   - Binary analysis + Reflection ยืนยันว่าเป็น **native .NET Framework 4.x WinExe (AnyCPU)** ขนาดจริง **55,820 bytes (~54KB)**
   - CLR header `v4.0.30319`, manifest `requestedExecutionLevel = asInvoker` (ไม่ขอ UAC)
   - หน้าที่คือ spawn `powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File ...\MainWindow.ps1`
     และส่ง env var `SCANME_EXE_PATH` ให้สคริปต์
   - **สรุป:** เป็น *launcher by design* ไม่ใช่ standalone bundle → ต้องวางไว้คู่กับโฟลเดอร์ `src` เสมอ
   - รายละเอียดเต็ม: `docs/KNOWN_ISSUES.md` (ISSUE-001)

2. **Windows 7 prerequisites** — รองรับ Win7 ได้ แต่ต้องเตรียม 2 อย่างก่อน:
   - **.NET Framework 4.8 (full)** — *ไม่ใช่ Client Profile* เพราะ Client Profile ตัด WPF ออก
     (อาการ: "The type initializer for ... threw an exception")
   - **Windows Management Framework 5.1** — PowerShell บน Win7 มักเป็นเวอร์ชันต่ำกว่า 5.1
   - **PowerShell 7 ไม่รองรับบน Windows 7** (Microsoft ไม่ release) และ Client Profile ไม่รองรับ
     → ดู README System Requirements

3. **PowerShell execution policy** — ทั้ง `ScanMe.exe` และ `run.bat` เรียกด้วย `-ExecutionPolicy Bypass` แล้ว
   ผู้ใช้ปลายทางจึง **ไม่ต้องตั้ง policy เอง** แต่ถ้าองก์กรณ์ Group Policy บล็อก ต้องแก้โดยผู้ดูแลระบบ

4. **Culture-invariant serialization (สำคัญที่สุดที่เพิ่งแก้)** — ห้ามใช้ `DateTime.ToString("yyyy-MM-dd HH:mm:ss")`
   เพราะบน locale `th-TH` ThaiBuddhistCalendar จะให้ปี **2569** แทน 2026
   → ต้องใช้ `Format-ScanDateTime` เสมอ (ดู `.clinerules` rule #6)

### Files in Repository (ยืนยันจาก `git ls-files` จริง)

```
ScanMe.exe          ← WinExe launcher (~54KB) — ต้องอยู่คู่กับ src/
run.bat             ← One-click source launcher (ไม่ต้องผ่าน .exe)
build_exe.ps1       ← Compile launcher ด้วย csc.exe
build_icon.ps1      ← จัดการ canonical icon
src/engine/         ← Scanner.ps1 (core engine)
src/gui/            ← MainWindow.xaml + MainWindow.ps1 (WPF UI)
src/utils/          ← Helpers.ps1 (hash, metadata, exporters)
config/             ← default_config.json (version, presets, defaults)
docs/               ← PRODUCT_SPEC, TECHNICAL_SPEC, HANDOFF, KNOWN_ISSUES, SCHEMA_SPEC, ...
tools/              ← scanme:// protocol register/unregister/diagnose
tests/              ← 6 feature tests (context menu, copy path/tree, dropdowns, icon)
output/             ← latest_scan.json, latest_tree.html, latest_tree.txt
assets/app.ico      ← Canonical icon (single source of truth)
.clinerules         ← Single-file Cline rules (6 rules)
.cursorrules        ← Cursor rules
```

---

## Current Product State

### ✅ v1.0.0 — Released 2026-09-26
- ฟีเจอร์ครบตาม `docs/PRODUCT_SPEC_v1.0.md`: deep scan, tree view, statistics, MD5 duplicates,
  HTML/TXT/JSON/CSV export, `scanme://` context menu, live search, filter presets
- Data contract นิ่งแล้วตาม `docs/SCHEMA_SPEC.md` — และ**ผลลัพธ์เหมือนกันทุก host** (5.1 และ 7)
- เอกสาร spec ครบ: `docs/PRODUCT_SPEC_v1.0.md`, `docs/TECHNICAL_SPEC.md`, `docs/SCHEMA_SPEC.md`
- ISSUE-001 (ScanMe.exe) ปิดแล้ว, ISSUE-003 (เอกสาร) ปิดแล้ว
- รองรับ Windows 7 SP1 (ต้องมี .NET 4.8 full + WMF 5.1), Windows 10, Windows 11

### ✅ ยืนยันแล้วว่าดีกว่าโปรเจกต์อื่น
- โครงสร้างโฟลเดอร์ดีที่สุด (src/, docs/, config/, tools/, tests/, output/)
- **Zero external dependencies** — ไม่มี NuGet / PSGallery / ไม่ต้องต่อเน็ต / ไม่ต้องใช้สิทธิ์แอดมิน
- เอกสารครบกว่าโปรเจกต์อื่น (README, ARCHITECTURE, CHANGELOG, ROADMAP, PRODUCT_SPEC,
  TECHNICAL_SPEC, SCHEMA_SPEC, KNOWN_ISSUES, HANDOFF)
- รองรับ AI agent ทั้ง Cline และ Cursor พร้อมกัน
- มี test ครอบคลุมจุดที่เคยพังจริง (JS syntax, copy path, tree text, context menu, icon, dropdown)

### ⚠️ ข้อจำกัดที่ต้องรู้ (ยังไม่แก้)
- การตรวจไฟล์ซ้ำต้องอ่านเนื้อหาไฟล์ทั้งหมด → ช้ากับขนาดใหญ่ (เป็นพฤติกรรมที่คาดหวัง)
- ยังไม่มีการลบไฟล์ซ้ำจริง — รายงานอย่างเดียว
- `.clinerules` เป็น single file — ถ้า rule โตขึ้นมากควรแยกเป็นโฟลเดอร์ (ดู ISSUE-002)
- ลำดับไฟล์ใน `Files[]` ขึ้นกับ `Get-ChildItem` ซึ่งไม่คงที่ — ถ้าเทียบ output ให้ sort ก่อน

---

## Recent Changes

| วันที่ | สิ่งที่เปลี่ยน | ทำไม | ไฟล์ |
|---|---|---|---|
| 2026-09-26 | **แก้บั๊กปี พ.ศ. 2569** — เพิ่ม `Format-ScanDateTime` (InvariantCulture) | PS7 สืบทอด OS locale → `th-TH` ให้ปี 2569 แต่ 5.1 ให้ 2026 → JSON คนละชุดกัน | `src/utils/Helpers.ps1`, `src/engine/Scanner.ps1` |
| 2026-09-26 | Cast `Total_Size_Bytes` เป็น `[int64]` | `Measure-Object -Sum` คืน `Double` → PS7 เขียน `50746.0` แต่ 5.1 เขียน `50746` | `src/engine/Scanner.ps1` |
| 2026-09-26 | เพิ่ม System Requirements table | ระบุ prerequisite ของ Windows 7 ให้ชัด (Client Profile / PS7 ใช้ไม่ได้) | `README.md` |
| 2026-09-26 | เพิ่ม `.clinerules` rule #6 | กันไม่ให้ใช้ `ToString()` แบบ culture-sensitive อีก | `.clinerules` |
| 2026-09-26 | ปิด ISSUE-001 | ยืนยันแล้วว่า ScanMe.exe เป็น WinExe 54KB ที่ทำงานถูกต้อง | `docs/KNOWN_ISSUES.md` |
| 2026-09-26 | **แก้ HANDOFF.md ที่อธิบายผิดว่าเป็น QR Scanner** | เอกสารไม่ตรงกับโค้ดจริง ทำให้ session ใหม่เข้าใจผิด | `docs/HANDOFF.md` |
| 2026-09-26 | สร้าง PRODUCT_SPEC / TECHNICAL_SPEC + อัปเดต ROADMAP | Retrospective spec สำหรับ v1.0.0 เพื่อเป็น baseline | `docs/`, `ROADMAP.md` |
| 2026-09-17 | สร้าง HANDOFF.md, CURRENT_TASK.md, KNOWN_ISSUES.md | Santa Claude audit — ไม่มีไฟล์เหล่านี้ | `docs/` |

---

## Where to Resume

1. อ่าน `docs/PRODUCT_SPEC_v1.0.md` — เข้าใจว่าโปรเจกต์ทำอะไร (แทนคำอธิบายผิดในเวอร์ชันก่อน)
2. อ่าน `docs/TECHNICAL_SPEC.md` — architecture, data flow, component ที่แก้ตรงไหน
3. อ่าน `docs/CURRENT_TASK.md` — งานที่ค้างอยู่
4. อ่าน `docs/KNOWN_ISSUES.md` — ปัญหาที่รู้แล้ว (ISSUE-002 ยังเปิดอยู่)
5. อ่าน `.clinerules` — กติกาการทำงาน (single file, 6 rules — **ข้อ 6 สำคัญที่สุด**)
6. ก่อนแก้โค้ดที่แตะ output → **ทดสอบด้วยทั้ง `powershell.exe` และ `pwsh.exe` แล้ว diff JSON**

