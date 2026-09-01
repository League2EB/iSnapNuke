#if DEBUG
import Combine
import Foundation
import iSnapNukeCore
import iSnapNukeLocalization

enum DemoDeletionScenario: String, CaseIterable, Identifiable {
    case allSucceed
    case permissionDenied
    case missing
    case commandFailed

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .allSucceed: "demo.scenario.all_succeed"
        case .permissionDenied: "demo.scenario.permission_denied"
        case .missing: "demo.scenario.missing"
        case .commandFailed: "demo.scenario.command_failed"
        }
    }
}

enum DemoDeletionSpeed: String, CaseIterable, Identifiable {
    case fast
    case normal
    case slow

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .fast: "demo.speed.fast"
        case .normal: "demo.speed.normal"
        case .slow: "demo.speed.slow"
        }
    }

    var serviceDelay: Duration {
        switch self {
        case .fast: .milliseconds(150)
        case .normal: .milliseconds(650)
        case .slow: .milliseconds(1_400)
        }
    }

    var deletionTiming: SnapshotDeletionTiming {
        switch self {
        case .fast:
            SnapshotDeletionTiming(
                successDisplayDuration: .milliseconds(180),
                rowAnimationDuration: 0.2
            )
        case .normal:
            SnapshotDeletionTiming(
                successDisplayDuration: .milliseconds(500),
                rowAnimationDuration: 0.28
            )
        case .slow:
            SnapshotDeletionTiming(
                successDisplayDuration: .milliseconds(1_000),
                rowAnimationDuration: 0.42
            )
        }
    }
}

@MainActor
final class DemoModeController: ObservableObject {
    @Published private(set) var speed: DemoDeletionSpeed = .normal
    @Published private(set) var scenario: DemoDeletionScenario = .allSucceed

    let viewModel: SnapshotViewModel
    private let store: DemoSnapshotStore

    init() {
        let store = DemoSnapshotStore()
        self.store = store
        self.viewModel = SnapshotViewModel(
            scanner: store,
            deletionService: DemoSnapshotDeletionService(store: store, authorization: .standard),
            adminDeletionService: DemoSnapshotDeletionService(store: store, authorization: .administrator),
            deletionTiming: DemoDeletionSpeed.normal.deletionTiming
        )
    }

    func selectSpeed(_ speed: DemoDeletionSpeed) {
        guard !viewModel.isDeleting else { return }
        self.speed = speed
        viewModel.updateDeletionTiming(speed.deletionTiming)
        Task {
            await store.configure(speed: speed)
        }
    }

    func selectScenario(_ scenario: DemoDeletionScenario) {
        guard !viewModel.isDeleting else { return }
        self.scenario = scenario
        Task {
            await store.configure(scenario: scenario)
        }
    }

    func reset() {
        guard !viewModel.isDeleting else { return }
        viewModel.resetPresentationState()
        Task {
            await store.reset()
            await viewModel.refresh()
        }
    }
}

private enum DemoDeletionAuthorization: Sendable, Equatable {
    case standard
    case administrator
}

private struct DemoSnapshotDeletionService: SnapshotDeleting {
    let store: DemoSnapshotStore
    let authorization: DemoDeletionAuthorization

    func delete(
        _ target: AssessedSnapshot,
        mode _: SnapshotDeletionMode
    ) async -> SnapshotDeletionResult {
        await store.delete(target, authorization: authorization)
    }
}

private actor DemoSnapshotStore: SnapshotScanning {
    private var snapshots = DemoSnapshotStore.seedSnapshots
    private var speed: DemoDeletionSpeed = .normal
    private var scenario: DemoDeletionScenario = .allSucceed
    private var standardDeletionCount = 0

    func scan() async throws -> [AssessedSnapshot] {
        snapshots
    }

    func configure(speed: DemoDeletionSpeed) {
        self.speed = speed
    }

    func configure(scenario: DemoDeletionScenario) {
        self.scenario = scenario
        standardDeletionCount = 0
    }

    func reset() {
        snapshots = Self.seedSnapshots
        standardDeletionCount = 0
    }

    func delete(
        _ target: AssessedSnapshot,
        authorization: DemoDeletionAuthorization
    ) async -> SnapshotDeletionResult {
        try? await Task.sleep(for: speed.serviceDelay)

        guard snapshots.contains(where: { $0.id == target.id }) else {
            return .skipped(target.id, reason: L10n.text("result.snapshot_missing"))
        }

        if authorization == .standard {
            standardDeletionCount += 1
            if standardDeletionCount == 2 {
                switch scenario {
                case .allSucceed:
                    break
                case .permissionDenied:
                    return .failed(target.id, message: "Permission denied")
                case .missing:
                    snapshots.removeAll { $0.id == target.id }
                    return .skipped(target.id, reason: L10n.text("result.snapshot_missing"))
                case .commandFailed:
                    return .failed(target.id, message: "diskutil: simulated command failure")
                }
            }
        }

        snapshots.removeAll { $0.id == target.id }
        return .deleted(target.id)
    }

    private static let seedSnapshots: [AssessedSnapshot] = [
        assessedSnapshot(
            uuid: "E6A1DCA1-4E68-4CDB-8465-9CD087F773F1",
            name: "com.synology.activebackup.demo",
            xid: 9_105,
            privateSizeBytes: 5_191_966_720
        ),
        assessedSnapshot(
            uuid: "B073A938-66A2-4A50-8B4A-C42A4752EA45",
            name: "com.example.project-backup",
            xid: 9_104,
            privateSizeBytes: 2_684_354_560
        ),
        assessedSnapshot(
            uuid: "C3E6F7B4-7E23-4167-9FB0-ED8B2FD5FD5C",
            name: "com.apple.TimeMachine.demo",
            xid: 9_103,
            privateSizeBytes: 1_073_741_824
        ),
        assessedSnapshot(
            uuid: "84B02383-F4D4-4D10-A414-736F85C763DD",
            name: "com.example.retained",
            xid: 9_102,
            privateSizeBytes: 536_870_912,
            purgeable: false
        ),
        assessedSnapshot(
            uuid: "CA8B32B9-BEF9-47BA-8B48-9186795A15EB",
            name: "com.apple.os.update-demo",
            xid: 9_101,
            privateSizeBytes: nil,
            role: .system,
            deviceIdentifier: "disk3s5",
            mountPoint: "/"
        ),
    ]

    private static func assessedSnapshot(
        uuid: String,
        name: String,
        xid: Int64,
        privateSizeBytes: Int64?,
        purgeable: Bool = true,
        role: VolumeRole = .data,
        deviceIdentifier: String = "disk3s1",
        mountPoint: String = "/System/Volumes/Data"
    ) -> AssessedSnapshot {
        let snapshot = APFSSnapshot(
            uuid: UUID(uuidString: uuid)!,
            name: name,
            xid: xid,
            purgeable: purgeable,
            revertTo: false,
            rootTo: false,
            limitingContainerShrink: false,
            privateSizeBytes: privateSizeBytes,
            volume: APFSVolume(
                role: role,
                deviceIdentifier: deviceIdentifier,
                name: role == .data ? "Data" : "Macintosh HD",
                mountPoint: mountPoint
            )
        )
        return SnapshotSafetyEvaluator.assess(snapshot)
    }
}
#endif
