# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.4.4] - 2026-07-23

### Fixed

- Kept the overview spinner and scan phase anchored while variable-length item details update.

## [0.4.3] - 2026-07-23

### Added

- Navigation from every category-usage row in the overview to its corresponding detail section.
- Localized accessibility help for category row controls.

## [0.4.2] - 2026-07-23

### Changed

- Replaced the category bar chart with an alternating-row usage list.
- Aligned all category sizes in a fixed trailing column while preserving proportional bars.

## [0.4.1] - 2026-07-23

### Added

- Live scan details showing the current phase, category, and item.
- Explicit progress while checking Gradle activity, comparing installed versions, applying cleanup policies, and reading disk capacity.

## [0.4.0] - 2026-07-23

### Added

- Gradle cache, wrapper distribution, daemon, native component, and temporary-data analysis.
- Cleanup suggestions for Gradle data not modified in the last 90 days.
- Protection that disables Gradle cleanup while Gradle is running.

### Changed

- Cleanup confirmations now explain that Gradle may download or rebuild deleted data and that the next build may be slower.

## [0.3.0] - 2026-07-23

### Added

- Android Platforms, System Images, Build Tools, and Sources storage categories.
- Detection of system images currently used by installed Android Virtual Devices.
- Conservative review notices for older Platforms, Build Tools, and Sources.

### Changed

- Bulk cleanup only suggests older Android system images that are not used by an AVD.
- Sidebar categories are grouped by Xcode and Android.

## [0.2.0] - 2026-07-23

### Added

- Android Virtual Device discovery with API, architecture, size, and cleanup support.
- Cleanup recommendations for older Android emulator versions of the same device model.

### Changed

- Renamed the project and application to Developer Storage Manager.
- Generalized the overview and documentation for multiple development toolchains.

## [0.1.0] - 2026-07-22

### Added

- Native macOS storage overview for Xcode-managed data.
- Simulator, runtime, device-symbol, Derived Data, archive, cache, and documentation scanning.
- Version-aware cleanup recommendations.
- Individual and bulk cleanup with confirmation and automatic reanalysis.
- Finder integration, custom app icon, About window, and DMG installer workflow.
