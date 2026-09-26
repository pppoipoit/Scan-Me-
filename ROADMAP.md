# 🗺️ Roadmap & Development Ideas - Scan Me!

เอกสารรวบรวมแนวคิดและไอเดียสำหรับการพัฒนาต่อยอดโปรเจกต์ **Scan Me!** สู่การเป็นแอปพลิเคชันจัดการไฟล์และระบบคลังความรู้ระดับมืออาชีพ

---

## 🌟 ฟีเจอร์ที่พัฒนาสำเร็จแล้ว (Version 1.0.0 - ✅ RELEASED 2026-09-26)
- [x] โครงสร้างโปรเจกต์แบบ Modular (`src/engine`, `src/gui`, `src/utils`, `docs/`, `config/`, `tools/`, `tests/`)
- [x] หน้าต่าง GUI สไตล์ Modern Fluent Dark UI ด้วย WPF บน Windows
- [x] รองรับการสแกนทุกประเภทไฟล์ (`*.*`) และหมวดหมู่ Presets (Installers, Code, Docs, Media, Custom)
- [x] สวิตช์เปิด/ปิด การตรวจจับไฟล์ซ้ำ (MD5 Checksum Hash) พร้อมรายงานพื้นที่ที่เสียเปล่า
- [x] สวิตช์เปิด/ปิด การดึงข้อมูล Version / Company / Metadata ของไฟล์ `.exe` / `.dll` / `.sys` / `.msi`
- [x] ระบบส่งออกข้อมูล 4 รูปแบบ: **HTML (interactive)**, **TXT (tree)**, **JSON (SkillTree Schema)**, **CSV**
- [x] การค้นหาและกรองตารางแบบสด (Real-time Live Filter) จากชื่อ/โฟลเดอร์/นามสกุล/path
- [x] การ์ดแสดงสถิติรวม (Total Files, Size, Categories, Duplicates)
- [x] **Root Tree View** ที่รักษาโครงสร้างโฟลเดอร์จริง (ไม่ flatten เป็นรายการแบน)
- [x] **Right-click context menu** ในหน้า HTML + custom protocol `scanme://` เพื่อเปิดไฟล์/โฟลเดอร์จริง
- [x] **Copy Path** (Windows backslashes) และ **Copy Tree Text** (ครบทุกโฟลเดอร์)
- [x] รองรับการพัฒนาและทำงานร่วมกับ AI Agent (Cline, VS Code tasks & launch)
- [x] รองรับ Windows 7 SP1 / 10 / 11 — **Zero external dependencies**, ไม่ต้องใช้สิทธิ์แอดมิน
- [x] **Culture-invariant serialization** — ผลลัพธ์เหมือนกันทุก host (แก้บั๊กปี พ.ศ. 2569 เมื่อ 2026-09-26)

> 📖 ดูรายละเอียดฟีเจอร์ทั้งหมดที่ [`docs/PRODUCT_SPEC_v1.0.md`](docs/PRODUCT_SPEC_v1.0.md)
> 🏗️ ดูสถาปัตยกรรมที่ [`docs/TECHNICAL_SPEC.md`](docs/TECHNICAL_SPEC.md)

### 📄 เอกสารประกอบ v1.0.0
- [x] `README.md` + System Requirements table
- [x] `docs/PRODUCT_SPEC_v1.0.md` — product scope, features, user workflows, limitations
- [x] `docs/TECHNICAL_SPEC.md` — architecture, components, build, testing
- [x] `docs/SCHEMA_SPEC.md` — JSON data contract
- [x] `docs/ARCHITECTURE.md`, `docs/HANDOFF.md`, `docs/KNOWN_ISSUES.md`, `docs/USER_GUIDE.md`
- [x] `CHANGELOG.md` + `docs/RELEASE_NOTES_v1.0.0.md`

---


## 🚀 แผนพัฒนาในเวอร์ชันถัดไป (Future Milestones)

