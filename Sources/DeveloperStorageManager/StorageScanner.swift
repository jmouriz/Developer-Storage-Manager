import Foundation

struct StorageScanner: Sendable {
    struct Root: Sendable {
        let category: StorageCategory
        let path: String
    }

    private let roots: [Root]
    private let homePath: String
    private let androidSDKDirectory: URL?
    private let gradleDirectory: URL
    private let gradleRunningOverride: Bool?
    private let referenceDate: Date
    private let gradleStaleDays: Int

    private var fileManager: FileManager { FileManager.default }

    init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        androidSDKDirectory: URL? = nil,
        gradleDirectory: URL? = nil,
        gradleIsRunning: Bool? = nil,
        referenceDate: Date = .now,
        gradleStaleDays: Int = 90
    ) {
        let home = homeDirectory.path
        homePath = home
        self.androidSDKDirectory = androidSDKDirectory ?? Self.findAndroidSDK(homeDirectory: homeDirectory)
        self.gradleDirectory = gradleDirectory
            ?? homeDirectory.appendingPathComponent(".gradle", isDirectory: true)
        gradleRunningOverride = gradleIsRunning
        self.referenceDate = referenceDate
        self.gradleStaleDays = gradleStaleDays
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

        scanAndroidEmulators(into: &locations, warnings: &warnings)
        scanAndroidSDK(into: &locations, warnings: &warnings)
        scanGradleCache(into: &locations, warnings: &warnings)
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

    private func scanGradleCache(
        into locations: inout [StorageLocation],
        warnings: inout [String]
    ) {
        guard fileManager.fileExists(atPath: gradleDirectory.path) else { return }
        let isRunning = gradleRunningOverride ?? isGradleRunning()
        let cutoff = Calendar.current.date(byAdding: .day, value: -gradleStaleDays, to: referenceDate)
            ?? referenceDate

        let groups: [(root: URL, kind: String, wholeRoot: Bool)] = [
            (gradleDirectory.appendingPathComponent("caches", isDirectory: true), L10n.tr("gradle.kind.cache"), false),
            (gradleDirectory.appendingPathComponent("wrapper/dists", isDirectory: true), L10n.tr("gradle.kind.distribution"), false),
            (gradleDirectory.appendingPathComponent("daemon", isDirectory: true), L10n.tr("gradle.kind.daemon"), false),
            (gradleDirectory.appendingPathComponent("native", isDirectory: true), L10n.tr("gradle.kind.native"), true),
            (gradleDirectory.appendingPathComponent(".tmp", isDirectory: true), L10n.tr("gradle.kind.temporary"), true)
        ]

        for group in groups where fileManager.fileExists(atPath: group.root.path) {
            do {
                let units = group.wholeRoot ? [group.root] : try directoryChildren(of: group.root)
                for unit in units {
                    let stats = gradleStats(of: unit, cutoff: cutoff)
                    let modified = stats.modifiedAt
                    let name = group.wholeRoot
                        ? group.kind
                        : "\(group.kind) · \(unit.lastPathComponent)"
                    locations.append(StorageLocation(
                        category: .gradleCache,
                        name: name,
                        detail: L10n.format("gradle.detail", gradleStaleDays),
                        path: unit.path,
                        byteCount: stats.size,
                        modifiedAt: modified,
                        recommendationPolicy: isRunning ? .none : .automatic,
                        isDeletionBlocked: isRunning,
                        candidateReason: !isRunning && stats.isStale
                            ? L10n.format("gradle.stale", gradleStaleDays)
                            : nil,
                        advisoryReason: isRunning ? L10n.tr("gradle.running") : nil
                    ))
                }
            } catch {
                warnings.append(L10n.format("scanner.readError", group.root.path, error.localizedDescription))
            }
        }
    }

    private func gradleStats(of url: URL, cutoff: Date) -> (size: Int64, modifiedAt: Date?, isStale: Bool) {
        let diskSize = diskUsage(of: url)
        let latestModification = latestContentModification(in: url)
        let fallback = diskSize == nil || latestModification == nil ? directoryStats(of: url) : nil
        let size = diskSize ?? fallback?.size ?? 0
        let modified = latestModification ?? fallback?.modifiedAt
        let isStale = modified.map { $0 < cutoff } ?? false
        return (size, modified, isStale)
    }

    private func diskUsage(of url: URL) -> Int64? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", url.path]
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            guard
                let line = String(data: data, encoding: .utf8)?.split(whereSeparator: \.isNewline).first,
                let kilobytes = Int64(line.split(whereSeparator: \.isWhitespace).first ?? "")
            else { return nil }
            return kilobytes * 1_024
        } catch {
            return nil
        }
    }

    private func latestContentModification(in url: URL) -> Date? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        process.arguments = [
            url.path, "-type", "f", "-exec", "/usr/bin/stat", "-f", "%m", "{}", "+"
        ]
        process.standardOutput = output
        process.standardError = Pipe()
        process.environment = ["LC_ALL": "C", "PATH": "/usr/bin:/bin"]
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let timestamps = String(data: data, encoding: .utf8)?
                .split(whereSeparator: \.isNewline)
                .compactMap { TimeInterval($0) }
            guard let latest = timestamps?.max() else { return nil }
            return Date(timeIntervalSince1970: latest)
        } catch {
            return nil
        }
    }

    private func isGradleRunning() -> Bool {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-ax", "-o", "command="]
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return true }
            let commands = String(data: data, encoding: .utf8)?.lowercased() ?? ""
            return commands.contains("gradledaemon")
                || commands.contains("org.gradle.launcher.daemon")
                || commands.contains("gradle daemon")
        } catch {
            return true
        }
    }

    private static func findAndroidSDK(homeDirectory: URL) -> URL? {
        let environment = ProcessInfo.processInfo.environment
        let candidates = [
            environment["ANDROID_SDK_ROOT"],
            environment["ANDROID_HOME"],
            homeDirectory.appendingPathComponent("Library/Android/sdk", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Android/Sdk", isDirectory: true).path
        ].compactMap { $0 }.map { URL(fileURLWithPath: $0, isDirectory: true) }
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func scanAndroidEmulators(
        into locations: inout [StorageLocation],
        warnings: inout [String]
    ) {
        let avdRoot = URL(fileURLWithPath: homePath)
            .appendingPathComponent(".android/avd", isDirectory: true)
        guard fileManager.fileExists(atPath: avdRoot.path) else { return }

        do {
            let descriptors = try fileManager.contentsOfDirectory(
                at: avdRoot,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension == "ini" }

            for descriptor in descriptors {
                let descriptorValues = iniValues(at: descriptor)
                let fallbackName = descriptor.deletingPathExtension().lastPathComponent
                let avdURL: URL
                if let configuredPath = descriptorValues["path"], !configuredPath.isEmpty {
                    avdURL = URL(fileURLWithPath: configuredPath)
                } else if let relativePath = descriptorValues["path.rel"], !relativePath.isEmpty {
                    avdURL = URL(fileURLWithPath: homePath).appendingPathComponent(relativePath)
                } else {
                    avdURL = avdRoot.appendingPathComponent("\(fallbackName).avd", isDirectory: true)
                }
                guard fileManager.fileExists(atPath: avdURL.path) else { continue }

                let config = iniValues(at: avdURL.appendingPathComponent("config.ini"))
                let displayName = config["avd.ini.displayname"] ?? fallbackName.replacingOccurrences(of: "_", with: " ")
                let api = androidAPI(from: config)
                let version = api.map { [$0] }
                let architecture = config["abi.type"] ?? androidArchitecture(from: config["image.sysdir.1"])
                let device = config["hw.device.name"] ?? config["hw.device.manufacturer"]
                let detailParts = [
                    api.map { "Android API \($0)" },
                    architecture,
                    device
                ].compactMap { $0 }.filter { !$0.isEmpty }
                let modified = try? avdURL.resourceValues(forKeys: [.contentModificationDateKey])

                locations.append(StorageLocation(
                    category: .androidEmulators,
                    name: displayName,
                    detail: detailParts.joined(separator: " · "),
                    path: avdURL.path,
                    byteCount: allocatedSize(of: avdURL),
                    modifiedAt: modified?.contentModificationDate,
                    comparisonGroup: device.map { "android:\($0)" },
                    versionComponents: version,
                    relatedPaths: [descriptor.path]
                ))
            }
        } catch {
            warnings.append(L10n.format("scanner.readError", avdRoot.path, error.localizedDescription))
        }
    }

    private func scanAndroidSDK(
        into locations: inout [StorageLocation],
        warnings: inout [String]
    ) {
        guard let sdk = androidSDKDirectory else { return }
        let usedSystemImages = androidSystemImagesUsedByAVDs()

        scanAndroidVersionDirectories(
            root: sdk.appendingPathComponent("platforms", isDirectory: true),
            category: .androidPlatforms,
            group: "android-platforms",
            recommendationPolicy: .reviewOnly,
            detail: { name in "Android API \(self.apiNumber(in: name) ?? 0)" },
            into: &locations,
            warnings: &warnings
        )
        scanAndroidVersionDirectories(
            root: sdk.appendingPathComponent("build-tools", isDirectory: true),
            category: .androidBuildTools,
            group: "android-build-tools",
            recommendationPolicy: .reviewOnly,
            detail: { version in L10n.format("android.buildTools.detail", version) },
            into: &locations,
            warnings: &warnings
        )
        scanAndroidVersionDirectories(
            root: sdk.appendingPathComponent("sources", isDirectory: true),
            category: .androidSources,
            group: "android-sources",
            recommendationPolicy: .reviewOnly,
            detail: { name in "Android API \(self.apiNumber(in: name) ?? 0)" },
            into: &locations,
            warnings: &warnings
        )

        let root = sdk.appendingPathComponent("system-images", isDirectory: true)
        guard fileManager.fileExists(atPath: root.path) else { return }
        do {
            let apis = try directoryChildren(of: root)
            for apiDirectory in apis {
                for tagDirectory in try directoryChildren(of: apiDirectory) {
                    for architectureDirectory in try directoryChildren(of: tagDirectory) {
                        let api = apiNumber(in: apiDirectory.lastPathComponent)
                        guard let api else { continue }
                        let path = architectureDirectory.standardizedFileURL.path
                        let isUsed = usedSystemImages.contains(path)
                        let tag = tagDirectory.lastPathComponent.replacingOccurrences(of: "_", with: " ")
                        let architecture = architectureDirectory.lastPathComponent
                        let values = try? architectureDirectory.resourceValues(forKeys: [.contentModificationDateKey])
                        locations.append(StorageLocation(
                            category: .androidSystemImages,
                            name: "Android API \(api)",
                            detail: "\(tag) · \(architecture)",
                            path: architectureDirectory.path,
                            byteCount: allocatedSize(of: architectureDirectory),
                            modifiedAt: values?.contentModificationDate,
                            comparisonGroup: "android-system-image:\(tagDirectory.lastPathComponent):\(architecture)",
                            versionComponents: [api],
                            recommendationPolicy: isUsed ? .none : .automatic,
                            advisoryReason: isUsed ? L10n.tr("android.systemImage.inUse") : nil
                        ))
                    }
                }
            }
        } catch {
            warnings.append(L10n.format("scanner.readError", root.path, error.localizedDescription))
        }
    }

    private func scanAndroidVersionDirectories(
        root: URL,
        category: StorageCategory,
        group: String,
        recommendationPolicy: RecommendationPolicy,
        detail: (String) -> String,
        into locations: inout [StorageLocation],
        warnings: inout [String]
    ) {
        guard fileManager.fileExists(atPath: root.path) else { return }
        do {
            for directory in try directoryChildren(of: root) {
                let name = directory.lastPathComponent
                let version = versionNumbers(in: name)
                guard !version.isEmpty else { continue }
                let values = try? directory.resourceValues(forKeys: [.contentModificationDateKey])
                locations.append(StorageLocation(
                    category: category,
                    name: name,
                    detail: detail(name),
                    path: directory.path,
                    byteCount: allocatedSize(of: directory),
                    modifiedAt: values?.contentModificationDate,
                    comparisonGroup: group,
                    versionComponents: version,
                    recommendationPolicy: recommendationPolicy
                ))
            }
        } catch {
            warnings.append(L10n.format("scanner.readError", root.path, error.localizedDescription))
        }
    }

    private func directoryChildren(of root: URL) throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }

    private func androidSystemImagesUsedByAVDs() -> Set<String> {
        guard let sdk = androidSDKDirectory else { return [] }
        let avdRoot = URL(fileURLWithPath: homePath).appendingPathComponent(".android/avd", isDirectory: true)
        guard let descriptors = try? fileManager.contentsOfDirectory(
            at: avdRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter({ $0.pathExtension == "ini" }) else { return [] }

        return Set(descriptors.compactMap { descriptor -> String? in
            let descriptorValues = iniValues(at: descriptor)
            let fallbackName = descriptor.deletingPathExtension().lastPathComponent
            let avdURL = descriptorValues["path"].map(URL.init(fileURLWithPath:))
                ?? avdRoot.appendingPathComponent("\(fallbackName).avd", isDirectory: true)
            guard let imagePath = iniValues(at: avdURL.appendingPathComponent("config.ini"))["image.sysdir.1"] else {
                return nil
            }
            let url = imagePath.hasPrefix("/")
                ? URL(fileURLWithPath: imagePath)
                : sdk.appendingPathComponent(imagePath)
            return url.standardizedFileURL.path
        })
    }

    private func apiNumber(in text: String) -> Int? {
        guard let range = text.range(of: #"android-(\d+)"#, options: .regularExpression) else { return nil }
        return Int(text[range].dropFirst("android-".count))
    }

    private func iniValues(at url: URL) -> [String: String] {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        return contents.split(whereSeparator: \.isNewline).reduce(into: [:]) { result, line in
            let text = line.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty, !text.hasPrefix("#"), let separator = text.firstIndex(of: "=") else { return }
            let key = text[..<separator].trimmingCharacters(in: .whitespaces)
            let value = text[text.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            result[key] = value
        }
    }

    private func androidAPI(from config: [String: String]) -> Int? {
        let candidates = [config["image.sysdir.1"], config["target"]].compactMap { $0 }
        for candidate in candidates {
            if let range = candidate.range(of: #"android-(\d+)"#, options: .regularExpression) {
                return Int(candidate[range].dropFirst("android-".count))
            }
        }
        return nil
    }

    private func androidArchitecture(from imagePath: String?) -> String? {
        guard let imagePath else { return nil }
        return imagePath.split(separator: "/").last.map(String.init)
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
                switch locations[index].recommendationPolicy {
                case .automatic:
                    locations[index].candidateReason = L10n.format("candidate.newerVersion", latest)
                case .reviewOnly:
                    locations[index].advisoryReason = L10n.format("candidate.reviewNewerVersion", latest)
                case .none:
                    break
                }
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
        directoryStats(of: url).size
    }

    private func directoryStats(of url: URL) -> (size: Int64, modifiedAt: Date?) {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
            .contentModificationDateKey
        ]
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return (0, nil) }

        var total: Int64 = 0
        var mostRecent = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys) else { continue }
            if values.isRegularFile == true {
                total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            }
            if let date = values.contentModificationDate, mostRecent == nil || date > mostRecent! {
                mostRecent = date
            }
        }
        return (total, mostRecent)
    }
}
