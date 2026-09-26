# 📘 PRODUCT SPEC — Scan Me! v1.0.0

> **Retrospective Specification** — เอกสารนี้เขียนย้อนหลังหลังปล่อย v1.0.0 เพื่อบันทึกสิ่งที่สร้างจริง
> เป็น **baseline** สำหรับการพัฒนาต่อ โดยอ้างอิงจากโค้ดจริงในรีโพเชอร์ ไม่ใช่จากความทรงจำ
>
> **Status**: ✅ Released 2026-09-26 · **Version**: 1.0.0 · **Owner**: DRKMTTR Studio (Tokenmee)

---

## 1. Product Overview & Vision

### 1.1 ปัญหาที่เราแก้

คนที่มีไฟล์เยอะมัก **รู้ว่ามีไฟล์อยู่เยอะ แต่ไม่รู้ว่าอยู่ที่ไหน ใช้พื้นที่เท่าไร และมีอะไรซ้ำกันบ้าง**
เครื่องมือที่มีอยู่มักตอบได้แค่ข้อมูลดิบ (รายการไฟล์แบบยาวเป็นพันบรรทัด) ซึ่งอ่านยากกว่าที่ควรจะเป็น
และเครื่องมือสำเร็จรูปที่ "สวยงาม" มักต้องติดตั้ง ใช้เน็ต หรือผูกกับ cloud

### 1.2 วิสัยทัศน์

> **เปลี่ยนโฟลเดอร์ที่รกรุง ให้กลายเป็น "แผนที่" ที่อ่านออก**

Scan Me! สแกนโฟลเดอร์แบบเรียงลำดับ แล้วแสดงผลเป็น **Tree View ที่เข้าใจได้ทันที** พร้อมสถิติที่ตอบคำถามได้จริง
(มีกี่ไฟล์ / กินพื้นที่เท่าไร / อะไรซ้ำ) และ export ได้ทั้งแบบ **อ่านเอง** (HTML, TXT) และแบบ **เอาไปใช้ต่อ** (JSON, CSV)

### 1.3 หลักการออกแบบ (Design Principles)

| หลักการ | ความหมายในทางปฏิบัติ |
|---|---|
| **Local-first** | ไม่มีการส่งข้อมูลออกเครือข่าย ไม่มีบัญชี ไม่มี telemetry |
| **Zero dependency** | ใช้เฉพาะของที่มากับ Windows (PowerShell + WPF) — ไม่ติดตั้งอะไรเพิ่ม |
| **No admin rights** | ทำงานระดับผู้ใช้ทั่วไป HKCU เท่านั้น |
| **Structure over list** | เสนอ *โครงสร้าง* (tree) ไม่ใช่แค่ *รายการ* (flat list) |
| **Machine-readable** | JSON ต้องตรงตาม `SCHEMA_SPEC.md` เพื่อให้ AI/automation ใช้ต่อได้ |
| **Locale-safe** | ผลลัพธ์ต้องเหมือนกันทุกเครื่อง ไม่ว่า locale หรือ PowerShell เวอร์ชันไหน |

---

## 2. Core Features (v1.0.0)

### 📁 Deep Folder Scanning with Root Tree View
- สแกนแบบ recursive ทั้งโฟลเดอร์และโฟลเดอร์ย่อยทั้งหมด
- แสดงผลเป็น **Root Tree View** ที่รักษาโครงสร้างจริง ไม่ flatten เป็นรายการแบน
- แสดงขนาดโฟลเดอร์ จำนวนรายการ ขนาดไฟล์ และ path รูปแบบ Windows
- รองรับการรวมไฟล์ซ่อน (hidden) เป็นตัวเลือก
- ตัวกรองด้วย extension แบบลิสต์ (`*.exe, *.msi`)

### 📊 File Statistics
- การ์ดสถิติสรุป: **Total Files**, **Total Size**, **จำนวนโฟลเดอร์/ชนิดไฟล์**, **จำนวนไฟล์ซ้ำ**
- สรุปตาม **Category** (โฟลเดอร์แม่) และ **Extension** (นามสกุลไฟล์) พร้อม Count + TotalBytes
- แสดงเวลาที่ใช้สแกน (Scan_Duration_Sec)

### 🔐 MD5 Hash Duplicate Detection
- คำนวณ checksum ตามต้องการ (เปิด/ปิดได้) เพื่อระบุไฟล์ที่**เนื้อหาเหมือนกัน**
- ค่าเริ่มต้นของ GUI คือ **MD5**; engine รองรับ `SHA256` ด้วย (ผ่าน `-HashAlgorithm`)
- รายงานจำนวนไฟล์ซ้ำ และ **พื้นที่ที่ "เสียเปล่า"** ที่อาจล้างได้
- ทำเครื่องหมาย `[DUPLICATE]` ในตารางและในไฟล์ export

