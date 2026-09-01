import Foundation
import iSnapNukeLocalization

enum SnapshotDeletionPreflightResult {
    case ready(AssessedSnapshot)
    case skipped(SnapshotDeletionResult)
}

enum SnapshotDeletionPreflight {
    static func prepare(
        target: AssessedSnapshot,
        currentSnapshots: [AssessedSnapshot],
        mode: SnapshotDeletionMode
    ) -> SnapshotDeletionPreflightResult {
        guard mode.permits(target) else {
            return .skipped(rejectionResult(for: target, mode: mode))
        }

        guard let current = currentSnapshots.first(where: { $0.id == target.id }) else {
            return .skipped(
                .skipped(target.id, reason: L10n.text("result.snapshot_missing"))
            )
        }

        guard mode.permits(current) else {
            return .skipped(rejectionResult(for: current, mode: mode))
        }

        return .ready(current)
    }

    static func rejectionResult(
        for snapshot: AssessedSnapshot,
        mode: SnapshotDeletionMode
    ) -> SnapshotDeletionResult {
        let reason: String
        switch mode {
        case .standard:
            reason = snapshot.safety.isDeletable
                ? SnapshotDeletionError.noLongerSafe.localizedDescription
                : L10n.text("result.snapshot_protected")
        case .forceAdministrator:
            reason = SnapshotDeletionError.malformedInput.localizedDescription
        }
        return .skipped(snapshot.id, reason: reason)
    }
}