### 📌 Phase 2: Enhanced Intelligence & Visual Reports
1. **Interactive HTML Dashboard Report**:
   - สร้างปุ่มส่งออกรายงานเป็นหน้าเว็บแบบ Interactive Dashboard (ใช้ Chart.js หรือ ECharts) แสดงแผนภูมิวงกลมสัดส่วนพื้นที่, Tree Map ขนาดโฟลเดอร์ และตารางที่ค้นหา/จัดเรียงได้ในเบราว์เซอร์
2. **Advanced Duplicate Cleaner & Resolver**:
   - หน้าต่างเปรียบเทียบไฟล์ซ้ำแบบเคียงข้าง (Side-by-side) พร้อมปุ่มเลือกลบไฟล์ซ้ำ (Send to Recycle Bin) หรือย้ายไปยังโฟลเดอร์สำรอง
3. **Smart Tagging & AI File Categorization**:
   - ตรวจจับประเภทไฟล์อัตโนมัติจาก MIME Type หรือ Magic Bytes (ไม่พึ่งพาแค่นามสกุลไฟล์) เพื่อความแม่นยำสูง

---

### 📌 Phase 3: Launcher & SkillTree Mode (Application Hub)
1. **Direct Launch & Run Profile**:
   - ผู้ใช้สามารถดับเบิลคลิกหรือกดปุ่ม "Launch" เพื่อเปิดโปรแกรม/ไฟล์ติดตั้งที่สแกนเจอได้ทันทีจากตัว GUI
   - กำหนด Arguments / Parameters ในการรันไฟล์ติดตั้ง (เช่น `/qn`, `/silent` สำหรับงาน IT Deployment)
2. **Visual SkillTree / Node Graph**:
   - แสดงผลหมวดหมู่ของเครื่องมือและแอปพลิเคชันเป็นโครงสร้างต้นไม้ (SkillTree View / RPG-style Tech Tree) จัดเรียงตามโฟลเดอร์และหน้าที่การทำงาน

---

### 📌 Phase 4: Automation & Background Watcher
1. **Live Folder Watcher (Daemon Mode)**:
   - ตรวจจับโฟลเดอร์เป้าหมาย (เช่น โฟลเดอร์ `Downloads` หรือ `LocalRepo`) แบบ Real-time เมื่อมีไฟล์ใหม่เข้ามา ระบบจะทำการจัดหมวดหมู่และอัปเดตไฟล์ JSON ให้อัตโนมัติ

---

## 🚀 ศักยภาพเวอร์ชันถัดไป (Potential v2.0 Features)

> ส่วนนี้เป็น **แนวคิดเชิงกลยุทธ์** ยังไม่ผูก commitment เรื่อง timeline
> เรียงตามความสำคัญเชิงคุณค่าต่อผู้ใช้ ไม่ใช่ตามความยาก

### 📌 Phase A: ประสิทธิภาพและความน่าเชื่อถือ (v1.1)

1. **Incremental / Resumable Scan**
   - เปรียบเทียบ `LastWriteTime` + ขนาดกับผลสแกนครั้งก่อน แล้วสแกนเฉพาะที่เปลี่ยน
   - เก็บ cache ลง `output/.scan_cache.json` → สแกนซ้ำเร็วขึ้นหลายเท่า
   - ควรมาก่อนฟีเจอร์อื่น เพราะเป็นคอขวดประสิทธิภาพของทั้งแอป
2. **Duplicate Resolver & Safe Delete**
   - หน้าต่างเทียบไฟล์ซ้ำแบบ side-by-side พร้อม metadata เปรียบเทียบ
   - ปุ่ม **Send to Recycle Bin** (ไม่ลบถาวร) + **Keep newer/older automatically**
   - ต้องมี dry-run และ undo เสมอ — เครื่องมือลบไฟล์ต้องปลอดภัยเป็นหลัก
3. **Cross-host Regression Test (สำคัญต่อความถูกต้อง)**
   - สคริปต์ที่รัน `Scanner.ps1` ทั้ง `powershell.exe` และ `pwsh.exe` แล้ว diff JSON อัตโนมัติ
   - ป้องกันบั๊กวันที่/ตัวเลขกลับมาอีก (เคยเกิดจริงเมื่อ 2026-09-26)

