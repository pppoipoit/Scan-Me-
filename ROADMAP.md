# 🗺️ Roadmap & Development Ideas - Scan Me!

เอกสารรวบรวมแนวคิดและไอเดียสำหรับการพัฒนาต่อยอดโปรเจกต์ **Scan Me!** สู่การเป็นแอปพลิเคชันจัดการไฟล์และระบบคลังความรู้ระดับมืออาชีพ

---

## 🌟 ฟีเจอร์ที่พัฒนาสำเร็จแล้ว (Version 1.0.0 - Current)
- [x] โครงสร้างโปรเจกต์แบบ Modular (`src/engine`, `src/gui`, `src/utils`, `docs/`, `config/`)
- [x] หน้าต่าง GUI สไตล์ Modern Fluent Dark UI ด้วย WPF บน Windows
- [x] รองรับการสแกนทุกประเภทไฟล์ (`*.*`) และหมวดหมู่ Presets (Installers, Code, Docs, Media, Custom)
- [x] สวิตช์เปิด/ปิด การตรวจจับไฟล์ซ้ำ (MD5 Checksum Hash)
- [x] สวิตช์เปิด/ปิด การดึงข้อมูล Version / Company / Metadata ของไฟล์ `.exe` / `.msi`
- [x] ระบบส่งออกข้อมูล (Export) เป็นมาตรฐาน JSON (SkillTree Schema) และ CSV
- [x] การค้นหาและกรองตารางแบบสด (Real-time Live Filter)
- [x] การ์ดแสดงสถิติรวม (Total Files, Size, Categories, Duplicates)
- [x] รองรับการพัฒนาและทำงานร่วมกับ AI Agent (Cline, VS Code tasks & launch)

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
2. **Cloud & Network Storage Scan**:
   - รองรับการสแกน Shared Network Drive (SMB/UNC paths เช่น `\\server\share`) และ Cloud Sync Folder (OneDrive, Google Drive)

---

## 💡 คำแนะนำสำหรับการเขียนโค้ดต่อยอด
- **หากต้องการขยายฟังก์ชันสแกน**: ให้เพิ่ม Logic ใน `src/engine/Scanner.ps1`
- **หากต้องการเพิ่มปุ่มหรือฟีเจอร์ใน GUI**: ให้ปรับแต่ง XAML ใน `src/gui/MainWindow.xaml` และเชื่อม Event ใน `src/gui/MainWindow.ps1`
- **หากต้องการสร้าง Web Frontend หรือเชื่อมต่อผ่าน Python / Electron**: สามารถอ่านข้อมูลจากไฟล์ผลลัพธ์ `output/latest_scan.json` ได้โดยตรงตามสเปกใน `docs/SCHEMA_SPEC.md`
