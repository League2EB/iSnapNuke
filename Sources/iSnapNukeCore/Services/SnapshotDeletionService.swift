import Foundation
import iSnapNukeLocalization

public enum SnapshotDeletionError: LocalizedError, Equatable {
    case noLongerSafe
    case commandFailed(String)
    case malformedInput
    case forceRequiresAdministrator

    public var errorDescription: String? {
        switch self {
        case .noLongerSafe:
            L10n.text("error.snapshot_no_longer_safe")
        case let .commandFailed(message):
            L10n.format("error.snapshot_delete_failed", message)
        case .malformedInput:
            L10n.text("error.snapshot_malformed")
        case .forceRequiresAdministrator:
            L10n.text("error.force_requires_administrator")
        }
    }
}

public struct SnapshotDeletionService: Sendable {
    private let runner: any CommandRunning
    private let scanner: any SnapshotScanning
    private let diskutil = URL(fileURLWithPath: "/usr/sbin/diskutil")

    public init(
        runner: any CommandRunning = ProcessCommandRunner(),
        scanner: (any SnapshotScanning)? = nil
    ) {
        self.runner = runner
        self.scanner = scanner ?? DiskUtilityScanner(runner: runner)
    }

    public func delete(
        _ target: AssessedSnapshot,
        mode: SnapshotDeletionMode
    ) async -> SnapshotDeletionResult {
        guard mode == .standard else {
            return .skipped(
                target.id,
                reason: SnapshotDeletionError.forceRequiresAdministrator.localizedDescription
            )
        }
        guard mode.permits(target) else {
            return SnapshotDeletionPreflight.rejectionResult(for: target, mode: mode)
        }

        do {
            let currentSnapshots = try await scanner.scan()
            let current: AssessedSnapshot
            switch SnapshotDeletionPreflight.prepare(
                target: target,
                currentSnapshots: currentSnapshots,
                mode: mode
            ) {
            case let .ready(snapshot):
                current = snapshot
            case let .skipped(result):
                return result
            }

            let result = try await runner.run(
                executable: diskutil,
                arguments: [
                    "apfs",
                    "deleteSnapshot",
                    current.snapshot.volume.deviceIdentifier,
                    "-uuid",
                    current.snapshot.rawUUID,
                    "-wait",
                ]
            )

            guard result.status == 0 else {
                return .failed(target.id, message: result.outputText)
            }

            return .deleted(target.id)
        } catch {
            return .failed(target.id, message: error.localizedDescription)
        }
    }

    public func delete(
        _ targets: [AssessedSnapshot],
        mode: SnapshotDeletionMode = .standard
    ) async -> [SnapshotDeletionResult] {
        var results: [SnapshotDeletionResult] = []

        for target in targets {
            let result = await delete(target, mode: mode)
            results.append(result)

            if case .deleted = result {
                continue
            } else {
                break
            }
        }

        return results
    }
}

extension SnapshotDeletionService: SnapshotDeleting {}