### 📌 Phase B: รายงานและการวิเคราะห์ (v1.2 – v1.5)

4. **Interactive HTML Dashboard**
   - เพิ่ม Chart.js: pie สัดส่วนพื้นที่ตามหมวด, bar จำนวนไฟล์ตามนามสกุล, treemap ขนาดโฟลเดอร์
   - ตารางที่ sort/filter ได้จริงในหน้าเดียว (ไม่ต้องพึ่ง external JS ถ้า offline สำคัญ)
5. **Scan History & Diff**
   - เก็บประวัติการสแกน แล้วเทียบสองครั้ง: ไฟล์ใดเพิ่ม / หาย / เปลี่ยนขนาด
   - ตอบคำถาม "ที่เก็บไฟล์มีอะไรเปลี่ยนไปบ้าง" ได้ตรง ๆ
6. **Content-Based Categorization**
   - ตรวจจาก MIME type / Magic Bytes แทนการเชื่อนามสกุลอย่างเดียว
   - แก้ปัญหาไฟล์นามสกุลผิด หรือไฟล์ไม่มีนามสกุล

### 📌 Phase C: ขยายไปนอกเครื่อง (v2.0)

7. **🌍 Multi-language Support (i18n)**
   - แยก string ทุกจุดออกจาก XAML ไปยัง resource file
   - รองรับ ไทย / English เป็นอย่างน้อย (ผู้ใช้หลักเป็นคนไทย)
   - สลับภาษาได้โดยไม่ต้อง restart
8. **☁️ Cloud Sync Support**
   - ตรวจจับและแสดงสถานะไฟล์ใน **OneDrive** และ **Google Drive**
   - รองรับสถานะ synced / not-synced / placeholder (cloud-only)
   - ระวังเรื่องพาธสัมพัทธ์และไฟล์ที่ยังไม่ดาวน์โหลด
9. **🤖 AI-Powered File Analysis & Categorization**
   - ให้แนะนำหมวดหมู่จาก **เนื้อหาและชื่อไฟล์** ไม่ใช่แค่นามสกุล
   - ตรวจจับไฟล์ที่ดูซ้ำแต่ hash ต่าง (เช่น screenshot หลายเวอร์ชัน) ด้วย perceptual hash
   - ออกแบบให้ทำงาน **local-first** — เคารพหลักการเดิม ไม่ส่งไฟล์ออกเครือข่าย
10. **👁️ Real-time Folder Monitoring**
    - เฝ้าดู `FileSystemWatcher` แล้วอัปเดตสถิติ/JSON อัตโนมัติเมื่อมีไฟล์เข้า-ออก
    - โหมด daemon ที่ทำงานเงียบ ๆ (เช่นเฝ้า `Downloads`)
11. **🐧 Cross-platform Support (macOS / Linux)**
    - แนวทาง: แยก **core engine** ให้เป็น language-agnostic (อ่าน/เขียน JSON ตามสัญญาเดิม)
    - แล้วสร้าง front-end ใหม่ (เช่น Python + PySide หรือ Electron) ที่อ่าน output เดิม
    - **ข้อจำกัดเดิมที่ต้องแก้:** `scanme://` protocol, WPF UI, `FileVersionInfo`,
      `HKCU` registry เป็นของ Windows โดยเฉพาะ — ต้องมี fallback สำหรับแต่ละแพลตฟอร์ม

### 📌 Phase D: เชื่อมต่อกับระบบอื่น (ขนาดเล็ก แต่คุ้มมาก)

12. **SMB / UNC Network Drive Support** — สแกน `\\server\share` และแสดงสถานะ offline
13. **CLI สำหรับ automation** — โหมด headless พร้อม `--watch` และ exit code ที่ใช้ใน CI ได้
14. **Plugin / Preset Sharing** — ให้ผู้ใช้เขียน preset เป็น JSON แล้วแชร์กันได้

---

## 🔭 Long-Term Vision

> **จาก "เครื่องมือสแกนโฟลเดอร์" → "ระบบอัจฉรัยดิจิทัลของไฟล์" (Personal File Intelligence Layer)**

