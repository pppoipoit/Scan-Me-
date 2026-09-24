# 🏷️ Extension Filter & Category Guide - Scan Me!

เอกสารนี้อธิบายรายละเอียดเกี่ยวกับ Preset หมวดหมู่ไฟล์ และการกำหนด Filter ใน **Scan Me!**

---

## 1. Built-in Preset Categories

| Preset Name | Target File Extensions | เหมาะสำหรับ |
| :--- | :--- | :--- |
| **🌐 All Files** | `*.*` | สแกนทุกไฟล์โดยไม่มีการกรอง (ครบถ้วนสมบูรณ์ที่สุด) |
| **📦 Installers & Packages** | `*.exe`, `*.msi`, `*.zip`, `*.msix`, `*.rar`, `*.7z`, `*.iso`, `*.tar`, `*.gz` | จัดระเบียบคลังไฟล์ติดตั้ง ซอฟต์แวร์ และไดรเวอร์ |
| **💻 Code & Dev** | `*.js`, `*.ts`, `*.py`, `*.ps1`, `*.json`, `*.html`, `*.css`, `*.cpp`, `*.c`, `*.cs`, `*.dart`, `*.yaml`, `*.yml`, `*.md` | สแกน Source Code, Configuration และ Script ในโปรเจกต์ |
| **📄 Documents** | `*.pdf`, `*.docx`, `*.doc`, `*.xlsx`, `*.xls`, `*.pptx`, `*.txt`, `*.csv` | สำรวจเอกสาร งานวิจัย เอกสารสำนักงาน และตารางข้อมูล |
| **🎨 Media** | `*.png`, `*.jpg`, `*.jpeg`, `*.gif`, `*.svg`, `*.webp`, `*.mp4`, `*.mkv`, `*.mov`, `*.mp3`, `*.wav` | จัดการไฟล์รูปภาพ มีเดีย วิดีโอ และเสียง |

---

## 2. Custom Extensions Syntax

หากเลือกโหมด **⚙️ Custom Extensions** คุณสามารถพิมพ์รายชื่อนามสกุลไฟล์ที่ต้องการได้โดยใช้เครื่องหมายจุลภาค (`,`), อัฒภาค (`;`), หรือช่องว่างในการคั่น เช่น:

```text
*.exe, *.msi, *.zip, *.pdf
```
หรือ
```text
exe msi zip pdf
```
*(ระบบจะเพิ่มเครื่องหมาย `*.` ให้อัตโนมัติในกรณีที่ไม่ได้พิมพ์)*
