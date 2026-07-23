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

    let snapshot = StorageScanner(homeDirectory: temporaryHome).scan()
    let emulator = try #require(snapshot.locations(in: .androidEmulators).first)

    #expect(emulator.name == "Pixel 8a API 35")
    #expect(emulator.detail?.contains("Android API 35") == true)
    #expect(emulator.detail?.contains("arm64-v8a") == true)
    #expect(
        emulator.relatedPaths.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
            == [avdRoot.appendingPathComponent("Pixel_8a_API_35.ini").standardizedFileURL.path]
    )
}