### ทิศทางระยะยาว 3 ชั้น

**ชั้นที่ 1 — รู้จักไฟล์ของคุณ (Understand)**
- สแกน → ทำ index → รู้ว่า "มีอะไรในเครื่อง, อยู่ตรงไหน, กินพื้นที่เท่าไร, อะไรซ้ำ"
- เป็นฐานข้อมูลที่ค้นหาได้จริง ไม่ใช่แค่รายงานครั้งเดียว

**ชั้นที่ 2 — ช่วยจัดการ (Organize & Act)**
- ช่วยล้างไฟล์ซ้ำอย่างปลอดภัย (มี preview + undo เสมอ)
- เฝ้าดูโฟลเดอร์แล้วเตือนเมื่อมีอะไรผิดปกติ (พื้นที่ใกล้เต็ม, ไฟล์ใหม่กองทับ)
- ให้คำแนะนำการจัดหมวด แต่ **ผู้ใช้อนุมัติเสมอ** — ไม่ลบเอง

**ชั้นที่ 3 — เข้าถึงได้ทุกที่ (Anywhere)**
- เดียวกันทั้ง Windows / macOS / Linux / mobile
- ค้นหาไฟล์ของตัวเองจากทุกอุปกรณ์ผ่าน local-first sync
- เชื่อมกับ AI agent ได้ตรง ๆ ผ่าน JSON contract ที่ **นิ่งและเข้าใจง่าย** (จุดแข็งที่มีอยู่แล้ว)

### หลักการที่จะไม่เปลี่ยน
- 🔒 **Local-first ตลอดไป** — ข้อมูลไฟล์ของผู้ใช้เป็นของผู้ใช้ ไม่ขึ้นเซิร์ฟเวอร์เรา
- 🪶 **Zero dependency** — ตราบใดที่ยังรักษาได้ จะไม่เพิ่ม dependency ที่ไม่จำเป็น
- 🧍 **ปลอดภัยเป็นค่าเริ่มต้น** — การลบ/ย้ายไฟล์ต้องมี preview, dry-run และ undo
- 🤝 **Data contract นิ่ง** — `SCHEMA_SPEC.md` คือสัญญาที่หักล้างไม่ได้
  (ถ้าจำเป็นต้องเปลี่ยน ต้องเป็น breaking change + version ใหม่ + migration guide)

### 🌍 ผลกระทบที่ตั้งใจสร้าง
เครื่องมือที่ใช้ได้จริงบน Windows 7 ที่ยังไม่มีในตลาด เพราะไม่ต้องติดตั้งอะไร ไม่ต้องต่อเน็ต
และไม่ต้องมีบัญชี — **ทำให้คนที่ไม่มีทางเลือกอื่น (เครื่องเก่า, องค์กรที่ล็อกเครื่อง)
ยังเข้าถึงเครื่องมือจัดการไฟล์ที่ดีได้**

---

## 💡 คำแนะนำสำหรับการเขียนโค้ดต่อยอด
2. **Cloud & Network Storage Scan**:
   - รองรับการสแกน Shared Network Drive (SMB/UNC paths เช่น `\\server\share`) และ Cloud Sync Folder (OneDrive, Google Drive)

---

## 💡 คำแนะนำสำหรับการเขียนโค้ดต่อยอด
- **หากต้องการขยายฟังก์ชันสแกน**: ให้เพิ่ม Logic ใน `src/engine/Scanner.ps1`
- **หากต้องการเพิ่มปุ่มหรือฟีเจอร์ใน GUI**: ให้ปรับแต่ง XAML ใน `src/gui/MainWindow.xaml` และเชื่อม Event ใน `src/gui/MainWindow.ps1`
- **หากต้องการสร้าง Web Frontend หรือเชื่อมต่อผ่าน Python / Electron**: สามารถอ่านข้อมูลจากไฟล์ผลลัพธ์ `output/latest_scan.json` ได้โดยตรงตามสเปกใน `docs/SCHEMA_SPEC.md`
