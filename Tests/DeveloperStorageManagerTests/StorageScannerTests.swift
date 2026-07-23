import Foundation
import Testing
@testable import DeveloperStorageManager

@Test func snapshotGroupsAndTotalsLocations() {
    let locations = [
        StorageLocation(category: .derivedData, name: "A", path: "/A", byteCount: 100, modifiedAt: nil),
        StorageLocation(category: .derivedData, name: "B", path: "/B", byteCount: 250, modifiedAt: nil),
        StorageLocation(category: .archives, name: "C", path: "/C", byteCount: 50, modifiedAt: nil)
    ]
    let snapshot = StorageSnapshot(locations: locations, scannedAt: .now, warnings: [])

    #expect(snapshot.totalBytes == 400)
    #expect(snapshot.bytes(in: .derivedData) == 350)
    #expect(snapshot.locations(in: .derivedData).map(\.name) == ["B", "A"])
}

@Test func olderVersionsBecomeCandidatesWithinTheSameModel() {
    var locations = [
        StorageLocation(
            category: .simulatorDevices,
            name: "iPhone 16 Pro",
            path: "/18.4",
            byteCount: 100,
            modifiedAt: nil,
            comparisonGroup: "simulator:iPhone 16 Pro",
            versionComponents: [18, 4]
        ),
        StorageLocation(
            category: .simulatorDevices,
            name: "iPhone 16 Pro",
            path: "/18.5",
            byteCount: 100,
            modifiedAt: nil,
            comparisonGroup: "simulator:iPhone 16 Pro",
            versionComponents: [18, 5]
        ),
        StorageLocation(
            category: .deviceSupport,
            name: "iPhone14,7 26.5.2",
            path: "/26.5.2",
            byteCount: 100,
            modifiedAt: nil,
            comparisonGroup: "symbols:iPhone14,7",
            versionComponents: [26, 5, 2]
        ),
        StorageLocation(
            category: .deviceSupport,
            name: "iPhone14,7 26.5",
            path: "/26.5",
            byteCount: 100,
            modifiedAt: nil,
            comparisonGroup: "symbols:iPhone14,7",
            versionComponents: [26, 5]
        )
    ]

    StorageScanner().markOlderVersions(in: &locations)

    #expect(locations[0].candidateReason != nil)
    #expect(locations[1].candidateReason == nil)
    #expect(locations[2].candidateReason == nil)
    #expect(locations[3].candidateReason != nil)
}

@Test func cleanupRejectsPathsOutsideTheDeveloperDirectory() {
    let unsafe = StorageLocation(
        category: .derivedData,
        name: "No permitido",
        path: "/tmp/developer-storage-manager-unsafe-target",
        byteCount: 0,
        modifiedAt: nil
    )

    #expect(throws: CleanupService.CleanupError.self) {
        try CleanupService().remove(unsafe)
    }
}

@Test func androidVirtualDevicesAreDiscovered() throws {
    let temporaryHome = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let avdRoot = temporaryHome.appendingPathComponent(".android/avd", isDirectory: true)
    let avd = avdRoot.appendingPathComponent("Pixel_8a_API_35.avd", isDirectory: true)
    try FileManager.default.createDirectory(at: avd, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryHome) }

    try """
    avd.ini.displayname=Pixel 8a API 35
    abi.type=arm64-v8a
    hw.device.name=pixel_8a
    image.sysdir.1=system-images/android-35/google_apis/arm64-v8a/
    """.write(to: avd.appendingPathComponent("config.ini"), atomically: true, encoding: .utf8)
    try """
    path=\(avd.path)
    path.rel=.android/avd/Pixel_8a_API_35.avd
    """.write(
        to: avdRoot.appendingPathComponent("Pixel_8a_API_35.ini"),
        atomically: true,
        encoding: .utf8
    )
    try Data(repeating: 1, count: 4_096).write(to: avd.appendingPathComponent("userdata.img"))

    let snapshot = StorageScanner(
        homeDirectory: temporaryHome,
        androidSDKDirectory: temporaryHome.appendingPathComponent("AndroidSDK")
    ).scan()
    let emulator = try #require(snapshot.locations(in: .androidEmulators).first)

    #expect(emulator.name == "Pixel 8a API 35")
    #expect(emulator.detail?.contains("Android API 35") == true)
    #expect(emulator.detail?.contains("arm64-v8a") == true)
    #expect(
        emulator.relatedPaths.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
            == [avdRoot.appendingPathComponent("Pixel_8a_API_35.ini").standardizedFileURL.path]
    )
}

@Test func androidSDKVersionsUseConservativeRecommendations() throws {
    let temporaryHome = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sdk = temporaryHome.appendingPathComponent("Library/Android/sdk", isDirectory: true)
    let avdRoot = temporaryHome.appendingPathComponent(".android/avd", isDirectory: true)
    let avd = avdRoot.appendingPathComponent("Pixel_API_35.avd", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryHome) }

    let platform34 = sdk.appendingPathComponent("platforms/android-34", isDirectory: true)
    let platform35 = sdk.appendingPathComponent("platforms/android-35", isDirectory: true)
    let image34 = sdk.appendingPathComponent("system-images/android-34/google_apis/arm64-v8a", isDirectory: true)
    let image35 = sdk.appendingPathComponent("system-images/android-35/google_apis/arm64-v8a", isDirectory: true)
    for directory in [platform34, platform35, image34, image35, avd] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 32).write(to: directory.appendingPathComponent("payload"))
    }
    try "image.sysdir.1=system-images/android-35/google_apis/arm64-v8a/\n"
        .write(to: avd.appendingPathComponent("config.ini"), atomically: true, encoding: .utf8)
    try "path=\(avd.path)\n"
        .write(to: avdRoot.appendingPathComponent("Pixel_API_35.ini"), atomically: true, encoding: .utf8)

    let snapshot = StorageScanner(homeDirectory: temporaryHome, androidSDKDirectory: sdk).scan()
    let platforms = snapshot.locations(in: .androidPlatforms)
    let images = snapshot.locations(in: .androidSystemImages)
    let olderPlatform = try #require(platforms.first { $0.name == "android-34" })
    let olderImage = try #require(images.first { $0.name == "Android API 34" })
    let usedImage = try #require(images.first { $0.name == "Android API 35" })

    #expect(olderPlatform.candidateReason == nil)
    #expect(olderPlatform.advisoryReason != nil)
    #expect(olderImage.candidateReason != nil)
    #expect(usedImage.candidateReason == nil)
    #expect(usedImage.advisoryReason == L10n.tr("android.systemImage.inUse"))
}

