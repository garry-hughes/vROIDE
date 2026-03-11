# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Quick Start guide, prerequisites, and usage examples in README
- Comment-based help and README for `tools/` scripts (`createNewAction.ps1`, `examples.ps1`, `testExamples.ps1`)

### Changed
- Simplified `ConvertFrom-VroActionJs` regex pipeline with a shared helper function
- Replaced string concatenation with array `+` `-join` in `ConvertTo-VroActionJs`, `ConvertTo-VroActionMd`, and `Export-VroActionFile`

### Fixed
- Added `ApiVersion` and `Creator` parameters; timestamp now uses UTC (`Extract hardcoded values`)
- Added function-name validation in `ConvertFrom-VroActionJs` to catch malformed input early
- Added `try/finally` blocks for temp-directory cleanup in four functions
- Added input validation (`[ValidateNotNullOrEmpty]`) to `Export-VroIde`, `Import-VroIde`, and `ConvertFrom-VroActionJs`

### Tests
- Upgraded test suite from Pester v4 to Pester v5 syntax
- Replaced placeholder test assertions with meaningful validations
- Removed legacy example `Planets` test files
- Added edge-case test fixtures for all six conversion functions
- Added unit tests covering all six conversion functions
- Fixed CI: Install-Pester step now checks version before reinstalling

## [0.0.2] - 2026-03-11

### Added
- GitHub Actions CI/CD pipeline: runs tests on pull requests; tags and publishes releases on merge
- `Compare-VroActionContents` function exported from module manifest

### Fixed
- Cross-platform newline handling in `ConvertFrom-VroActionJs`, `ConvertTo-VroActionJs`, `ConvertTo-VroActionMd`, and `Export-VroActionFile` (use `\r?\n` / `[^\r\n]` in regex patterns)
- `Import-VroIde`: now uses basename for FQN and filters to `.js` files only
- `Export-VroIde`: disposes `ZipArchive` to prevent file-locking on Windows
- Fixed typo in `Compare-VroActionContents` (`action-cont` → `action-content`)
- CI test reporter format changed to JUnit XML for better cross-platform compatibility
- Windows CI: use `WriteAllText` with UTF-8 NoBOM encoding to preserve LF line endings

### Removed
- Legacy Azure Pipelines configuration (`azure-pipelines.yml`) and test runner

## [0.0.1] - 2019-07-28

### Added
- Initial release of the `vROIDE` PowerShell module
- `Export-VroIde` and `Import-VroIde` master functions for round-trip VRO action editing
- `ConvertFrom-VroActionXml` / `ConvertTo-VroActionXml` for XML ↔ directory conversion
- `ConvertFrom-VroActionJs` / `ConvertTo-VroActionJs` for JS ↔ metadata conversion
- `Export-VroActionFile` helper for writing action files
- Module manifest (`vroide.psd1`) with metadata and function exports

[Unreleased]: https://github.com/garry-hughes/vROIDE/compare/v0.0.2...HEAD
[0.0.2]: https://github.com/garry-hughes/vROIDE/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/garry-hughes/vROIDE/releases/tag/v0.0.1