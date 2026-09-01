import XCTest
@testable import iSnapNukeCore

@MainActor
final class SnapshotViewModelTests: XCTestCase {
    func testSuccessfulBatchRemovesRowsOneByOneAndPublishesSummaryAtEnd() async {
        let targets = makeTargets(count: 3)
        let store = InMemorySnapshotStore(snapshots: targets)
        let viewModel = SnapshotViewModel(
            scanner: store,
            deletionService: store,
            adminDeletionService: store,
            pauser: ImmediateSnapshotDeletionPauser()
        )

        await viewModel.refresh()
        targets.forEach(viewModel.toggleSelection(for:))

        await viewModel.deleteSelected()

        XCTAssertEqual(
            viewModel.deletionResults,
            targets.map { .deleted($0.id) }
        )
        XCTAssertTrue(viewModel.snapshots.isEmpty)
        XCTAssertTrue(viewModel.operationStates.isEmpty)
        XCTAssertNil(viewModel.deletionProgress)
        XCTAssertFalse(viewModel.isDeleting)
    }

    func testFailureStopsBatchKeepsRowAndPreparesAdministratorRetry() async {
        let targets = makeTargets(count: 3)
        let store = InMemorySnapshotStore(
            snapshots: targets,
            failureAtStandardDeletion: 2,
            failureResult: .failed(targets[1].id, message: "Permission denied")
        )
        let viewModel = SnapshotViewModel(
            scanner: store,
            deletionService: store,
            adminDeletionService: AdministratorDeletionService(store: store),
            pauser: ImmediateSnapshotDeletionPauser()
        )

        await viewModel.refresh()
        targets.forEach(viewModel.toggleSelection(for:))

        await viewModel.deleteSelected()

        XCTAssertEqual(
            viewModel.deletionResults,
            [
                .deleted(targets[0].id),
                .failed(targets[1].id, message: "Permission denied"),
            ]
        )
        XCTAssertEqual(viewModel.snapshots.map(\.id), [targets[1].id, targets[2].id])
        XCTAssertEqual(
            viewModel.operationStates[targets[1].id],
            .failed(message: "Permission denied")
        )
        XCTAssertNil(viewModel.operationStates[targets[2].id])
        XCTAssertEqual(viewModel.pendingAdminRetryTargets.map(\.id), [targets[1].id])

        viewModel.prepareAdminRetry()
        await viewModel.retryWithAdministrator()

        XCTAssertEqual(viewModel.deletionResults, [.deleted(targets[1].id)])
        XCTAssertEqual(viewModel.snapshots.map(\.id), [targets[2].id])
        XCTAssertTrue(viewModel.operationStates.isEmpty)
        XCTAssertTrue(viewModel.pendingAdminRetryTargets.isEmpty)
    }

    func testSkippedSnapshotStaysVisibleAndStopsFollowingBatch() async {
        let targets = makeTargets(count: 3)
        let store = InMemorySnapshotStore(
            snapshots: targets,
            failureAtStandardDeletion: 2,
            failureResult: .skipped(targets[1].id, reason: "Snapshot is no longer available")
        )
        let viewModel = SnapshotViewModel(
            scanner: store,
            deletionService: store,
            adminDeletionService: store,
            pauser: ImmediateSnapshotDeletionPauser()
        )

        await viewModel.refresh()
        targets.forEach(viewModel.toggleSelection(for:))

        await viewModel.deleteSelected()

        XCTAssertEqual(
            viewModel.deletionResults,
            [
                .deleted(targets[0].id),
                .skipped(targets[1].id, reason: "Snapshot is no longer available"),
            ]
        )
        XCTAssertEqual(viewModel.snapshots.map(\.id), [targets[1].id, targets[2].id])
        XCTAssertEqual(
            viewModel.operationStates[targets[1].id],
            .skipped(reason: "Snapshot is no longer available")
        )
        XCTAssertNil(viewModel.operationStates[targets[2].id])
        XCTAssertTrue(viewModel.pendingAdminRetryTargets.isEmpty)
    }

    func testForceModeMakesProtectedSnapshotsSelectableOnlyWhileEnabled() async {
        let protectedTarget = makeProtectedTarget(index: 0)
        let store = InMemorySnapshotStore(snapshots: [protectedTarget])
        let viewModel = SnapshotViewModel(
            scanner: store,
            deletionService: store,
            adminDeletionService: store,
            pauser: ImmediateSnapshotDeletionPauser()
        )

        XCTAssertFalse(viewModel.isForceDeletionEnabled)
        await viewModel.refresh()

        viewModel.toggleSelection(for: protectedTarget)
        XCTAssertTrue(viewModel.selectedIDs.isEmpty)

        viewModel.setForceDeletionEnabled(true)
        viewModel.toggleSelection(for: protectedTarget)
        XCTAssertEqual(viewModel.selectedSnapshots.map(\.id), [protectedTarget.id])

        viewModel.setForceDeletionEnabled(false)
        XCTAssertFalse(viewModel.isForceDeletionEnabled)
        XCTAssertTrue(viewModel.selectedIDs.isEmpty)
    }

