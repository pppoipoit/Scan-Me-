# ⚠️ KNOWN ISSUES — Scan Me! (Santa Claude Audit 2026-09-17)

> **Cline: อ่านก่อน session ทุกครั้ง** — คู่กับ HANDOFF.md + CURRENT_TASK.md

---

## 🟡 MEDIUM — ตรวจสอบก่อนทำงาน

### ISSUE-001: ScanMe.exe ขนาด 5KB — อาจไม่ใช่ standalone exe จริงๆ

**Status**: ✅ **ปิดแล้ว 2026-09-26 (verified)** — ไม่ใช่บั๊ก
**Impact**: —

ตรวจสอบจริงแล้ว (binary analysis + Reflection) ยืนยันว่า ScanMe.exe เป็น **native .NET Framework WinExe launcher** ที่ถูกต้อง:

| Property | ค่าจริง |
| :--- | :--- |
| AssemblyName | `ScanMe, Version=0.0.0.0` |
| CLR header | `v4.0.30319` (.NET Framework 4.x) |
| ProcessorArchitecture | `None` (AnyCPU) |
| Manifest | `requestedExecutionLevel = asInvoker` (ไม่ขอ UAC) |
| **ขนาดจริง** | **55,820 bytes (~54 KB)** — *ไม่ใช่ 5KB* |

ตัวเลข 5KB ในรายการนี้เป็นข้อมูลผิด (outdated) — ขนาดจริงประมาณ 54 KB ซึ่ง **ถูกต้อง** สำหรับ WinExe ที่ฝังไอคอน 49 KB และไม่มี payload อื่น

หน้าที่ของมันคือ spawn `powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File ...\MainWindow.ps1`
และส่ง env var `SCANME_EXE_PATH` ให้สคริปต์ — **ไม่ hardcode เวอร์ชัน PowerShell ใดๆ** และตั้งใจเรียก `powershell.exe` (5.1) ไม่ใช่ `pwsh.exe` (7)
ดังนั้น **รองรับ Windows 7 ได้** เพราะ target .NET Framework 4.x ที่ Win7 SP1 รองรับ

**หลักฐานว่าเป็น launcher ไม่ใช่บั๊ก:** ไฟล์เล็กเพราะโดย*ตั้งใจ* เป็น bootstrapper ไม่ใช่ standalone — README ระบุชัดเจนแล้วว่า
"`ScanMe.exe` is a Windows launcher ... it is not a self-contained single-file bundle" ต้องวางไว้คู่กับโฟลเดอร์ `src` เสมอ

### ISSUE-002: .clinerules เป็น single file — maintain ยากขึ้นเรื่อยๆ

**Status**: ⚠️ ยังเปิดอยู่ — เติบโตขึ้นจนเห็นผลแล้ว (2026-09-26)
**รายละเอียด**: โปรเจกต์นี้ใช้ .clinerules แบบ single file (ต่างจาก Key Scraper ที่แบ่งเป็น 6 ไฟล์)
**Impact**: ตอนนี้มี 6 กฎ และกฎที่ 6 (Culture-Invariant Serialization) ยาวมากจนซ้ำซ้อนกับ `docs/TECHNICAL_SPEC.md`
**แนวทาง**: ย้ายเป็น `.clinerules/` folder แบบ Key Scraper — คงกฎที่ 1-5 ไว้ แต่ตัดกฎที่ 6
ให้เหลือเฉพาะข้อบังคับสั้น ๆ ("ใช้ `Format-ScanDateTime` / `ConvertTo-StableNumber` และรัน
`tests\cross_host_json_test.ps1` ก่อน commit") แล้วชี้ไปที่ `docs/TECHNICAL_SPEC.md` §2 สำหรับรายละเอียด
→ ติดตามเป็น TC-005 ใน `docs/CURRENT_TASK.md`

### ISSUE-003: ไม่มี HANDOFF.md และ CURRENT_TASK.md (แก้แล้ว)

**Status**: ✅ แก้แล้ว — Santa Claude สร้างให้ 2026-09-17

---

## ✅ ดีกว่าโปรเจกต์อื่น

| จุดแข็ง | รายละเอียด |
|---|---|
| โครงสร้าง folder | ดีที่สุดใน 4 โปรเจกต์ (src/, docs/, config/, output/) |
| มี ARCHITECTURE.md | ครบที่สุด |
| มี CHANGELOG.md | บันทึก version history |
| มี ROADMAP.md | วางแผน feature ล่วงหน้า |
| รองรับ 2 AI tools | .clinerules + .cursorrules |

---
*Audit: Santa Claude | 2026-09-17*
