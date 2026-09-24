# Project Handoff — Scan Me!

**Last updated**: 2026-09-17 (Santa Claude cross-project audit)
**Status**: Stable — No active development task
**Owner**: DRKMTTR Studio (Tokenmee)

---

## Project Snapshot

### What this is
Scan Me! — Windows desktop application สำหรับสแกน QR Code / Barcode จากกล้องเว็บแคมหรือไฟล์รูปภาพ แสดงผลแบบ real-time มี UI แบบ overlay หรือ standalone window

### Tech Stack — ยืนยันจากไฟล์จริง

| Component | Technology | หมายเหตุ |
|---|---|---|
| Language | PowerShell + WPF | ไม่ใช่ Python |
| UI Framework | WPF (Windows Presentation Foundation) | .NET-based |
| Scanner Engine | ดูใน src/ | [ตรวจใน session ถัดไป] |
| Distribution | `ScanMe.exe` (5KB launcher) | เล็กมาก — อาจเป็น launcher ที่เรียก script ต่อ |
| Docs | ARCHITECTURE.md, CHANGELOG.md, ROADMAP.md | ครบกว่าโปรเจกต์อื่น |
| Rules | `.clinerules` (single file), `.cursorrules` | รองรับทั้ง Cline และ Cursor |

### ⚠️ สิ่งที่ต้องตรวจสอบในไฟล์จริง

1. **ScanMe.exe ขนาด 5KB** — เล็กผิดปกติสำหรับ WPF app เต็มๆ
   - อาจเป็น launcher ที่เรียก PowerShell script เป็น main logic
   - อาจพังในเครื่องที่ไม่มี PowerShell execution policy ที่ถูกต้อง
   - ตรวจสอบด้วย: `Get-Content ScanMe.exe` หรือดูว่า exe เรียก script อะไร

2. **PowerShell execution policy** — ผู้ใช้ปลายทางอาจต้องตั้งค่าเพิ่ม

### Files in Repository (ที่รู้จาก audit)

```
ScanMe.exe          ← Launcher (5KB — ต้องตรวจว่า standalone จริงไหม)
src/                ← Source code
docs/               ← ARCHITECTURE.md, CHANGELOG.md, ROADMAP.md (มีอยู่แล้ว)
config/             ← Config files
output/             ← Output folder
.clinerules         ← Single-file cline rules
.cursorrules        ← Cursor rules
.code-workspace     ← VS Code workspace
```

---

## Current Product State

### ✅ ยืนยันแล้ว
- มี documentation ครบกว่าโปรเจกต์อื่น (ARCHITECTURE, CHANGELOG, ROADMAP)
- มีทั้ง .clinerules และ .cursorrules รองรับ 2 AI tools
- โครงสร้างโฟลเดอร์ดีที่สุดในบรรดา 4 โปรเจกต์ (src/, docs/, config/, output/)
- มีการ update ล่าสุด Sep 2026 (.code-workspace)

### ⚠️ ต้องตรวจสอบ
- พฤติกรรมของ ScanMe.exe ขนาด 5KB (launcher vs standalone)
- ความเข้ากันได้กับเครื่องที่ไม่มี .NET/PS runtime ที่ต้องการ

---

## Recent Changes

| วันที่ | สิ่งที่เปลี่ยน | ทำไม | ไฟล์ |
|---|---|---|---|
| 2026-09-17 | สร้าง HANDOFF.md, CURRENT_TASK.md | Santa Claude audit — ไม่มีไฟล์นี้ | docs/ |
| Sep 2026 | [ล่าสุด — ดูจาก .code-workspace] | [TBD] | .code-workspace |

---

## Where to Resume

1. อ่าน `docs/CURRENT_TASK.md` — งานที่ค้างอยู่
2. อ่าน `docs/KNOWN_ISSUES.md` — ปัญหาที่รู้แล้ว
3. อ่าน `.clinerules` — กติกาทำงาน (มีอยู่แล้ว single file)
4. ตรวจสอบ ScanMe.exe ขนาด 5KB ก่อนทำ feature ใหม่
