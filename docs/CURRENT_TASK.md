# Current Task — Scan Me!

**Status**: ✅ No Active Task
**Last updated**: 2026-09-26

---

## TC-001: Add Missing Handoff Documentation

**Status**: ✅ COMPLETED — 2026-09-17
**Done by**: Santa Claude cross-project audit

สร้าง `docs/HANDOFF.md`, `docs/CURRENT_TASK.md`, `docs/KNOWN_ISSUES.md`
เพื่อให้ Cline session ใหม่เริ่มงานต่อได้โดยไม่ต้องเล่าบริบทจากศูนย์

---

## TC-002: Verify ScanMe.exe Architecture

**Status**: ✅ COMPLETED — 2026-09-26
**Priority**: MEDIUM
**Result**: ยืนยันแล้วว่าเป็น **native .NET Framework 4.x AnyCPU WinExe launcher** (ขนาดจริง 55,820 bytes ≈ 54KB)
หน้าที่คือ spawn `powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File ...\MainWindow.ps1`
และส่ง env var `SCANME_EXE_PATH` ไม่ hardcode เวอร์ชัน PowerShell และตั้งใจเรียก 5.1 (รองรับ Windows 7)
→ ตัวเลข "5KB" ในรายการเดิมเป็นข้อมูลผิด

### งานที่ทำ
```
1. [x] ตรวจสอบ ScanMe.exe (binary analysis + Reflection)
       → เป็น WinExe launcher จริง ไม่ใช่ Electron wrapper และไม่ใช่ standalone
2. [x] อัปเดต HANDOFF.md — แก้ Tech Stack + distribution model ให้ถูกต้อง
3. [x] อัปเดต CURRENT_TASK.md → Status: COMPLETED
4. [x] ปิด ISSUE-001 ใน docs/KNOWN_ISSUES.md พร้อมบันทึกหลักฐาน
```

---

## TC-003: Retrospective Spec Documentation for v1.0.0

**Status**: ✅ COMPLETED — 2026-09-26

สร้างเอกสาร baseline สำหรับ v1.0.0 โดยอ้างอิงจากโค้ดจริง
- `docs/PRODUCT_SPEC_v1.0.md` — vision, features, user workflows, limitations, success criteria
- `docs/TECHNICAL_SPEC.md` — architecture, components, build, testing
- แก้ `docs/HANDOFF.md` ที่เคยอธิบายผิดว่าเป็น "QR Code / Barcode Scanner"
- อัปเดต `ROADMAP.md` (v1.0.0 released + v1.1–v2.0 + long-term vision)

---

## TC-004: Automated Cross-Host Serialization Regression Test

**Status**: ✅ COMPLETED — 2026-09-26
**Priority**: HIGH (ป้องกันบั๊กที่เพิ่งแก้ไม่ให้กลับมา)

เพิ่ม `tests/cross_host_json_test.ps1` ที่รัน engine ใต้ทุก PowerShell host ที่มี
แล้ว diff JSON — เทียบกับที่ `.clinerules` rule #6 สั่งไว้แต่ยังทำด้วยมือเท่านั้น

### ⚠️ เจอบั๊กจริงระหว่างทำ (ไม่ใช่แค่เขียนเทสต์)
`Total_Size_MB`, `Size_MB` และ `Scan_Duration_Sec` ยัง drift ระหว่าง host
เพราะ **PS7's `ConvertTo-Json` เติม `.0` ให้ float ที่เป็นจำนวนเต็ม** (`0.0`, `5.0`)
ขณะที่ 5.1 เขียน `0`, `5` — และการ cast เป็น `[decimal]` **ไม่ช่วย**

แก้โดยเพิ่ม `ConvertTo-StableNumber` ใน `src/utils/Helpers.ps1`
(whole → `[int]`, fractional → คงเดิม) และครอบทั้ง 3 จุดใน `src/engine/Scanner.ps1`

```
1. [x] เขียน tests/cross_host_json_test.ps1
2. [x] เจอ + แก้ drift ของ float (Total_Size_MB / Size_MB / Scan_Duration_Sec)
3. [x] ยืนยันด้วยการสแกนจริง 54 ไฟล์ → ผลเหมือนกันทุก host (เหลือเฉพาะ timestamp/duration ที่ volatile จริง)
4. [x] รันเทสต์เดิมทั้ง 4 ตัวซ้ำ → ไม่มี regression
```

---

## 📋 งานที่แนะนำถัดไป (ยังไม่เริ่ม)

| Task | รายละเอียด |
|---|---|
| **TC-005** | ย้าย `.clinerules` จาก single file เป็นโฟลเดอร์ (ดู ISSUE-002) — ตอนนี้มี 6 กฎแล้วและกฎที่ 6 ยาวมาก |
| **TC-006** | เพิ่ม test runner กลาง + VS Code task ที่รันทุกเทสต์พร้อมกัน (ตอนนี้รันทีละไฟล์ และ 2 ไฟล์ต้องเปิด GUI) |
| **TC-007** | Incremental scan ตาม ROADMAP Phase A — เป็นคอขวดประสิทธิภาพที่ใหญ่ที่สุดของแอป |
| **TC-008** | Duplicate resolver + safe delete (ต้องมี dry-run และ undo เสมอ) |

---

## Work Log

| วันที่ | Session | สิ่งที่ทำ |
|---|---|---|
| 2026-09-26 | Spec + regression | แก้บั๊กปี พ.ศ./float (`a92841a`) · spec docs (`bb61f00`) · เพิ่ม `cross_host_json_test.ps1` + `ConvertTo-StableNumber` (TC-002/003/004) |
| 2026-09-17 | Santa Claude audit | สร้าง HANDOFF.md + CURRENT_TASK.md + KNOWN_ISSUES.md |
