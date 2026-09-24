# 📄 JSON Schema Specification (SkillTree Standard) - Scan Me!

เอกสารนี้กำหนดโครงสร้างมาตรฐาน (Data Contract) ของไฟล์ JSON ที่ส่งออกจาก **Scan Me!** เพื่อให้นักพัฒนาสามารถนำผลลัพธ์ไปเขียนโค้ดเชื่อมต่อกับ Backend, Frontend Dashboard, หรือ AI Pipeline ได้อย่างแม่นยำ

---

## 1. Top-Level Structure

```json
{
  "Scan_Meta": { ... },
  "Category_Stats": { ... },
  "Extension_Stats": { ... },
  "Files": [ ... ]
}
```

---

## 2. Detailed Schema Definitions

### 2.1 `Scan_Meta` (Object)
ประกอบด้วยข้อมูลสรุปภาพรวมของการสแกน:

| Field Name | Type | Description |
| :--- | :--- | :--- |
| `Target_Folder` | `string` | Absolute path ของโฟลเดอร์ต้นทางที่ถูกสแกน |
| `Scan_Timestamp` | `string` | วันที่และเวลาที่สแกนเสร็จสิ้น (`yyyy-MM-dd HH:mm:ss`) |
| `Scan_Duration_Sec` | `number` | เวลาที่ใช้ในการประมวลผลทั้งหมด (หน่วย: วินาที) |
| `Total_Files` | `integer` | จำนวนไฟล์ทั้งหมดที่สแกนพบ |
| `Total_Size_Bytes` | `integer` | ขนาดรวมของไฟล์ทั้งหมดในหน่วย Bytes |
| `Total_Size_MB` | `number` | ขนาดรวมของไฟล์ทั้งหมดในหน่วย Megabytes |
| `Total_Size_Human` | `string` | ขนาดรวมที่แปลงเป็นหน่วยที่อ่านง่าย (เช่น `1.45 GB`) |
| `Hash_Calculated` | `boolean` | สถานะว่ามีการเปิดตัวเลือกคำนวณ Checksum Hash หรือไม่ |
| `Duplicate_Files` | `integer` | จำนวนไฟล์ที่พบว่ามี Checksum Hash ซ้ำกับไฟล์อื่น |
| `Duplicate_Space_Wasted`| `string` | พื้นที่จัดเก็บที่สูญเสียไปจากไฟล์ที่ซ้ำกัน |
| `Metadata_Extracted` | `boolean` | สถานะว่ามีการเปิดตัวเลือกดึง Metadata หรือไม่ |

---

### 2.2 `Category_Stats` & `Extension_Stats` (Object)
สรุปสถิติตามหมวดหมู่โฟลเดอร์ย่อย และตามนามสกุลไฟล์:

```json
"Category_Stats": {
  "engine": {
    "Count": 1,
    "TotalBytes": 5214
  }
},
"Extension_Stats": {
  ".ps1": {
    "Count": 3,
    "TotalBytes": 16400
  }
}
```

---

### 2.3 `Files` (Array of Objects)
รายการข้อมูลของแต่ละไฟล์ที่ถูกสแกน:

```json
{
  "Category_Folder": "engine",
  "Relative_Path": "src\\engine\\Scanner.ps1",
  "File_Name": "Scanner.ps1",
  "Full_Path": "D:\\Project\\Scan Me!\\src\\engine\\Scanner.ps1",
  "Extension": ".ps1",
  "Size_Bytes": 5214,
  "Size_MB": 0.01,
  "Size_Formatted": "5.09 KB",
  "Hash": "D41D8CD98F00B204E9800998ECF8427E",
  "IsDuplicate": false,
  "Metadata": {
    "FileType": ".exe",
    "IsReadOnly": false,
    "CreationTime": "2026-08-24 14:00:00",
    "LastWriteTime": "2026-08-24 14:30:00",
    "FileVersion": "1.0.0.0",
    "ProductVersion": "1.0.0",
    "CompanyName": "My Company",
    "FileDescription": "Core Setup Utility",
    "OriginalFileName": "setup.exe"
  },
  "LastModified": "2026-08-24 14:30:00"
}
```
