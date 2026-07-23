import AppKit
import Charts
import SwiftUI

struct ContentView: View {
    @State private var model = StorageViewModel()
    @State private var selection: SidebarItem? = .summary

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label(L10n.tr("overview"), systemImage: "chart.pie")
                    .tag(SidebarItem.summary)

                Section("Xcode") {
                    ForEach(StorageCategory.xcodeCategories) { category in
                        sidebarLabel(for: category)
                            .tag(SidebarItem.category(category))
                    }
                }

                Section("Android") {
                    ForEach(StorageCategory.androidCategories) { category in
                        sidebarLabel(for: category)
                            .tag(SidebarItem.category(category))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 330, max: 400)
            .navigationTitle("Developer Storage")
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("analyzed.space"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.snapshot.totalBytes, format: .byteCount(style: .file))
                        .font(.title2.bold())
                    Divider()
                        .padding(.vertical, 6)
                    Text(L10n.tr("cleanup.candidates"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.snapshot.candidateBytes, format: .byteCount(style: .file))
                        .font(.title2.bold())
                        .foregroundStyle(model.snapshot.candidateBytes > 0 ? .orange : .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.bar)
            }
        } detail: {
            switch selection {
            case .summary:
                SummaryView(model: model)
            case .category(let category):
                CategoryView(category: category, model: model)
            case nil:
                ContentUnavailableView(L10n.tr("select.category"), systemImage: "externaldrive")
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await model.scan() }
                } label: {
                    Label(
                        model.isCleaning ? L10n.tr("action.cleaning") : (model.isScanning ? L10n.tr("action.scanning") : L10n.tr("action.scan")),
                        systemImage: model.isCleaning ? "trash" : "arrow.clockwise"
                    )
                }
                .disabled(model.isScanning || model.isCleaning)
            }
        }
        .task { await model.scan() }
        .alert(L10n.tr("cleanup.failed.title"), isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.clearError() } }
        )) {
            Button(L10n.tr("action.ok")) { model.clearError() }
        } message: {
            Text(model.errorMessage ?? L10n.tr("error.unknown"))
        }
        .alert(L10n.tr("cleanup.completed.title"), isPresented: Binding(
            get: { model.cleanupSuccessMessage != nil },
            set: { if !$0 { model.clearCleanupSuccess() } }
        )) {
            Button(L10n.tr("action.ok")) { model.clearCleanupSuccess() }
        } message: {
            Text(model.cleanupSuccessMessage ?? "")
        }
    }

    private func sidebarLabel(for category: StorageCategory) -> some View {
        Label {
            HStack {
                Text(category.title)
                Spacer()
                Text(model.snapshot.bytes(in: category), format: .byteCount(style: .file))
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: category.systemImage)
        }
    }
}

private struct SummaryView: View {
    let model: StorageViewModel
    @State private var confirmsCandidateCleanup = false

    private var snapshot: StorageSnapshot { model.snapshot }
    private var categories: [StorageCategory] {
        StorageCategory.allCases.filter { snapshot.bytes(in: $0) > 0 }
    }
    private var otherUsedBytes: Int64 {
        max(0, snapshot.usedDiskBytes - snapshot.totalBytes)
    }
    private var candidates: [StorageLocation] {
        snapshot.locations.filter { $0.candidateReason != nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.tr("overview")).font(.largeTitle.bold())
                    Text(L10n.tr("overview.description"))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 18) {
                    diskChart
                    VStack(spacing: 12) {
                        MetricCard(title: L10n.tr("metric.capacity"), value: snapshot.totalDiskBytes, icon: "internaldrive")
                        MetricCard(title: L10n.tr("metric.available"), value: snapshot.availableDiskBytes, icon: "checkmark.circle")
                        MetricCard(title: L10n.tr("metric.developerAnalyzed"), value: snapshot.totalBytes, icon: "hammer")
                        MetricCard(
                            title: L10n.tr("metric.suggestedCandidates"),
                            value: snapshot.candidateBytes,
                            icon: "sparkles",
                            buttonTitle: L10n.tr("action.cleanAll"),
                            isButtonDisabled: candidates.isEmpty || model.isScanning || model.isCleaning,
                            buttonAction: { confirmsCandidateCleanup = true }
                        )
                    }
                }

