import Foundation

struct StorageScanner: Sendable {
    struct Root: Sendable {
        let category: StorageCategory
        let path: String
    }

    private let roots: [Root]
    private let homePath: String

    private var fileManager: FileManager { FileManager.default }

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        let home = homeDirectory.path
        homePath = home
        roots = [
            Root(category: .simulatorRuntimes, path: "/Library/Developer/CoreSimulator/Volumes"),
            Root(category: .simulatorDevices, path: "\(home)/Library/Developer/CoreSimulator/Devices"),
            Root(category: .simulatorCaches, path: "\(home)/Library/Developer/CoreSimulator/Caches"),
            Root(category: .deviceSupport, path: "\(home)/Library/Developer/Xcode/iOS DeviceSupport"),
            Root(category: .deviceSupport, path: "\(home)/Library/Developer/Xcode/watchOS DeviceSupport"),
            Root(category: .deviceSupport, path: "\(home)/Library/Developer/Xcode/tvOS DeviceSupport"),
            Root(category: .deviceSupport, path: "\(home)/Library/Developer/Xcode/macOS DeviceSupport"),
            Root(category: .derivedData, path: "\(home)/Library/Developer/Xcode/DerivedData"),
            Root(category: .archives, path: "\(home)/Library/Developer/Xcode/Archives"),
            Root(category: .documentation, path: "\(home)/Library/Developer/Xcode/DocumentationCache"),
            Root(category: .documentation, path: "\(home)/Library/Developer/Xcode/DocumentationIndex")
        ]
    }

    func scan() -> StorageSnapshot {
        var locations: [StorageLocation] = []
        var warnings: [String] = []

        for root in roots {
            let url = URL(fileURLWithPath: root.path)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            do {
                let children = try fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )

                for child in children {
                    let values = try? child.resourceValues(forKeys: [.contentModificationDateKey])
                    let device = root.category == .simulatorDevices ? simulatorDescription(at: child) : nil
                    let symbols = root.category == .deviceSupport ? deviceSupportDescription(for: child.lastPathComponent) : nil
                    locations.append(StorageLocation(
                        category: root.category,
                        name: device?.name ?? child.lastPathComponent,
                        detail: device?.detail,
                        path: child.path,
                        byteCount: allocatedSize(of: child),
                        modifiedAt: values?.contentModificationDate,
                        comparisonGroup: device?.group ?? symbols?.group,
                        versionComponents: device?.version ?? symbols?.version
                    ))
                }
            } catch {
                warnings.append(L10n.format("scanner.readError", root.path, error.localizedDescription))
            }
        }

        markOlderVersions(in: &locations)
        let disk = diskCapacity()
        return StorageSnapshot(
            locations: locations,
            scannedAt: .now,
            warnings: warnings,
            totalDiskBytes: disk.total,
            availableDiskBytes: disk.available
        )
    }

    private func diskCapacity() -> (total: Int64, available: Int64) {
        guard let attributes = try? fileManager.attributesOfFileSystem(forPath: homePath) else { return (0, 0) }
        let total = (attributes[.systemSize] as? NSNumber)?.int64Value ?? 0
        let available = (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        return (total, available)
    }

    private func simulatorDescription(at directory: URL) -> (name: String, detail: String, group: String, version: [Int])? {
        let plistURL = directory.appendingPathComponent("device.plist")
        guard
            let data = try? Data(contentsOf: plistURL),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let values = plist as? [String: Any],
            let name = values["name"] as? String
        else { return nil }

        let runtime = (values["runtime"] as? String).map(readableRuntime) ?? L10n.tr("scanner.unknownRuntime")
        let version = versionNumbers(in: runtime)
        let udid = (values["UDID"] as? String) ?? directory.lastPathComponent
        let status = (values["isDeleted"] as? Bool) == true ? " · \(L10n.tr("scanner.deleted"))" : ""
        return (name, "\(runtime) · \(udid)\(status)", "simulator:\(name)", version)
    }

    private func deviceSupportDescription(for name: String) -> (group: String, version: [Int])? {
        let parts = name.split(separator: " ").map(String.init)
        guard let versionIndex = parts.firstIndex(where: { !$0.isEmpty && $0.first?.isNumber == true && $0.contains(".") }) else {
            return nil
        }
        let model = parts[..<versionIndex].joined(separator: " ")
        guard !model.isEmpty else { return nil }
        let version = versionNumbers(in: parts[versionIndex])
        guard !version.isEmpty else { return nil }
        return ("symbols:\(model)", version)
    }

    private func versionNumbers(in text: String) -> [Int] {
        text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    }

    func markOlderVersions(in locations: inout [StorageLocation]) {
        let grouped = Dictionary(grouping: locations.indices.compactMap { index -> (String, Int)? in
            guard let group = locations[index].comparisonGroup, locations[index].versionComponents != nil else { return nil }
            return (group, index)
        }, by: { $0.0 })

        for entries in grouped.values where entries.count > 1 {
            let indices = entries.map(\.1)
            guard let newest = indices.compactMap({ locations[$0].versionComponents }).max(by: versionIsOlder) else { continue }
            for index in indices {
                guard let version = locations[index].versionComponents, versionIsOlder(version, newest) else { continue }
                let latest = newest.map(String.init).joined(separator: ".")
                locations[index].candidateReason = L10n.format("candidate.newerVersion", latest)
            }
        }
    }

    private func versionIsOlder(_ lhs: [Int], _ rhs: [Int]) -> Bool {
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    private func readableRuntime(_ identifier: String) -> String {
        let prefix = "com.apple.CoreSimulator.SimRuntime."
        let raw = identifier.hasPrefix(prefix) ? String(identifier.dropFirst(prefix.count)) : identifier
        let parts = raw.split(separator: "-").map(String.init)
        guard parts.count > 1 else { return raw }
        return "\(parts[0]) \(parts.dropFirst().joined(separator: "."))"
    }

    private func allocatedSize(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys), values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }
}