### 🎨 Export — 4 รูปแบบ

| รูปแบบ | ฟังก์ชัน | เหมาะกับ |
|---|---|---|
| **🌳 HTML** | `Export-ScanResultToHtmlTree` | แชร์/เปิดดู — interactive: expand/collapse, search, icons, context menu, Copy Path/Tree |
| **📝 TXT** | `Export-ScanResultToTextTree` | เอาไปวางในเอกสาร/ทิกเก็ต — ต้นไม้ UTF-8 พร้อมขนาดและแท็กซ้ำ |
| **🧾 JSON** | `Export-ScanResultToJson` | Automation/AI — ข้อมูลเต็มตาม `SCHEMA_SPEC.md` |
| **📊 CSV** | `Export-ScanResultToCsv` | Excel/สเปรดชีต — ตารางแบนกรองง่าย |

> ทุกการสแกนจะ **บันทึกอัตโนมัติ** เป็น `output/latest_scan.json`, `output/latest_tree.html`,
> `output/latest_tree.txt` เพื่อให้มีของล่าสุดใช้งานต่อได้ทันที

---


### 🖱️ Right-Click Context Menu with `scanme://` Protocol
- ในหน้า HTML export ที่แต่ละแถว (โฟลเดอร์/ไฟล์) มี context menu ของตัวเอง
  - 📂 **Open in Windows Explorer** (โฟลเดอร์)
  - 📄 **Open in Default App** (ไฟล์)
  - 📋 **Copy Path**
- ใช้ custom protocol `scanme://open?path=<URL-encoded path>` โดย encode ถูกต้อง
  รองรับชื่อที่มี **ช่องว่าง**, **`!`**, และ **อักษรไทย/Unicode**
- `tools/ScanMeOpener.ps1` ตรวจสอบ URL อย่างเข้มงวด แล้วเปิด**เฉพาะ**พาธที่มีอยู่จริงบนเครื่อง
- ปิดเมนูเมื่อคลิกนอกพื้นที่, กด Escape, เลื่อนหน้า หรือคลิกขวาอีกครั้ง
- พื้นที่นอกแถวยังคงใช้ context menu ปกติของเบราว์เซอร์

> 💡 นี่คือ context menu **ภายในหน้า HTML** ไม่ใช่การแทนที่เมนูขวาของ Windows Explorer

