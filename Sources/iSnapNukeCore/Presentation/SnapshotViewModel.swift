import Combine
import Foundation
import iSnapNukeLocalization

@MainActor
public final class SnapshotViewModel: ObservableObject {
    @Published public private(set) var snapshots: [AssessedSnapshot] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isDeleting = false
    @Published public private(set) var lastScanDate: Date?
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var deletionResults: [SnapshotDeletionResult] = []
    @Published public private(set) var deletionWasForced = false
    @Published public private(set) var pendingAdminRetryTargets: [AssessedSnapshot] = []
    @Published public private(set) var operationStates: [UUID: SnapshotOperationState] = [:]
    @Published public private(set) var deletionProgress: SnapshotDeletionProgress?
    @Published public private(set) var deletionTiming: SnapshotDeletionTiming
    @Published public private(set) var isForceDeletionEnabled = false
    @Published public var selectedIDs: Set<UUID> = []

    private let scanner: any SnapshotScanning
    private let deletionService: any SnapshotDeleting
    private let adminDeletionService: any SnapshotDeleting
    private let pauser: any SnapshotDeletionPausing
    private var hasLoaded = false

    public init(
        scanner: any SnapshotScanning = DiskUtilityScanner(),
        deletionService: any SnapshotDeleting = SnapshotDeletionService(),
        adminDeletionService: any SnapshotDeleting = AdminSnapshotDeletionService(),
        pauser: any SnapshotDeletionPausing = TaskSnapshotDeletionPauser(),
        deletionTiming: SnapshotDeletionTiming = .standard
    ) {
        self.scanner = scanner
        self.deletionService = deletionService
        self.adminDeletionService = adminDeletionService
        self.pauser = pauser
        self.deletionTiming = deletionTiming
    }

    public var selectedSnapshots: [AssessedSnapshot] {
        snapshots.filter { selectedIDs.contains($0.id) && isSelectable($0) }
    }

    public var deletableCount: Int {
        snapshots.filter(\.safety.isDeletable).count
    }

    public var protectedCount: Int {
        snapshots.count - deletableCount
    }

    public var canDeleteSelection: Bool {
        !selectedSnapshots.isEmpty && !isDeleting
    }

    public var selectedPrivateSizeBytes: Int64? {
        let sizes = selectedSnapshots.compactMap(\.snapshot.privateSizeBytes)
        guard sizes.count == selectedSnapshots.count else {
            return nil
        }
        return sizes.reduce(0, +)
    }

    public func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await refresh()
    }

    public func refresh() async {
        await refresh(allowDuringDeletion: false)
    }

    public func toggleSelection(for snapshot: AssessedSnapshot) {
        guard isSelectable(snapshot), !isDeleting else { return }

        if selectedIDs.contains(snapshot.id) {
            selectedIDs.remove(snapshot.id)
        } else {
            selectedIDs.insert(snapshot.id)
        }
    }

    public func deleteSelected() async {
        let targets = selectedSnapshots
        guard !targets.isEmpty else { return }

        if isForceDeletionEnabled {
            await delete(
                targets,
                with: adminDeletionService,
                mode: .forceAdministrator
            )
        } else {
            await delete(targets, with: deletionService, mode: .standard)
        }
    }

    public func retryWithAdministrator() async {
        let targets = pendingAdminRetryTargets
        guard !targets.isEmpty else { return }
        await delete(targets, with: adminDeletionService, mode: .standard)
    }

    public func setForceDeletionEnabled(_ isEnabled: Bool) {
        guard !isDeleting else { return }

        isForceDeletionEnabled = isEnabled
        guard !isEnabled else { return }

        selectedIDs = selectedIDs.intersection(
            Set(snapshots.filter(\.safety.isDeletable).map(\.id))
        )
    }

    public func clearError() {
        errorMessage = nil
    }

    public func clearDeletionResults() {
        deletionResults = []
        deletionWasForced = false
        pendingAdminRetryTargets = []
    }

    public func prepareAdminRetry() {
        deletionResults = []
    }

    public func updateDeletionTiming(_ timing: SnapshotDeletionTiming) {
        guard !isDeleting else { return }
        deletionTiming = timing
    }

    public func resetPresentationState() {
        guard !isDeleting else { return }
        selectedIDs = []
        deletionResults = []
        pendingAdminRetryTargets = []
        operationStates = [:]
        deletionProgress = nil
        isForceDeletionEnabled = false
        errorMessage = nil
    }

    public func isSelectable(_ snapshot: AssessedSnapshot) -> Bool {
        if isForceDeletionEnabled {
            return snapshot.isForceDeletable
        }
        return snapshot.safety.isDeletable
    }

    private func refresh(allowDuringDeletion: Bool) async {
        guard allowDuringDeletion || !isDeleting else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            snapshots = try await scanner.scan()
            selectedIDs = selectedIDs.intersection(
                Set(snapshots.filter(isSelectable).map(\.id))
            )
            lastScanDate = .now
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(
        _ targets: [AssessedSnapshot],
        with service: any SnapshotDeleting,
        mode: SnapshotDeletionMode
    ) async {
        isDeleting = true
        errorMessage = nil
        deletionResults = []
        deletionWasForced = mode == .forceAdministrator
        pendingAdminRetryTargets = []

        let total = targets.count
        for (index, target) in targets.enumerated() {
            operationStates[target.id] = .queued(
                SnapshotDeletionProgress(current: index + 1, total: total)
            )
        }

        defer {
            isDeleting = false
            deletionProgress = nil
        }

        var results: [SnapshotDeletionResult] = []

        for (index, target) in targets.enumerated() {
            let progress = SnapshotDeletionProgress(current: index + 1, total: total)
            deletionProgress = progress
            operationStates[target.id] = .deleting(progress)

            let result = await service.delete(target, mode: mode)
            results.append(result)
            selectedIDs.remove(target.id)

            switch result {
            case .deleted:
                operationStates[target.id] = .succeeded
                await pauser.pause(for: deletionTiming.successDisplayDuration)
                snapshots.removeAll { $0.id == target.id }
                operationStates.removeValue(forKey: target.id)

            case let .failed(_, message):
                operationStates[target.id] = .failed(message: message)
                if mode == .standard {
                    clearQueuedStates(after: index, in: targets)
                }

            case let .skipped(_, reason):
                operationStates[target.id] = .skipped(reason: reason)
                if mode == .standard {
                    clearQueuedStates(after: index, in: targets)
                }
            }

            guard mode == .forceAdministrator || result.isDeleted else {
                break
            }
        }

        if mode == .standard {
            let permissionFailureIDs = Set(
                results
                    .filter(\.isLikelyPermissionFailure)
                    .map(\.uuid)
            )
            pendingAdminRetryTargets = targets.filter { permissionFailureIDs.contains($0.id) }
        }

        await refresh(allowDuringDeletion: true)
        deletionResults = results
    }

    private func clearQueuedStates(
        after index: Int,
        in targets: [AssessedSnapshot]
    ) {
        for target in targets.dropFirst(index + 1) {
            operationStates.removeValue(forKey: target.id)
        }
    }
}

private extension SnapshotDeletionResult {
    var isDeleted: Bool {
        if case .deleted = self {
            return true
        }
        return false
    }
}
