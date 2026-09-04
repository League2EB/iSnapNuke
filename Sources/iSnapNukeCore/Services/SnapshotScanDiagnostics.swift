import OSLog

enum SnapshotScanDiagnostics {
    private static let logger = Logger(
        subsystem: "com.xuanci.isnapnuke",
        category: "SnapshotScan"
    )

    static func logHiddenZeroPrivateSizeSnapshots(_ snapshots: [AssessedSnapshot]) {
        guard !snapshots.isEmpty else { return }

        logger.notice(
            "Hiding \(snapshots.count, privacy: .public) snapshot(s) with an APFS private size of zero bytes."
        )

        for assessedSnapshot in snapshots {
            let snapshot = assessedSnapshot.snapshot
            logger.notice(
                """
                Hidden zero-private-size snapshot \
                source=\(assessedSnapshot.source.diagnosticName, privacy: .public) \
                name=\(snapshot.name, privacy: .private(mask: .hash)) \
                volumeRole=\(snapshot.volume.role.rawValue, privacy: .public) \
                device=\(snapshot.volume.deviceIdentifier, privacy: .public) \
                xid=\(snapshot.xid, privacy: .public) \
                purgeable=\(snapshot.purgeable, privacy: .public) \
                uuid=\(snapshot.rawUUID, privacy: .private(mask: .hash))
                """
            )
        }
    }

    static func logPrivateSizeReadFailure(
        for volume: APFSVolume,
        error: any Error
    ) {
        logger.error(
            """
            Could not read APFS private sizes \
            volumeRole=\(volume.role.rawValue, privacy: .public) \
            device=\(volume.deviceIdentifier, privacy: .public) \
            failure=\(privateSizeFailureDescription(for: error), privacy: .public)
            """
        )
    }

    private static func privateSizeFailureDescription(for error: any Error) -> String {
        guard let privateSizeError = error as? SnapshotPrivateSizeError else {
            return "unknown"
        }

        switch privateSizeError {
        case let .openFailed(errorNumber):
            return "openFailed(errno: \(errorNumber))"
        case let .listFailed(errorNumber):
            return "listFailed(errno: \(errorNumber))"
        case .malformedRecord:
            return "malformedRecord"
        }
    }
}

private extension SnapshotSource {
    var diagnosticName: String {
        switch self {
        case .macOSUpdate:
            "macOSUpdate"
        case .timeMachine:
            "timeMachine"
        case .synologyActiveBackup:
            "synologyActiveBackup"
        case .other:
            "other"
        }
    }
}