    func testForceBatchContinuesAfterFailureAndUsesAdministratorMode() async {
        let targets = (0..<3).map { makeProtectedTarget(index: $0) }
        let store = InMemorySnapshotStore(
            snapshots: targets,
            failureAtForceDeletion: 2,
            forceFailureResult: .failed(targets[1].id, message: "Operation not permitted")
        )
        let viewModel = SnapshotViewModel(
            scanner: store,
            deletionService: store,
            adminDeletionService: store,
            pauser: ImmediateSnapshotDeletionPauser()
        )

        await viewModel.refresh()
        viewModel.setForceDeletionEnabled(true)
        targets.forEach(viewModel.toggleSelection(for:))

        await viewModel.deleteSelected()

        XCTAssertEqual(
            viewModel.deletionResults,
            [
                .deleted(targets[0].id),
                .failed(targets[1].id, message: "Operation not permitted"),
                .deleted(targets[2].id),
            ]
        )
        XCTAssertTrue(viewModel.deletionWasForced)
        XCTAssertEqual(viewModel.snapshots.map(\.id), [targets[1].id])
        XCTAssertTrue(viewModel.pendingAdminRetryTargets.isEmpty)
        let deletionModes = await store.deletionModes()
        XCTAssertEqual(
            deletionModes,
            [.forceAdministrator, .forceAdministrator, .forceAdministrator]
        )
    }

    private func makeTargets(count: Int) -> [AssessedSnapshot] {
        (0..<count).map { index in
            let snapshot = APFSSnapshot(
                uuid: UUID(),
                name: "com.example.demo-\(index)",
                xid: Int64(1_000 - index),
                purgeable: true,
                revertTo: false,
                rootTo: false,
                limitingContainerShrink: false,
                privateSizeBytes: Int64(index + 1) * 1_024,
                volume: APFSVolume(
                    role: .data,
                    deviceIdentifier: "disk3s1",
                    name: "Data",
                    mountPoint: "/System/Volumes/Data"
                )
            )
            return SnapshotSafetyEvaluator.assess(snapshot)
        }
    }

    private func makeProtectedTarget(index: Int) -> AssessedSnapshot {
        let snapshot = APFSSnapshot(
            uuid: UUID(),
            name: "com.apple.os.update-\(index)",
            xid: Int64(2_000 - index),
            purgeable: false,
            revertTo: false,
            rootTo: false,
            limitingContainerShrink: false,
            privateSizeBytes: Int64(index + 1) * 1_024,
            volume: APFSVolume(
                role: .system,
                deviceIdentifier: "disk3s5",
                name: "Macintosh HD",
                mountPoint: "/"
            )
        )
        return SnapshotSafetyEvaluator.assess(snapshot)
    }
}

private struct AdministratorDeletionService: SnapshotDeleting {
    let store: InMemorySnapshotStore

    func delete(
        _ target: AssessedSnapshot,
        mode _: SnapshotDeletionMode
    ) async -> SnapshotDeletionResult {
        await store.forceDelete(target)
    }
}

private actor InMemorySnapshotStore: SnapshotScanning, SnapshotDeleting {
    private var snapshots: [AssessedSnapshot]
    private let failureAtStandardDeletion: Int?
    private let failureResult: SnapshotDeletionResult?
    private let failureAtForceDeletion: Int?
    private let forceFailureResult: SnapshotDeletionResult?
    private var standardDeletionCount = 0
    private var forceDeletionCount = 0
    private var recordedDeletionModes: [SnapshotDeletionMode] = []

    init(
        snapshots: [AssessedSnapshot],
        failureAtStandardDeletion: Int? = nil,
        failureResult: SnapshotDeletionResult? = nil,
        failureAtForceDeletion: Int? = nil,
        forceFailureResult: SnapshotDeletionResult? = nil
    ) {
        self.snapshots = snapshots
        self.failureAtStandardDeletion = failureAtStandardDeletion
        self.failureResult = failureResult
        self.failureAtForceDeletion = failureAtForceDeletion
        self.forceFailureResult = forceFailureResult
    }

    func scan() async throws -> [AssessedSnapshot] {
        snapshots
    }

    func delete(
        _ target: AssessedSnapshot,
        mode: SnapshotDeletionMode
    ) async -> SnapshotDeletionResult {
        recordedDeletionModes.append(mode)

        switch mode {
        case .standard:
            standardDeletionCount += 1
            if standardDeletionCount == failureAtStandardDeletion, let failureResult {
                return failureResult
            }
        case .forceAdministrator:
            forceDeletionCount += 1
            if forceDeletionCount == failureAtForceDeletion, let forceFailureResult {
                return forceFailureResult
            }
        }

        return forceDelete(target)
    }

    func forceDelete(_ target: AssessedSnapshot) -> SnapshotDeletionResult {
        guard snapshots.contains(where: { $0.id == target.id }) else {
            return .skipped(target.id, reason: "Snapshot is no longer available")
        }
        snapshots.removeAll { $0.id == target.id }
        return .deleted(target.id)
    }

    func deletionModes() -> [SnapshotDeletionMode] {
        recordedDeletionModes
    }
}
