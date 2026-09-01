import Foundation
import iSnapNukeLocalization

public struct AdminSnapshotDeletionService: Sendable {
    private let runner: any CommandRunning
    private let scanner: any SnapshotScanning
    private let osascript = URL(fileURLWithPath: "/usr/bin/osascript")

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

            let device = current.snapshot.volume.deviceIdentifier
            let uuid = current.snapshot.rawUUID
            guard DeviceIdentifier.isValid(device), UUID(uuidString: uuid) != nil else {
                return .skipped(target.id, reason: SnapshotDeletionError.malformedInput.localizedDescription)
            }

            let command = "/usr/sbin/diskutil apfs deleteSnapshot \(device) -uuid \(uuid) -wait"
            let script = "do shell script \(appleScriptStringLiteral(command)) with administrator privileges"
            let result = try await runner.run(
                executable: osascript,
                arguments: ["-e", script]
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

            if mode == .forceAdministrator {
                continue
            }

            guard case .deleted = result else {
                break
            }
        }

        return results
    }

    private func appleScriptStringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

extension AdminSnapshotDeletionService: SnapshotDeleting {}

public extension SnapshotDeletionResult {
    var failureMessage: String? {
        if case let .failed(_, message) = self {
            return message
        }
        return nil
    }

    var isLikelyPermissionFailure: Bool {
        guard let message = failureMessage?.lowercased() else {
            return false
        }

        let indicators = [
            "not permitted",
            "permission denied",
            "operation not permitted",
            "not authorized",
            "ownership",
            "權限",
            "不允許",
            "未授權",
        ]
        return indicators.contains { message.contains($0) }
    }
}