                GroupBox(L10n.tr("chart.category.title")) {
                    CategoryUsageList(categories: categories, snapshot: snapshot)
                        .padding(.top, 10)
                }
            }
            .padding(28)
            .animation(.easeInOut(duration: 0.2), value: model.isScanning)
        }
        .navigationTitle(L10n.tr("overview"))
        .alert(L10n.tr("cleanup.all.confirm.title"), isPresented: $confirmsCandidateCleanup) {
            Button(L10n.tr("action.cancel"), role: .cancel) { }
            Button(L10n.format("cleanup.all.button", candidates.count), role: .destructive) {
                let items = candidates
                Task { await model.delete(items) }
            }
        } message: {
            Text(L10n.format("cleanup.all.message", snapshot.candidateBytes.formatted(.byteCount(style: .file))))
        }
    }

    private var diskChart: some View {
        GroupBox(L10n.tr("chart.diskUsage")) {
            ZStack {
                Chart {
                    SectorMark(
                        angle: .value(L10n.tr("chart.space"), snapshot.totalBytes),
                        innerRadius: .ratio(0.68),
                        angularInset: 2
                    )
                    .foregroundStyle(.cyan)
                    SectorMark(
                        angle: .value(L10n.tr("chart.space"), otherUsedBytes),
                        innerRadius: .ratio(0.68),
                        angularInset: 2
                    )
                    .foregroundStyle(.blue.opacity(0.55))
                    SectorMark(
                        angle: .value(L10n.tr("chart.space"), snapshot.availableDiskBytes),
                        innerRadius: .ratio(0.68),
                        angularInset: 2
                    )
                    .foregroundStyle(.gray.opacity(0.25))
                }
                if model.isScanning {
                    VStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.regular)
                        Text(L10n.tr("action.scanning"))
                            .font(.headline)
                        Text(model.scanProgress.phase)
                            .font(.caption)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                        if let detail = model.scanProgress.detail {
                            Text(detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                    }
                    .frame(maxWidth: 190)
                    .foregroundStyle(.primary)
                    .transition(.opacity)
                } else {
                    VStack(spacing: 2) {
                        Text(snapshot.totalBytes, format: .byteCount(style: .file))
                            .font(.title2.bold())
                        Text(L10n.tr("chart.developerAnalyzed")).font(.caption).foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }
            }
            .frame(width: 300, height: 260)
            HStack(spacing: 14) {
                DiskLegend(color: .cyan, title: L10n.tr("chart.developerData"))
                DiskLegend(color: .blue.opacity(0.55), title: L10n.tr("chart.otherData"))
                DiskLegend(color: .gray.opacity(0.25), title: L10n.tr("metric.available"))
            }
            .font(.caption)
            .padding(.bottom, 6)
        }
    }
}

private struct DiskLegend: View {
    let color: Color
    let title: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Circle().fill(color).frame(width: 8, height: 8)
        }
        .labelStyle(.titleAndIcon)
    }
}

private struct CategoryUsageList: View {
    let categories: [StorageCategory]
    let snapshot: StorageSnapshot

