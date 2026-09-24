# 📜 Changelog - Scan Me!

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-08-24
### Added
- **Modern WPF GUI**: Built full dark-themed Fluent GUI with gradient headers, dynamic status indicators, and responsive controls.
- **Selective Scanning**: Added support for All Files (`*.*`), Category Presets (Installers, Code, Docs, Media), and custom extension inputs.
- **Optional Duplicate Detection**: Implemented MD5 checksum calculation and duplicate file grouping with wasted space metrics.
- **Optional Metadata Extractor**: Added EXE/MSI metadata parser for FileVersion, ProductVersion, CompanyName, and FileDescription.
- **Multi-Format Export**: Implemented UTF-8 compliant JSON (SkillTree standard) and CSV export.
- **Live Search & Filter**: Instant search box to filter files in the DataGrid by name, extension, category, or path.
- **Project Structure**: Organized files into modular layers (`src/engine/`, `src/gui/`, `src/utils/`, `config/`, `output/`, `docs/`).
- **AI Tooling & Rules**: Added `.clinerules`, `.cursorrules`, and `.vscode/` configurations (`tasks.json`, `launch.json`, `settings.json`).
- **Documentation Suite**: Added `README.md`, `ARCHITECTURE.md`, `ROADMAP.md`, `USER_GUIDE.md`, `SCHEMA_SPEC.md`, and `EXTENSIONS_GUIDE.md`.
- **One-Click Runner**: Added `run.bat` for launching the app directly on Windows.
