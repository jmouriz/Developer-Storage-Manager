import Foundation

struct StorageLocation: Identifiable, Hashable, Sendable {
    let id: String
    let category: StorageCategory
    let name: String
    let detail: String?
    let path: String
    let byteCount: Int64
    let modifiedAt: Date?
    let comparisonGroup: String?
    let versionComponents: [Int]?
    var candidateReason: String?

    var modifiedSortDate: Date { modifiedAt ?? .distantPast }

    init(
        category: StorageCategory,
        name: String,
        detail: String? = nil,
        path: String,
        byteCount: Int64,
        modifiedAt: Date?,
        comparisonGroup: String? = nil,
        versionComponents: [Int]? = nil,
        candidateReason: String? = nil
    ) {
        self.id = path
        self.category = category
        self.name = name
        self.detail = detail
        self.path = path
        self.byteCount = byteCount
        self.modifiedAt = modifiedAt
        self.comparisonGroup = comparisonGroup
        self.versionComponents = versionComponents
        self.candidateReason = candidateReason
    }
}

enum StorageCategory: String, CaseIterable, Identifiable, Sendable {
    case simulatorRuntimes
    case simulatorDevices
    case simulatorCaches
    case deviceSupport
    case derivedData
    case archives
    case documentation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simulatorRuntimes: L10n.tr("category.runtimes.title")
        case .simulatorDevices: L10n.tr("category.simulators.title")
        case .simulatorCaches: L10n.tr("category.caches.title")
        case .deviceSupport: L10n.tr("category.symbols.title")
        case .derivedData: L10n.tr("category.derivedData.title")
        case .archives: L10n.tr("category.archives.title")
        case .documentation: L10n.tr("category.documentation.title")
        }
    }

    var subtitle: String {
        switch self {
        case .simulatorRuntimes: L10n.tr("category.runtimes.subtitle")
        case .simulatorDevices: L10n.tr("category.simulators.subtitle")
        case .simulatorCaches: L10n.tr("category.caches.subtitle")
        case .deviceSupport: L10n.tr("category.symbols.subtitle")
        case .derivedData: L10n.tr("category.derivedData.subtitle")
        case .archives: L10n.tr("category.archives.subtitle")
        case .documentation: L10n.tr("category.documentation.subtitle")
        }
    }

    var systemImage: String {
        switch self {
        case .simulatorRuntimes: "square.stack.3d.up"
        case .simulatorDevices: "iphone.gen3"
        case .simulatorCaches: "shippingbox"
        case .deviceSupport: "waveform.path.ecg.rectangle"
        case .derivedData: "hammer"
        case .archives: "archivebox"
        case .documentation: "books.vertical"
        }
    }
}

struct StorageSnapshot: Sendable {
    let locations: [StorageLocation]
    let scannedAt: Date
    let warnings: [String]
    var totalDiskBytes: Int64 = 0
    var availableDiskBytes: Int64 = 0

    static let empty = StorageSnapshot(locations: [], scannedAt: .now, warnings: [])

    var totalBytes: Int64 { locations.reduce(0) { $0 + $1.byteCount } }
    var candidateBytes: Int64 {
        locations.filter { $0.candidateReason != nil }.reduce(0) { $0 + $1.byteCount }
    }
    var usedDiskBytes: Int64 { max(0, totalDiskBytes - availableDiskBytes) }

    func locations(in category: StorageCategory) -> [StorageLocation] {
        locations.filter { $0.category == category }
            .sorted { $0.byteCount > $1.byteCount }
    }

    func bytes(in category: StorageCategory) -> Int64 {
        locations(in: category).reduce(0) { $0 + $1.byteCount }
    }
}

enum SidebarItem: Hashable, Identifiable {
    case summary
    case category(StorageCategory)

    var id: String {
        switch self {
        case .summary: "summary"
        case .category(let category): category.id
        }
    }
}