    private let colors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .teal,
        .indigo, .mint, .cyan, .yellow, .red, .brown
    ]

    private var largestSize: Int64 {
        max(1, categories.map { snapshot.bytes(in: $0) }.max() ?? 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                let size = snapshot.bytes(in: category)

                HStack(spacing: 14) {
                    Label(category.title, systemImage: category.systemImage)
                        .lineLimit(1)
                        .frame(minWidth: 170, idealWidth: 220, maxWidth: 260, alignment: .leading)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.primary.opacity(0.08))
                            Capsule()
                                .fill(colors[index % colors.count].gradient)
                                .frame(width: max(
                                    3,
                                    proxy.size.width * CGFloat(size) / CGFloat(largestSize)
                                ))
                        }
                    }
                    .frame(height: 8)

                    Text(size, format: .byteCount(style: .file))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 112, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(
                    .primary.opacity(index.isMultiple(of: 2) ? 0.055 : 0.018)
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: Int64
    let icon: String
    var buttonTitle: String? = nil
    var isButtonDisabled = false
    var buttonAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value, format: .byteCount(style: .file))
                    .font(.title3.bold().monospacedDigit())
            }
            Spacer()
            if let buttonTitle, let buttonAction {
                Button(buttonTitle, role: .destructive, action: buttonAction)
                    .buttonStyle(.bordered)
                    .disabled(isButtonDisabled)
            }
        }
        .padding(14)
        .frame(minWidth: 260)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct CategoryView: View {
    let category: StorageCategory
    let model: StorageViewModel
    @State private var sortOrder = [KeyPathComparator(\StorageLocation.byteCount, order: .reverse)]
    @State private var pendingDeletion: StorageLocation?

    private var locations: [StorageLocation] {
        model.snapshot.locations(in: category).sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 38))
                    .foregroundStyle(.tint)
                    .frame(width: 54)
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.title).font(.title.bold())
                    Text(category.subtitle).foregroundStyle(.secondary)
                }
                Spacer()
                Text(model.snapshot.bytes(in: category), format: .byteCount(style: .file))
                    .font(.title2.monospacedDigit().bold())
            }
            .padding(24)

            Divider()

            if model.isScanning && locations.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text(model.scanProgress.phase)
                        .font(.headline)
                    if let detail = model.scanProgress.detail {
                        Text(detail)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if locations.isEmpty {
                ContentUnavailableView(
                    L10n.tr("empty.title"),
                    systemImage: "checkmark.circle",
                    description: Text(L10n.tr("empty.description"))
                )
            } else {
                Table(locations, sortOrder: $sortOrder) {
                    TableColumn(L10n.tr("table.item"), value: \.name) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 7) {
                                Text(item.name).lineLimit(1)
                                if item.candidateReason != nil {
                                    Text(L10n.tr("candidate.badge"))
                                        .font(.caption2.bold())
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.orange.opacity(0.12), in: Capsule())
                                }
                            }
                            Text(item.detail ?? item.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if let reason = item.candidateReason ?? item.advisoryReason {
                                Text(reason)
                                    .font(.caption)
                                    .foregroundStyle(item.candidateReason != nil ? .orange : .blue)
                                    .lineLimit(1)
                            }
                        }
                        .help(item.candidateReason ?? item.advisoryReason ?? item.path)
                    }
                    .width(min: 230, ideal: 360, max: 560)
                    TableColumn(L10n.tr("table.modified"), value: \.modifiedSortDate) { item in
                        if let date = item.modifiedAt {
                            Text(date, style: .date)
                        } else {
                            Text("—").foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 110, ideal: 135, max: 165)
                    TableColumn(L10n.tr("table.size"), value: \.byteCount) { item in
                        Text(item.byteCount, format: .byteCount(style: .file))
                            .monospacedDigit()
                    }
                    .width(min: 85, ideal: 105, max: 125)
                    TableColumn("") { item in
                        Menu {
                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([
                                    URL(fileURLWithPath: item.path)
                                ])
                            } label: {
                                Label(L10n.tr("action.showFinder"), systemImage: "folder")
                            }

                            Divider()

                            Button(role: .destructive) {
                                pendingDeletion = item
                            } label: {
                                Label(L10n.tr("action.delete"), systemImage: "trash")
                            }
                            .disabled(model.isScanning || model.isCleaning || item.isDeletionBlocked)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .buttonStyle(.borderless)
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .help(L10n.format("actions.help", item.name))
                    }
                    .width(min: 30, ideal: 34, max: 38)
                }
            }
        }
        .navigationTitle(category.title)
        .alert(
            L10n.format("delete.confirm.title", pendingDeletion?.name ?? L10n.tr("delete.thisItem")),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            )
        ) {
            Button(L10n.tr("action.cancel"), role: .cancel) { pendingDeletion = nil }
            Button(L10n.tr("action.delete"), role: .destructive) {
                guard let item = pendingDeletion else { return }
                pendingDeletion = nil
                Task { await model.delete([item]) }
            }
        } message: {
            if let item = pendingDeletion {
                Text(deletionMessage(for: item))
            }
        }
    }

    private func deletionMessage(for item: StorageLocation) -> String {
        switch item.category {
        case .simulatorDevices, .simulatorRuntimes:
            L10n.format("delete.coreSimulator.message", item.byteCount.formatted(.byteCount(style: .file)))
        case .gradleCache:
            L10n.format("delete.gradle.message", item.byteCount.formatted(.byteCount(style: .file)))
        default:
            L10n.format("delete.trash.message", item.byteCount.formatted(.byteCount(style: .file)))
        }
    }
}
