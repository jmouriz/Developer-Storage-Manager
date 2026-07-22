import Foundation

struct CleanupService: Sendable {
    enum CleanupError: LocalizedError {
        case unsafePath(String)
        case runtimeIdentifierMissing(String)
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .unsafePath(let path): L10n.format("cleanup.unsafePath", path)
            case .runtimeIdentifierMissing(let name): L10n.format("cleanup.runtimeMissing", name)
            case .commandFailed(let message): message
            }
        }
    }

    func remove(_ location: StorageLocation) throws {
        switch location.category {
        case .simulatorDevices:
            try runSimctl(["delete", URL(fileURLWithPath: location.path).lastPathComponent])
        case .simulatorRuntimes:
            guard let identifier = runtimeIdentifier(at: URL(fileURLWithPath: location.path)) else {
                throw CleanupError.runtimeIdentifierMissing(location.name)
            }
            try runSimctl(["runtime", "delete", identifier])
        case .simulatorCaches, .deviceSupport, .derivedData, .archives, .documentation:
            try moveUserDataToTrash(at: URL(fileURLWithPath: location.path))
        }
    }

    private func moveUserDataToTrash(at url: URL) throws {
        let homeDeveloper = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer", isDirectory: true)
            .standardizedFileURL.path + "/"
        let target = url.standardizedFileURL.path
        guard target.hasPrefix(homeDeveloper), target != String(homeDeveloper.dropLast()) else {
            throw CleanupError.unsafePath(target)
        }
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    private func runtimeIdentifier(at volume: URL) -> String? {
        let runtimes = volume.appendingPathComponent(
            "Library/Developer/CoreSimulator/Profiles/Runtimes",
            isDirectory: true
        )
        guard let bundles = try? FileManager.default.contentsOfDirectory(at: runtimes, includingPropertiesForKeys: nil) else {
            return nil
        }
        for bundle in bundles where bundle.pathExtension == "simruntime" {
            let plist = bundle.appendingPathComponent("Contents/Info.plist")
            guard
                let data = try? Data(contentsOf: plist),
                let object = try? PropertyListSerialization.propertyList(from: data, format: nil),
                let values = object as? [String: Any],
                let identifier = values["CFBundleIdentifier"] as? String
            else { continue }
            return identifier
        }
        return nil
    }

    private func runSimctl(_ arguments: [String]) throws {
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl"] + arguments
        process.standardError = errorPipe
        process.standardOutput = Pipe()
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus != 0 else { return }
        let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let detail = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        throw CleanupError.commandFailed(detail?.isEmpty == false ? detail! : L10n.format("cleanup.simctlFailed", process.terminationStatus))
    }
}
