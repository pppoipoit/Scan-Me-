# Current Task — Scan Me!

**Status**: 📋 No Active Task
**Last updated**: 2026-09-17 (Santa Claude audit)

---

## TC-001: Add Missing Handoff Documentation

**Status**: ✅ COMPLETED — 2026-09-17
**Done by**: Santa Claude cross-project audit

สร้าง `docs/HANDOFF.md`, `docs/CURRENT_TASK.md`, `docs/KNOWN_ISSUES.md`
เพื่อให้ Cline session ใหม่เริ่มงานต่อได้โดยไม่ต้องเล่าบริบทจากศูนย์

---

## TC-002: Verify ScanMe.exe Architecture

**Status**: 🔴 NOT STARTED
**Priority**: MEDIUM

### งานที่ต้องทำ

```
1. [ ] ตรวจสอบ ScanMe.exe ว่าเป็น:
       a. Standalone WPF exe จริงๆ (แล้วทำไมถึงเล็กแค่ 5KB?)
       b. Launcher ที่เรียก PowerShell script หรือ DLL ต่อ?
       c. Electron/other wrapper?

       วิธีตรวจ:
       - ดูที่ src/ folder ว่ามีอะไร
       - ลองรัน exe แล้วดู process ที่ spawn ตามมา (Task Manager)
       - ตรวจ .csproj หรือ .ps1 ใน src/

2. [ ] อัพเดท HANDOFF.md ด้วยผลที่ได้
       → แก้ Tech Stack ให้ถูกต้อง
       → อธิบาย distribution model จริงๆ

3. [ ] อัพเดท CURRENT_TASK.md → Status: COMPLETED
```

---

## Work Log

| วันที่ | Session | สิ่งที่ทำ |
|---|---|---|
| 2026-09-17 | Santa Claude audit | สร้าง HANDOFF.md + CURRENT_TASK.md + KNOWN_ISSUES.md |
