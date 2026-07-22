import Foundation
import Testing
@testable import XcodeStorageManager

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
        path: "/tmp/xcode-storage-manager-unsafe-target",
        byteCount: 0,
        modifiedAt: nil
    )

    #expect(throws: CleanupService.CleanupError.self) {
        try CleanupService().remove(unsafe)
    }
}
