import Foundation

@MainActor
@Observable
final class StorageViewModel {
    private(set) var snapshot = StorageSnapshot.empty
    private(set) var isScanning = false
    private(set) var scanProgress = StorageScanProgress(
        phase: L10n.tr("scan.phase.preparing"),
        detail: nil
    )
    private(set) var isCleaning = false
    private(set) var errorMessage: String?
    private(set) var cleanupSuccessMessage: String?

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        errorMessage = nil
        scanProgress = StorageScanProgress(phase: L10n.tr("scan.phase.preparing"), detail: nil)

        let (progressStream, progressContinuation) = AsyncStream.makeStream(
            of: StorageScanProgress.self
        )
        let scanTask = Task.detached(priority: .userInitiated) {
            let result = StorageScanner(progressHandler: { progress in
                progressContinuation.yield(progress)
            }).scan()
            progressContinuation.finish()
            return result
        }

        for await progress in progressStream {
            scanProgress = progress
        }
        let result = await scanTask.value

        snapshot = result
        isScanning = false
    }

    func delete(_ locations: [StorageLocation]) async {
        guard !locations.isEmpty, !isCleaning else { return }
        isCleaning = true
        errorMessage = nil
        cleanupSuccessMessage = nil

        let result = await Task.detached(priority: .userInitiated) {
            var failures: [String] = []
            var removedCount = 0
            var trashedCount = 0
            let service = CleanupService()
            for location in locations {
                do {
                    try service.remove(location)
                    removedCount += 1
                    if ![StorageCategory.simulatorDevices, .simulatorRuntimes].contains(location.category) {
                        trashedCount += 1
                    }
                } catch {
                    failures.append("\(location.name): \(error.localizedDescription)")
                }
            }
            return (failures, removedCount, trashedCount)
        }.value

        isCleaning = false
        if !result.0.isEmpty {
            errorMessage = result.0.joined(separator: "\n\n")
        } else if result.1 > 0 {
            cleanupSuccessMessage = result.2 > 0
                ? L10n.format("cleanup.success.trash", result.1)
                : L10n.format("cleanup.success.simulator", result.1)
        }
        await scan()
    }

    func clearError() {
        errorMessage = nil
    }

    func clearCleanupSuccess() {
        cleanupSuccessMessage = nil
    }
}
