# 📜 Changelog - Scan Me!

All notable changes to this project will be documented in this file.

## [1.0.1] - 2026-09-26
### Fixed
- **Checksum hashing silently broken under Windows PowerShell 5.1**: `Get-FileChecksum` called the `Get-FileHash` cmdlet, which is only reachable through *module auto-loading* and therefore depends on `$env:PSModulePath`. Whenever Windows PowerShell 5.1 is launched from a PowerShell 7 session, the child inherits PS 7's `PSModulePath`, which does not contain the 5.1 module directories, so `Get-FileHash` raised `CommandNotFoundException`. The existing `catch` swallowed it, so **every** file was reported as `ERROR_READING_HASH`: duplicate detection always reported `0` duplicates, the `Hash` field was garbage, and the scan still exited `0` — a silent wrong-answer failure that is worse than a crash. `Get-FileChecksum` now uses in-box `System.Security.Cryptography` (`MD5`/`SHA256`), so it needs no module, satisfies the zero-dependency rule, and returns hashes byte-identical to `Get-FileHash` on every host (verified for MD5 + SHA256, including empty files, plus the missing-file → `""` and locked-file → `ERROR_READING_HASH` contracts).
- **Culture-invariant dates (cross-host JSON stability)**: `LastModified`, `Scan_Timestamp`, and metadata `CreationTime`/`LastWriteTime` used the culture-sensitive `DateTime.ToString("yyyy-MM-dd HH:mm:ss")`. PowerShell 7 inherits the OS locale, so on a `th-TH` system the `ThaiBuddhistCalendar` emitted year **2569** instead of 2026, while Windows PowerShell 5.1 forces `en-US` and emitted 2026. The same scan therefore produced different output depending on the host, violating `docs/SCHEMA_SPEC.md`. All four call sites now use the new `Format-ScanDateTime` helper, which pins `InvariantCulture`.
- **Integer `Total_Size_Bytes`**: `Measure-Object -Sum` returns a `Double`, so PowerShell 7's `ConvertTo-Json` emitted `"Total_Size_Bytes": 50746.0` while 5.1 emitted `50746`. The result is now cast to `[int64]` before serialization to match the schema's declared `integer` type.
- **Whole-valued floats still drifted across hosts** (found while writing the new cross-host test): PowerShell 7's `ConvertTo-Json` appends `.0` to *every* whole-valued floating point number (`0.0`, `5.0`) while 5.1 emits `0` and `5`, and casting to `[decimal]` does **not** help. This affected `Total_Size_MB`, per-file `Size_MB`, and `Scan_Duration_Sec` — so the previous fix was incomplete. A new `ConvertTo-StableNumber` helper returns an `[int]` for whole values (JSON has no int/float distinction, so this remains valid for a `number` field) and leaves genuinely fractional values such as `19.15` untouched. Verified on a real 54-file scan: output is now identical across hosts apart from the legitimately volatile `Scan_Timestamp` and `Scan_Duration_Sec`.
- **`cross_host_json_test.ps1` year assertion produced a false positive**: the test extracted the year with `String.IndexOf('-')`, but in PowerShell 7 a bare `-` argument is parsed as the unary minus operator and reaches the method as `$null`, so `IndexOf` returned `0`, the substring was empty, and `[int]''` became `0`. Every correctly formatted `2026` date was therefore reported as an out-of-range "Buddhist" year. The year is now extracted with a regex, which is host-independent. This false positive was masking the hashing defect above, so the suite was never green.

### Added
- **`Format-ScanDateTime` helper** in `src/utils/Helpers.ps1` — culture-invariant, Gregorian, host-independent date formatting.
- **`ConvertTo-StableNumber` helper** in `src/utils/Helpers.ps1` — host-stable number formatting for whole vs. fractional values.
- **`tests/cross_host_json_test.ps1`** — runs the engine under every available PowerShell host (`powershell.exe` and `pwsh.exe`), then asserts Gregorian years, integer byte counts, and byte-identical `Scan_Meta` / `Files[]` / `Category_Stats` / `Extension_Stats`. This automates the dual-host check that `.clinerules` rule #6 previously required by hand, and is what surfaced the whole-valued float defect above.
- **📋 System Requirements section** in `README.md` with a minimum/recommended matrix, Windows 7 SP1 prerequisites, and explicit Client Profile / PowerShell 7-on-Windows 7 exclusions.
- **AI agent rule #6 (Culture-Invariant Serialization)** in `.clinerules`, extended to cover the whole-valued float case and to require `tests\cross_host_json_test.ps1` to pass.
- **Troubleshooting entries** for the two most common launch failures: missing full .NET Framework (Client Profile present) and PowerShell older than 5.1.

### Documentation
- Documented **Windows 7 SP1** as a supported platform in `README.md`, `docs/RELEASE_NOTES_v1.0.0.md`, and `.clinerules` (previously Windows 10/11 only).
- Closed **ISSUE-001** in `docs/KNOWN_ISSUES.md`: verified `ScanMe.exe` is a legitimate 54 KB .NET Framework 4.x AnyCPU WinExe launcher (the recorded "5KB" size was outdated). Confirmed it hardcodes no PowerShell version and targets `powershell.exe` by design.
- **Corrected `docs/HANDOFF.md`**: it described the project as a "QR Code / Barcode Scanner", which was wrong — no camera, overlay, or barcode code exists in the repository. Rewrote the project description, Tech Stack, and current-state sections to match the actual folder scanner product, and removed the resolved "5KB launcher" concern in favour of the verified 54 KB WinExe plus Windows 7 prerequisites (.NET 4.8 full + WMF 5.1).
- **Added `docs/PRODUCT_SPEC_v1.0.md`**: retrospective product specification covering vision, design principles, the full feature list, user workflows, supported platforms, known limitations, and success criteria.
- **Added `docs/TECHNICAL_SPEC.md`**: architecture (scanner engine → GUI → exporters → protocol handler), tech stack, file structure, per-component detail, dependencies, build process, and the test suite.
- **Updated `ROADMAP.md`**: marked v1.0.0 as released (2026-09-26) with the v1.0.0 feature list, added a phased v1.1–v2.0 feature outlook (i18n, cloud sync, AI categorization, real-time monitoring, cross-platform), and documented a long-term vision.
- Linked the new specifications from the README documentation index.

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