### 📋 Copy Path และ Copy Tree Text
- **Copy Path** — คัดลอก path เป็น **Windows backslash (`\`) เสมอ** แม้ source ใช้ `/`
- **Copy Tree Text** — คัดลอก **ต้นไม้ทั้งหมด** (ทุกโฟลเดอร์ ไม่ว่าจะพับหรือขยายอยู่)
  พร้อม path, ขนาด, จำนวน, ไอคอน และ version ที่ตรวจพบ
  *(แก้บั๊กเดิม: เดิมใช้ `innerText` ซึ่งตัดโฟลเดอร์ที่ collapsed ทิ้ง — เปลี่ยนมา embed `TREE_DATA` JSON แทน)*

### 🔍 Live Search และ Filtering
- ช่องค้นหาในตารางผลลัพธ์ กรองแบบทันทีทุกครั้งที่พิมพ์
- ค้นหาได้จาก **ชื่อไฟล์, โฟลเดอร์, นามสกุลไฟล์, และ full path**
- แสดงสถานะว่า "N of M items matching filter"
- ค้นหาในหน้า HTML export ก็มี live search พร้อม highlight ข้อความที่ตรง

### ⚙️ Filter Presets และ Extensions
- Preset: **All Files**, **Installers & Packages**, **Code & Dev**, **Documents & Office**,
  **Media**, **Custom**
- เลือก preset แล้วเติมช่อง extension ให้อัตโนมัติ หรือพิมพ์เองได้
- ตัวเลือกเสริม: **Check Duplicates (MD5)**, **Extract .exe/.dll/.sys/.msi Metadata**,
  **Include Hidden Files**
- ค่าเริ่มต้นและ preset อ่านจาก `config/default_config.json`

---

## 3. User Workflows

### 3.1 สแกนโฟลเดอร์และอ่านสถิติ (5 นาที)
1. ดับเบิลคลิก `ScanMe.exe` (หรือ `run.bat`)
2. กด **Browse** เลือกโฟลเดอร์เป้าหมาย
3. เลือก preset (เช่น Installers) — หรือกด All Files
4. *(ถ้าต้องการ)* เปิด **Check Duplicates (MD5)** และ **Include Hidden Files**
5. กด **Start Scan** → ดู progress bar และชื่อไฟล์ล่าสุด
6. อ่านการ์ดสถิติ 4 ใบ และตารางผลลัพธ์

### 3.2 หาไฟล์ที่ต้องการ
- พิมพ์ในช่อง live search → ตารางกรองทันที (ค้นได้ทั้งชื่อและ path)

### 3.3 ส่งออกข้อมูล
- **JSON** → ปุ่ม Export JSON → เลือกที่บันทึก → ใช้กับ automation/AI
- **CSV** → ปุ่ม Export CSV → เปิดใน Excel
- **HTML** → ปุ่ม Export Interactive HTML Tree → เปิดในเบราว์เซอร์ทันที (ถามก่อน)
- **TXT** → ปุ่ม Export Plain Text Tree → เปิดใน Notepad (ถามก่อน)

### 3.4 แชร์ผลการสแกนให้ทีม
1. Export เป็น **HTML** แล้วส่งไฟล์ `.html` ไปให้ทีม
2. ผู้รับเปิดในเบราว์เซอร์ → คลิกลูกศรขยาย/ยุบ, ค้นหา, Copy Path
3. ถ้าต้องการคลิกเปิดไฟล์จริงในเครื่อง → ลงทะเบียน protocol ครั้งเดียว:
   `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\register_protocol.ps1"`
   (ต้องทำแยกทีละเครื่อง และเบราว์เซอร์จะขึ้นขออนุญาตครั้งแรก)

### 3.5 ใช้งานจาก command line (ไม่เปิด GUI)
```powershell
.\src\engine\Scanner.ps1 -TargetFolder "D:\Data" -OutputFile ".\output\data.json" `
                        -IncludeAllFiles -CalculateHash -ExtractMetadata
```

### 3.6 ล้างตาราง
- กด **Clear** → ล้างผลลัพธ์, รีเซ็ตการ์ดสถิติ และ **ปิดปุ่ม Export ทั้ง 4** (กัน export ข้อมูลค้างเก่า)

---

## 4. Supported Platforms

| Platform | สถานะ | Prerequisites |
| :--- | :--- | :--- |
| **Windows 11** | ✅ รองรับเต็มรูปแบบ | .NET Framework 4.8 (มากับเครื่อง) + Windows PowerShell 5.1 |
| **Windows 10** | ✅ รองรับเต็มรูปแบบ | เหมือนข้างบน |
| **Windows 7 SP1** | ✅ รองรับ *(มีเงื่อนไข)* | **.NET Framework 4.8 แบบ full** (ห้ามใช้ Client Profile) + **Windows Management Framework 5.1** |

**ข้อจำกัดเฉพาะ Windows 7:**
- ❌ **PowerShell 7 ไม่รองรับ** — Microsoft ไม่ release บน Win7 (ใช้ Windows PowerShell 5.1 แทน)
- ❌ **.NET Framework 4 Client Profile ใช้ไม่ได้** — ไม่มี WPF → อาการ "The type initializer for ... threw an exception"
- ✅ `ScanMe.exe` target .NET Framework 4.x (AnyCPU) จึงรันได้

**Engine hosts ที่ทดสอบแล้ว (2026-09-26):** Windows PowerShell 5.1 และ PowerShell 7.6.6
ผลลัพธ์ JSON **เหมือนกันทุกประการ** (ยืนยันด้วยการรันจริงบนเครื่อง locale `th-TH`)

---

## 5. Known Limitations (v1.0.0)

### 🔍 ด้านประสิทธิภาพ
- **ตรวจไฟล์ซ้ำช้าเมื่อเปิดใช้** — ต้องอ่านเนื้อหาไฟล์ทั้งหมดเพื่อคำนวณ MD5
  (เป็นธรรมชาติของการ hash แต่ต้องเตือนผู้ใช้: ปิดไว้ก่อนถ้าต้องการแค่ inventory เร็ว ๆ)
- **การสแกนขนาดใหญ่กินเวลา** — ไม่มีการขนานงาน (parallelism) ใน v1.0.0
- การค้นหาแบบ live ทำงานบนรายการทั้งหมดใน memory → ขนาดใหญ่มากอาจช้าลง

### 🗑️ ด้านการจัดการไฟล์
- **ยังไม่ลบไฟล์ซ้ำให้อัตโนมัติ** — รายงานอย่างเดียว ผู้ใช้ต้องลบเอง (เป็นการตัดสินใจที่ปลอดภัย)
- ไม่มี "Safe delete to Recycle Bin" แบบ side-by-side เทียบไฟล์

### 🧩 ด้านขอบเขต
- **ไม่ลบ/ย้ายไฟล์** — เป็นเครื่องมือ read-only อย่างเดียว
- ไม่มีการตรวจจับชนิดไฟล์ด้วย MIME/Magic Bytes — ใช้นามสกุลไฟล์เป็นหลัก
- Metadata ดึงได้เฉพาะ `.exe`, `.dll`, `.sys`, `.msi` (ใช้ `FileVersionInfo`)
- ไม่มีการตรวจจับไฟล์ที่เข้าถึงไม่ได้ — ใช้ `ErrorAction = 'SilentlyContinue'` (ไฟล์ที่ล็อกจะถูกข้ามเงียบ ๆ)

### 🌐 ด้านการเชื่อมต่อ
- **Custom protocol ต้องลงทะเบียนแยกทีละเครื่อง** — ทำที่ `HKCU\Software\Classes\scanme`
- เบราว์เซอร์จะขึ้นขออนุญาต **"Open this app?"** ครั้งแรก (เป็นพฤติกรรมปกติของเบราว์เซอร์ ไม่ใช่บั๊ก)
- พาธที่เปิดได้ต้องเป็น **พาธแบบเต็มบนเครื่องนั้น** (`C:\...` หรือ `\\server\share`) — ไม่รองรับพาธของเครื่องอื่น

### 🧪 ด้านการทดสอบ
- ไม่มี unit test framework มาตรฐาน — ใช้สคริปต์ตรวจสอบแบบ exit-code ใน `tests/*.ps1`
- มี `tests/cross_host_json_test.ps1` ครอบเรื่อง host-independence ของ JSON แล้ว
  (สแกนจริงทั้ง 5.1 และ 7 แล้ว diff) แต่ยังไม่มีเทสต์เฉพาะสำหรับ relative-path stripping
- บางเทสต์ต้องใช้ Node.js (`context_menu_test.ps1` ใช้ Node DOM stub) และ UIAutomation (`ui_dropdown_test.ps1`)

---

## 6. Future Considerations

> รายละเอียดเชิงลึกและลำดับความสำคัญ ดูที่ [`ROADMAP.md`](../ROADMAP.md)

### ระยะถัดไป (v1.1)
- ⚡ **Incremental scan** — เปรียบเทียบ hash/mtime เดิม แล้วสแกนเฉพาะที่เปลี่ยน (เร็วขึ้นมาก)
- 🗑️ **Duplicate resolver** — เทียบไฟล์ซ้ำแบบ side-by-side + ส่ง Recycle Bin (ไม่ลบถาวร)
- 📊 **Chart.js dashboard** ใน HTML export (pie สัดส่วนพื้นที่, treemap)

### ระยบกลาง (v1.5)
- 🗂️ **Category by MIME / Magic Bytes** แทนการใช้นามสกุลอย่างเดียว
- 💾 **Scan history / comparison** — เปรียบเทียบผลสแกนสองครั้งว่าอะไรเพิ่ม/หาย

### ระยะไกล (v2.0)
- 🌍 **Multi-language (i18n)** — เปลี่ยน UI เป็นภาษาไทย/อังกฤษ
- ☁️ **Cloud sync** — OneDrive / Google Drive
- 🤖 **AI-powered categorization** — วิเคราะห์และจัดหมวดหมู่อัตโนมัติ
- 👁️ **Real-time folder monitoring** — เฝ้าดูโฟลเดอร์แล้วอัปเดตอัตโนมัติ
- 🐧 **Cross-platform** — macOS / Linux

---

## 7. Success Criteria (v1.0.0 ✅)

| เกณฑ์ | สถานะ |
| :--- | :--- |
| สแกน recursive ได้ครบทุกโฟลเดอร์ | ✅ |
| แสดง Tree View ที่รักษาโครงสร้าง (ไม่ flatten) | ✅ |
| สถิติครบ: ไฟล์ / ขนาด / หมวดหมู่ / ไฟล์ซ้ำ | ✅ |
| ตรวจไฟล์ซ้ำด้วย MD5 ได้ | ✅ |
| Export ได้ครบ 4 รูปแบบ (HTML/TXT/JSON/CSV) | ✅ |
| Context menu + `scanme://` เปิดไฟล์/โฟลเดอร์จริงได้ | ✅ |
| Copy Path / Copy Tree Text ถูกต้อง (backslash + ครบทุกโฟลเดอร์) | ✅ |
| Live search กรองได้ทันที | ✅ |
| JSON ตรงตาม `SCHEMA_SPEC.md` | ✅ |
| **ผลลัพธ์เหมือนกันทุก host (5.1 / 7.6)** | ✅ ยืนยัน 2026-09-26 ด้วย `tests/cross_host_json_test.ps1` |
| Zero external dependencies | ✅ |
| ไม่ต้องใช้สิทธิ์แอดมิน | ✅ |

---

<div align="center">

**Scan once. Understand everything.** 🚀
*Retrospective Spec — v1.0.0 · 2026-09-26*

</div>
