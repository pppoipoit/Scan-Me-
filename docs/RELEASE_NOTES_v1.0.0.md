# 🎉 Scan Me! v1.0.0 — Release Notes

<div align="center">

### ⚡ From a folder scanner to a polished file intelligence experience ✨

**Release tag:** `v1.0.0`  
**Platform:** Windows 10/11  
**Interface:** Modern dark WPF UI  
**Engine:** PowerShell 5.1+ / PowerShell 7+

</div>

---

## 🚀 Release Highlights

**Scan Me! v1.0.0** is the first complete release of a Windows application for deep folder scanning, file intelligence, and shareable tree catalogs. It turns a selected folder into an organized, searchable map with statistics, duplicate detection, structured exports, and a browser-friendly HTML presentation.

This release represents the journey from a basic folder-scanning script to a complete desktop experience with a modern interface, modular architecture, and practical Windows integrations.

## 🧭 The Journey

### 🧪 1. From basic script to scanning engine

The foundation became a reusable PowerShell engine that recursively walks a target folder, supports extension filters, tracks categories and extensions, and records reliable file metadata.

### 🖥️ 2. A real Windows application experience

A WPF interface was added with a Fluent-inspired dark theme, responsive controls, live status updates, progress feedback, dynamic statistics, and a searchable results table.

### 🧠 3. More intelligence in every result

Optional MD5 duplicate detection, wasted-space reporting, file checksum data, and binary metadata extraction help users understand not just what files exist, but which files may be redundant and what an executable is.

### 🌳 4. A catalog that is easy to share

The results can be exported as structured JSON, spreadsheet-friendly CSV, a clean text tree, or a polished interactive HTML tree that works without a server.

### 🖱️ 5. A practical bridge back to Windows

The HTML tree adds row-level right-click actions using the custom `scanme://` protocol, allowing a user to open a folder in Explorer or open a file with its default application without leaving the catalog workflow.

## ✨ Completed Features

### 📁 Deep Folder Scanning & Root Tree View

- Recursively scans a selected folder and every nested folder.
- Preserves the complete root hierarchy in tree exports.
- Shows folder sizes, child counts, file sizes, and Windows paths.
- Supports All Files, built-in category presets, custom extensions, and hidden files.
- Provides live search/filter in the WPF results table.

### 📊 File Statistics & Duplicate Detection (MD5)

- Displays total file count, total size, category/extension summaries, and scan duration.
- Calculates MD5 checksums on demand to identify duplicate content.
- Reports duplicate file counts and potentially wasted space.
- The underlying engine also supports SHA256 when used directly.
- Optionally extracts version, company, description, and original filename metadata from supported binaries.

### 🖱️ Right-Click Context Menu

Inside an exported HTML tree, right-clicking a folder or file row provides the relevant action:

- **📂 Open in Windows Explorer** for folders.
- **📄 Open in Default App** for files.
- **📋 Copy Path** for a Windows-normalized path.

The actions use the `scanme://open?path=...` protocol. Paths are URL-encoded, validated, and restricted to existing local folders or files. The first browser use may show a normal Windows/browser security confirmation.

### 📋 Smart Copy

- **Copy Path** uses Windows `\` separators for easy pasting into Explorer, PowerShell, and terminals.
- **Copy Full Tree Text** copies the full embedded tree even when some folders are collapsed on screen.
- **Tree (TXT)** exports a clean UTF-8 hierarchy for documentation, tickets, notes, and handoffs.

### 🎨 Beautiful HTML Export

- 🌟 Polished dark-themed HTML presentation.
- 🔽 Interactive dropdown-style expand/collapse tree controls.
- 🔍 Live search with highlighted matches.
- 🧩 Consistent icons for folders and common file categories.
- 📋 Copy Path and Copy Full Tree Text buttons.
- 🔽 Expand All and Collapse All controls.
- 🖱️ Row-level context menu with Explorer/default-app actions.
- 🧾 Scan header with target, timestamp, file count, and total size.

### ⚡ PowerShell + WPF Performance

- ⚙️ Native Windows stack with no third-party runtime dependency.
- 🪟 Responsive WPF UI with live progress and status feedback.
- 🧵 Modular engine, GUI, utilities, configuration, and documentation layers.
- 🧪 Focused tests cover tree exports, dropdowns, icons, copy behavior, and the context menu.

## 📤 Export Options

| Format | Purpose |
|---|---|
| 🌳 **HTML** | Interactive sharing, searching, tree navigation, and Windows actions |
| 📝 **TXT** | Human-readable folder tree and handoff notes |
| 🧾 **JSON** | Structured data for applications, automation, and AI workflows |
| 📊 **CSV** | Excel/Google Sheets analysis and filtering |

The JSON format follows the project data contract in [`docs/SCHEMA_SPEC.md`](SCHEMA_SPEC.md).

## 🛡️ First-Time HTML Setup

To enable the HTML right-click actions, register the per-user protocol once from the project root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\register_protocol.ps1"
```

No administrator rights are required. If the project is moved, run the command again. To remove the registration, use `tools\unregister_protocol.ps1`.

## 🧰 Distribution Notes

- 🖥️ `ScanMe.exe` is the Windows launcher for the project.
- 📁 Keep the project folders (`src`, `assets`, `config`, and related files) beside the EXE.
- 📦 For the simplest user download, publish a ZIP containing the complete project and optionally attach `ScanMe.exe` as a separate binary asset.
- 🖼️ If Windows Explorer shows an old icon after rebuilding the EXE, run `ie4uinit.exe -show` to refresh the Icon Cache.

## 🧪 Quality & Compatibility

- ✅ Windows 10 and Windows 11
- ✅ Windows PowerShell 5.1+
- ✅ PowerShell 7+
- ✅ UTF-8 output for international filenames and documents
- ✅ Literal-path handling for spaces and special characters
- ✅ Optional hidden-file inclusion
- ✅ Feature tests for HTML dropdowns, copy actions, icon mapping, and context-menu behavior

## 🙏 Thank You

Thank you to everyone who helped shape Scan Me! from a prototype into a useful, release-ready Windows tool. v1.0.0 is the foundation for future improvements while preserving a simple local-first workflow.

