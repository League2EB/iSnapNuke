import Foundation
import iSnapNukeLocalization

public enum SnapshotSafetyEvaluator {
    public static func assess(_ snapshot: APFSSnapshot) -> AssessedSnapshot {
        AssessedSnapshot(
            snapshot: snapshot,
            source: source(for: snapshot.name),
            safety: safety(for: snapshot)
        )
    }

    public static func source(for name: String) -> SnapshotSource {
        let normalizedName = name.lowercased()

        if normalizedName.hasPrefix("com.apple.os.update") {
            return .macOSUpdate
        }
        if normalizedName.contains("timemachine") || normalizedName.contains("time.machine") {
            return .timeMachine
        }
        if normalizedName.hasPrefix("com.synology.activebackup") {
            return .synologyActiveBackup
        }
        return .other
    }

    public static func safety(for snapshot: APFSSnapshot) -> SnapshotSafety {
        var reasons: [String] = []

        if snapshot.volume.role != .data {
            reasons.append(L10n.text("reason.data_only"))
        }
        if !snapshot.purgeable {
            reasons.append(L10n.text("reason.not_purgeable"))
        }
        if snapshot.revertTo {
            reasons.append(L10n.text("reason.revert_target"))
        }
        if snapshot.rootTo {
            reasons.append(L10n.text("reason.root_snapshot"))
        }
        if source(for: snapshot.name) == .macOSUpdate {
            reasons.append(L10n.text("reason.macos_update"))
        }
        if snapshot.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            reasons.append(L10n.text("reason.missing_name"))
        }
        if !snapshot.metadataIsComplete {
            reasons.append(L10n.text("reason.metadata_incomplete"))
        }
        if UUID(uuidString: snapshot.rawUUID) == nil {
            reasons.append(L10n.text("reason.invalid_uuid"))
        }
        if !DeviceIdentifier.isValid(snapshot.volume.deviceIdentifier) {
            reasons.append(L10n.text("reason.invalid_device"))
        }

        return reasons.isEmpty ? .deletable : .protected(reasons: reasons)
    }
}
