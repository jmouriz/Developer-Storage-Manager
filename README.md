# Xcode Storage Manager

A native macOS app to analyze, identify, and clean up Xcode simulators, device symbols, build data, archives, caches, and documentation.

Xcode Storage Manager explains where the space is being used, recommends older simulator and device-symbol versions as cleanup candidates, and always asks for confirmation before removing anything.

## Screenshots

### Overview

![Xcode Storage Manager overview](Screenshots/overview.png)

### Simulators

![Simulator storage and cleanup candidates](Screenshots/simulators.png)

### Device Symbols

![Device symbol storage and cleanup candidates](Screenshots/device-symbols.png)

## Features

- Disk usage overview with breakdowns by Xcode category.
- Simulator names and runtime versions instead of opaque UUIDs.
- Cleanup recommendations that keep the newest version for each device model.
- Individual cleanup actions and bulk cleanup for suggested candidates.
- Finder integration for every scanned item.
- Recoverable cleanup through the Trash for user-managed Xcode data.
- Official `simctl` operations for simulator devices and runtimes.
- Automatic reanalysis after cleanup.
- English, Spanish, Portuguese, and French localization with automatic system-language selection and English fallback.

## Requirements

- macOS 15 or later.
- Xcode with the Swift 6.2 toolchain or later.

## Run from source

```bash
swift run XcodeStorageManager
```

You can also open `Package.swift` directly in Xcode.

## Build the macOS app

```bash
./Scripts/build-app.sh
open ".build/Xcode Storage Manager.app"
```

The build script generates `AppIcon.icns` from `Assets/AppIcon.png`, creates the application bundle, and applies an ad hoc signature for local use.

## Build the DMG installer

```bash
./Scripts/build-dmg.sh
```

The installer is written to `.build/Xcode Storage Manager.dmg`. It includes a custom background, a shortcut to Applications, and a custom Finder icon for the DMG file.

## Tests

```bash
swift test
```

## Safety

Every cleanup operation requires confirmation. User-managed files are moved to the Trash, while simulator devices and runtimes are removed through CoreSimulator. Paths outside `~/Library/Developer` are rejected by the cleanup service.

Please report security concerns according to [SECURITY.md](SECURITY.md).

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## License

Xcode Storage Manager is available under the [MIT License](LICENSE).

Copyright © 2026 Juan Manuel Mouriz.
