# Contributing

Thank you for your interest in Xcode Storage Manager.

## Development setup

1. Install macOS 15 or later and Xcode with Swift 6.2 or later.
2. Clone the repository.
3. Run the tests:

   ```bash
   swift test
   ```

4. Launch the app:

   ```bash
   swift run XcodeStorageManager
   ```

## Pull requests

- Keep changes focused and explain the user-facing behavior.
- Add or update tests when changing scanning, recommendation, or cleanup logic.
- Never weaken path validation or remove confirmation from destructive actions.
- Verify `swift test` before submitting.
- Do not commit `.build`, application bundles, DMG files, or local Xcode state.

## Reporting bugs

Use the bug report template and include the macOS version, Xcode version, steps to reproduce, and relevant screenshots. Remove device identifiers or other sensitive information before posting logs.
