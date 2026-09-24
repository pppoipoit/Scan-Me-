# ⚠️ KNOWN ISSUES — Scan Me! (Santa Claude Audit 2026-09-17)

> **Cline: อ่านก่อน session ทุกครั้ง** — คู่กับ HANDOFF.md + CURRENT_TASK.md

---

## 🟡 MEDIUM — ตรวจสอบก่อนทำงาน

### ISSUE-001: ScanMe.exe ขนาด 5KB — อาจไม่ใช่ standalone exe จริงๆ

**Status**: ⚠️ ยังไม่ verify
**Impact ถ้าเป็น launcher**: exe พังในเครื่องที่ไม่มี PowerShell/script engine ที่ต้องการ

WPF application ขนาดปกติจะมีขนาด 1–30 MB ขึ้นอยู่กับว่า embed .NET runtime หรือไม่
exe ขนาด 5KB ชี้ว่าน่าจะเป็น:
- Launcher script ที่ compile เป็น exe
- Bootstrapper ที่เรียก main logic จาก DLL/PS1 อื่น

**วิธีตรวจ**:
```powershell
# ดู dependencies
dumpbin /dependents ScanMe.exe   # ถ้ามี Visual Studio

# หรือดูว่า process ลูกอะไรถูก spawn ตามมา
Get-Process | Where-Object { $_.Parent.Id -eq (Get-Process ScanMe).Id }
```

### ISSUE-002: .clinerules เป็น single file — maintain ยากขึ้นเรื่อยๆ

**Status**: ℹ️ ทราบแล้ว — ไม่ใช่บัค
**รายละเอียด**: โปรเจกต์นี้ใช้ .clinerules แบบ single file (ต่างจาก Key Scraper ที่แบ่งเป็น 6 ไฟล์)
**Impact**: ถ้า rules เพิ่มมากขึ้น ไฟล์จะยาวและหา rule เฉพาะเรื่องยาก
**แนวทาง**: ถ้า session ถัดไปมีเวลา แนะนำให้ migrate เป็น `.clinerules/` folder แบบ Key Scraper

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
