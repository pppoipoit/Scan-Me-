<div align="center">

# ⚡ Scan Me! ✨

### 🚀 Fast, beautiful file intelligence for Windows

**Deep scanning • Root tree exploration • Duplicate detection • Interactive HTML export**

[![Windows](https://img.shields.io/badge/Platform-Win%207%20SP1%20%7C%2010%20%7C%2011-2563EB.svg)](https://microsoft.com)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-5391FE.svg)](https://github.com/PowerShell/PowerShell)
[![WPF](https://img.shields.io/badge/UI-WPF%20Fluent%20Dark-06B6D4.svg)]()
[![Release](https://img.shields.io/badge/Release-v1.0.0-10B981.svg)]()

</div>

---

## 🌟 What is Scan Me!?

**Scan Me!** is a Windows file intelligence, cataloging, and tree-view application that turns a folder into a clear, searchable map. It combines a native PowerShell scanning engine with a polished WPF interface, then gives you practical outputs: statistics, duplicate insights, JSON/CSV data, plain-text trees, and a polished interactive HTML tree.

> 💡 **Perfect for:** cleaning up storage, understanding large projects, preparing file inventories, cataloging installers, and sharing a folder map with teammates or tools that consume structured data.

## ✨ Completed Features

### 📁 Deep Folder Scanning & Root Tree View

- 🔍 Recursively scans the selected folder and all nested folders.
- 🌲 Exports a true **root tree view** that preserves the folder hierarchy instead of flattening every file into a list.
- 🗂️ Includes folder sizes, item counts, file sizes, and clean Windows-style paths.
- 🧩 Supports All Files, built-in category presets, custom extensions, and hidden-file inclusion.
- 🔎 Includes a live table search/filter while scanning results are displayed.

### 📊 File Statistics & Duplicate Detection (MD5)

- 📈 Shows total files, total storage, category/extension summaries, and scan timing.
- 🧬 Calculates file checksums on demand to identify content duplicates.
- ✅ The default duplicate workflow uses **MD5**; the lower-level scanner also supports SHA256.
- 📦 Reports duplicate counts and potentially wasted storage so cleanup is easier.
- 🏷️ Can extract version information and company/description metadata from supported binaries.

### 🖱️ Right-Click Context Menu

The exported HTML tree provides a focused right-click context menu on each folder or file row:

- 📂 **Open in Windows Explorer** for folders.
- 📄 **Open in Default App** for files, using the Windows default application.
- 📋 **Copy Path** from the same menu.
- 🧭 Uses the custom `scanme://` protocol and URL-encodes full Windows paths safely, including spaces, `!`, and Unicode characters.
- 🔒 The protocol handler validates the URL and only opens an existing local folder or file.

> 💡 This is a context menu inside the exported HTML page; it is not a replacement for the normal Windows Explorer right-click menu.

### 📋 Smart Copy

- 🪟 **Copy Path** always uses Windows `\` separators, even when the page or source path used `/`.
- 🌳 **Copy Full Tree Text** copies the complete embedded tree—including paths, sizes, counts, icons, and detected versions—regardless of which rows are currently expanded or collapsed.
- 📝 **Tree (TXT)** exports the same useful hierarchy as a clean UTF-8 plain-text tree for notes, tickets, or documentation.

### 🎨 Beautiful HTML Export

- 🌟 Creates a polished dark-themed HTML tree that opens directly in a modern browser.
- 🔽 Provides interactive dropdown-style expand/collapse controls for nested folders.
- 🔍 Includes live search with matching results and highlighted text.
- 🧩 Uses a consistent icon system for folders, executables, archives, code, documents, media, fonts, config, and database files.
- 📋 Includes Copy Path, Copy Full Tree Text, Expand All, and Collapse All controls.
- 🖱️ Adds the row-level context menu described above.
- 🧾 Includes scan timestamp, total file count, total size, and target folder in the page header.

### ⚡ Blazing Fast PowerShell + WPF Engine

- ⚙️ Uses a lightweight, native Windows stack: **Windows PowerShell 5.1** or **PowerShell 7+**, plus full .NET Framework 4.x (WPF). No external modules.
- 🪟 Provides a responsive modern dark interface with live progress and status feedback.
- 🧵 Keeps the core engine, GUI controller, helpers, configuration, and documentation modular.
- 🧰 Ships with JSON, CSV, HTML, and plain-text export options.
- 🧪 Includes focused tests for tree behavior, dropdowns, icons, copy actions, and the context menu.
- 🌐 Date and size fields are **culture-invariant and host-independent** — the same scan produces identical JSON on PowerShell 5.1 and 7+.

## 📋 System Requirements

| | Minimum | Recommended |
| :--- | :--- | :--- |
| **OS** | Windows 7 SP1\* | Windows 10 / 11 |
| **PowerShell** | Windows PowerShell 5.1 | 5.1 **or** PowerShell 7+ |
| **.NET Framework** | 4.8 (full — **not** Client Profile) | 4.8 |
| **Disk space** | ~50 MB | ~50 MB |
| **RAM** | 512 MB | 1 GB+ |

> ⚠️ **\* Windows 7 SP1 requires manual setup.**
> Windows 7 ships with **.NET Framework 3.5.1** and **PowerShell 2.0** — neither can run
> Scan Me!. Before first launch, install:
> 1. **.NET Framework 4.8** (full, from Microsoft)
> 2. **Windows Management Framework 5.1** (provides Windows PowerShell 5.1)
>
> **.NET Framework 4 Client Profile is not supported** — it excludes WPF, so the GUI cannot start.
> **PowerShell 7 is not supported on Windows 7** by Microsoft; Windows 7 users must use
> Windows PowerShell 5.1. `ScanMe.exe` invokes `powershell.exe` by design.

**What you do NOT need:** no PowerShell modules, no NuGet/PSGallery packages, no internet
connection, and no administrator rights (protocol registration is per-user `HKCU`).

## 🚀 Quick Start

### 1️⃣ Get the project

Download or copy the complete project folder. **Keep the folder structure intact.** `ScanMe.exe` is a Windows launcher and looks for the PowerShell/WPF files in the `src` folder; it is not a self-contained single-file bundle.

### 2️⃣ Launch the app

Choose any of these simple options:

- 🖱️ Double-click **`ScanMe.exe`** in the project root.
- 📦 Double-click **`run.bat`** for the classic launcher.
- ⚙️ Run `src\gui\MainWindow.ps1` from PowerShell if you are comfortable with a terminal.

### 3️⃣ Scan a folder

1. 📂 Click **Browse** and choose the folder you want to inspect.
2. 🧰 Select All Files, a preset, or enter custom extensions.
3. 🧬 Enable MD5 duplicate detection or binary metadata extraction if needed.
4. 🚀 Click **START SCAN** and watch the live progress/status area.
5. 💾 Export the result as JSON, CSV, interactive HTML, or plain text.

## 🖥️ First-Time Setup: Enable HTML Right-Click Actions

The HTML tree is fully viewable without setup. To enable its **Open in Explorer / Open in Default App** actions, register the per-user `scanme://` protocol **once** for the current Windows user:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\register_protocol.ps1"
```

Run that command from the project root in PowerShell. It does **not** require administrator rights. If you move the project to a different folder, run the registration script again so the absolute opener path is refreshed.

The first time a browser uses the protocol, Windows may ask whether to open PowerShell or the Scan Me! handler. That is a normal browser safety prompt. To remove the registration later, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\unregister_protocol.ps1"
```

## 🛠️ Troubleshooting

### 🖼️ The EXE icon still looks old

Windows Explorer caches executable icons. After rebuilding or replacing `ScanMe.exe`, refresh the Icon Cache from an elevated or normal Command Prompt/PowerShell window:

```powershell
ie4uinit.exe -show
```

If the old icon remains, restart **Windows Explorer** or sign out and back in. The cache is a Windows behavior, not a Scan Me! data problem.

### 🖱️ Right-click Open actions do nothing

- ✅ Run `tools\register_protocol.ps1` once again.
- 📁 Make sure the project has not been moved after registration.
- 🔎 Open the exported HTML file locally in a browser and right-click a tree row.
- 🔐 Expect the first browser use to show a security confirmation.
- 🧪 Run the built-in diagnostic from the project root:

```powershell
.\tools\diagnose_protocol.ps1 -TestPath "E:\Project\Scan Me!"
```

- 📝 The opener records details in `%TEMP%\scanme_opener.log`.

### 🚀 The app does not open

- 📁 Confirm `ScanMe.exe` is next to `src`, `assets`, and `config`—do not move only the EXE.
- ⚙️ Try `run.bat` or launch `src\gui\MainWindow.ps1` with Windows PowerShell.
- 🪟 Supported: Windows 7 SP1, 10, and 11. See [📋 System Requirements](#-system-requirements) for the Windows 7 prerequisites.
- 🔍 If you see "The type initializer for ... threw an exception", your machine likely has only the **.NET 4 Client Profile**. Install the full **.NET Framework 4.8**.
- 🔍 If PowerShell reports a version below 5.1 (common on Windows 7), install **Windows Management Framework 5.1**.

### 🧬 Duplicate detection is slower than a normal scan

Duplicate detection reads file contents to calculate MD5 checksums. This is expected for large files and large trees. For a fast inventory, leave **Check Duplicates (MD5)** disabled until you need it.

## 🗂️ Project Map

```text
Scan Me!/
├── src/
│   ├── engine/Scanner.ps1        # Recursive scanning and statistics
│   ├── gui/MainWindow.xaml       # Modern WPF interface
│   ├── gui/MainWindow.ps1        # GUI events and scan orchestration
│   └── utils/Helpers.ps1         # Hashing, metadata, and exports
├── config/default_config.json    # Version, presets, and defaults
├── docs/                          # Guides, schema, and release documents
├── tools/                         # Protocol registration and diagnostics
├── tests/                        # Feature-focused PowerShell tests
├── output/                        # Generated JSON/CSV/HTML/TXT exports
├── assets/app.ico                 # Canonical application icon
├── ScanMe.exe                    # Windows launcher
├── build_exe.ps1                 # EXE build script
└── run.bat                       # One-click source launcher
```

## 📤 Exports & Data Contract

| Export | Best for | Details |
|---|---|---|
| 🌳 HTML Tree | Sharing and browsing | Interactive tree, search, dropdowns, icons, copy actions, and context menu |
| 📝 TXT Tree | Notes and documentation | UTF-8 folder tree with sizes and duplicate tags |
| 🧾 JSON | Automation and integrations | Full scan statistics and file records following `docs/SCHEMA_SPEC.md` |
| 📊 CSV | Excel and spreadsheets | Flat, easy-to-filter file inventory |

The JSON output is intentionally structured for downstream applications and AI workflows. See [`docs/SCHEMA_SPEC.md`](docs/SCHEMA_SPEC.md) for the data contract.

## 📚 Documentation

- 📖 [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) — Step-by-step product usage
- 📘 [`docs/PRODUCT_SPEC_v1.0.md`](docs/PRODUCT_SPEC_v1.0.md) — Full feature list, user workflows, and known limitations
- 🏗️ [`docs/TECHNICAL_SPEC.md`](docs/TECHNICAL_SPEC.md) — Architecture, key components, build, and testing
- 🏛️ [`ARCHITECTURE.md`](ARCHITECTURE.md) — Layers, data flow, and design decisions
- 📄 [`docs/SCHEMA_SPEC.md`](docs/SCHEMA_SPEC.md) — JSON data contract for integrations
- 🧪 [`CHANGELOG.md`](CHANGELOG.md) — Version history
- 🗓️ [`docs/RELEASE_NOTES_v1.0.0.md`](docs/RELEASE_NOTES_v1.0.0.md) — GitHub Release summary
- 🚀 [`ROADMAP.md`](ROADMAP.md) — Released features, v1.1 plans, and long-term vision
- 🚀 [`docs/GITHUB_UPLOAD_GUIDE.md`](docs/GITHUB_UPLOAD_GUIDE.md) — Beginner's GitHub upload guide
- 🧩 [`docs/EXTENSIONS_GUIDE.md`](docs/EXTENSIONS_GUIDE.md) — Presets and custom extensions
- 🤝 [`docs/HANDOFF.md`](docs/HANDOFF.md) — Project handoff notes for contributors and AI agents

<div align="center">

### ✨ Scan once. Understand everything. 🚀

**Made for Windows • PowerShell + WPF • Local-first file intelligence**

</div>

---

## 📄 License

This project is licensed under the MIT License. See the [`LICENSE`](LICENSE) file for the full terms.

Copyright © 2026 DRKMTTR Studio (Tokenmee).