@Test func gradleItemsUnusedForNinetyDaysBecomeCandidates() throws {
    let temporaryHome = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let gradle = temporaryHome.appendingPathComponent(".gradle", isDirectory: true)
    let oldCache = gradle.appendingPathComponent("caches/8.0", isDirectory: true)
    let recentCache = gradle.appendingPathComponent("caches/9.0", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryHome) }

    let referenceDate = Date(timeIntervalSince1970: 1_774_224_000)
    try createGradleFixture(
        at: oldCache,
        modifiedAt: referenceDate.addingTimeInterval(-100 * 86_400)
    )
    try createGradleFixture(
        at: recentCache,
        modifiedAt: referenceDate.addingTimeInterval(-10 * 86_400)
    )

    let snapshot = StorageScanner(
        homeDirectory: temporaryHome,
        androidSDKDirectory: temporaryHome.appendingPathComponent("AndroidSDK"),
        gradleDirectory: gradle,
        gradleIsRunning: false,
        referenceDate: referenceDate
    ).scan()
    let oldPath = oldCache.resolvingSymlinksInPath().path
    let recentPath = recentCache.resolvingSymlinksInPath().path
    let oldItem = try #require(snapshot.locations(in: .gradleCache).first {
        URL(fileURLWithPath: $0.path).resolvingSymlinksInPath().path == oldPath
    })
    let recentItem = try #require(snapshot.locations(in: .gradleCache).first {
        URL(fileURLWithPath: $0.path).resolvingSymlinksInPath().path == recentPath
    })

    #expect(oldItem.candidateReason != nil)
    #expect(oldItem.isDeletionBlocked == false)
    #expect(recentItem.candidateReason == nil)
}

@Test func gradleCleanupIsBlockedWhileGradleIsRunning() throws {
    let temporaryHome = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let gradle = temporaryHome.appendingPathComponent(".gradle", isDirectory: true)
    let cache = gradle.appendingPathComponent("caches/8.0", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryHome) }

    let referenceDate = Date(timeIntervalSince1970: 1_774_224_000)
    try createGradleFixture(
        at: cache,
        modifiedAt: referenceDate.addingTimeInterval(-100 * 86_400)
    )

    let snapshot = StorageScanner(
        homeDirectory: temporaryHome,
        androidSDKDirectory: temporaryHome.appendingPathComponent("AndroidSDK"),
        gradleDirectory: gradle,
        gradleIsRunning: true,
        referenceDate: referenceDate
    ).scan()
    let item = try #require(snapshot.locations(in: .gradleCache).first)

    #expect(item.candidateReason == nil)
    #expect(item.advisoryReason == L10n.tr("gradle.running"))
    #expect(item.isDeletionBlocked)
}

@Test func scannerReportsDetailedProgressThroughCandidateAnalysis() throws {
    let temporaryHome = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let gradle = temporaryHome.appendingPathComponent(".gradle", isDirectory: true)
    let cache = gradle.appendingPathComponent("caches/8.0", isDirectory: true)
    let recorder = ScanProgressRecorder()
    defer { try? FileManager.default.removeItem(at: temporaryHome) }

    try createGradleFixture(at: cache, modifiedAt: Date(timeIntervalSince1970: 1_700_000_000))
    _ = StorageScanner(
        homeDirectory: temporaryHome,
        androidSDKDirectory: temporaryHome.appendingPathComponent("AndroidSDK"),
        gradleDirectory: gradle,
        gradleIsRunning: false,
        progressHandler: { recorder.append($0) }
    ).scan()

    let progress = recorder.values
    #expect(progress.contains {
        $0.phase == L10n.tr("scan.phase.measuring")
            && $0.detail?.contains(cache.lastPathComponent) == true
    })
    #expect(progress.contains { $0.phase == L10n.tr("scan.phase.activity") })
    #expect(progress.contains { $0.phase == L10n.tr("scan.phase.candidates") })
    #expect(progress.last?.phase == L10n.tr("scan.phase.disk"))
}

private func createGradleFixture(at directory: URL, modifiedAt: Date) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    let payload = directory.appendingPathComponent("payload.bin")
    try Data(repeating: 1, count: 4_096).write(to: payload)
    let attributes: [FileAttributeKey: Any] = [.modificationDate: modifiedAt]
    try fileManager.setAttributes(attributes, ofItemAtPath: payload.path)
    try fileManager.setAttributes(attributes, ofItemAtPath: directory.path)
}

private final class ScanProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [StorageScanProgress] = []

    var values: [StorageScanProgress] {
        lock.withLock { storage }
    }

    func append(_ progress: StorageScanProgress) {
        lock.withLock { storage.append(progress) }
    }
}
