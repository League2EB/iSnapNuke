import Foundation
import iSnapNukeLocalization

public enum DiskUtilityError: LocalizedError, Equatable {
    case invalidPropertyList
    case missingVolumeMetadata
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPropertyList:
            L10n.text("error.diskutil_invalid_plist")
        case .missingVolumeMetadata:
            L10n.text("error.volume_metadata_missing")
        case let .commandFailed(message):
            L10n.format("error.diskutil_command", message)
        }
    }
}

public struct DiskUtilityScanner: Sendable {
    private let runner: any CommandRunning
    private let sizeProvider: any SnapshotPrivateSizeProviding
    private let diskutil = URL(fileURLWithPath: "/usr/sbin/diskutil")

    public init(
        runner: any CommandRunning = ProcessCommandRunner(),
        sizeProvider: any SnapshotPrivateSizeProviding = SnapshotPrivateSizeProvider()
    ) {
        self.runner = runner
        self.sizeProvider = sizeProvider
    }

    public func scan() async throws -> [AssessedSnapshot] {
        async let systemVolume = volume(at: "/", role: .system)
        async let dataVolume = volume(at: "/System/Volumes/Data", role: .data)

        let volumes = try await [systemVolume, dataVolume]
        let allSnapshots = try await withThrowingTaskGroup(of: [APFSSnapshot].self) { group in
            for volume in volumes {
                group.addTask {
                    try await snapshots(for: volume)
                }
            }

            var combined: [APFSSnapshot] = []
            for try await values in group {
                combined += values
            }
            return combined
        }

        return allSnapshots
            .map(SnapshotSafetyEvaluator.assess)
            .sorted {
                if $0.snapshot.volume.role != $1.snapshot.volume.role {
                    return $0.snapshot.volume.role == .data
                }
                return $0.snapshot.xid > $1.snapshot.xid
            }
    }

    public func volume(at mountPoint: String, role: VolumeRole) async throws -> APFSVolume {
        let result = try await runner.run(
            executable: diskutil,
            arguments: ["info", "-plist", mountPoint]
        )
        try ensureSuccess(result)

        let metadata: DiskInfoPlist
        do {
            metadata = try PropertyListDecoder().decode(DiskInfoPlist.self, from: result.standardOutput)
        } catch {
            throw DiskUtilityError.invalidPropertyList
        }

        guard
            DeviceIdentifier.isValid(metadata.deviceIdentifier),
            !metadata.volumeName.isEmpty,
            !metadata.mountPoint.isEmpty
        else {
            throw DiskUtilityError.missingVolumeMetadata
        }

        return APFSVolume(
            role: role,
            deviceIdentifier: metadata.deviceIdentifier,
            name: metadata.volumeName,
            mountPoint: metadata.mountPoint
        )
    }

    public func snapshots(for volume: APFSVolume) async throws -> [APFSSnapshot] {
        let result = try await runner.run(
            executable: diskutil,
            arguments: ["apfs", "listSnapshots", volume.deviceIdentifier, "-plist"]
        )
        try ensureSuccess(result)

        let entries: [Any]
        do {
            let propertyList = try PropertyListSerialization.propertyList(
                from: result.standardOutput,
                options: [],
                format: nil
            )
            guard
                let response = propertyList as? [String: Any],
                let snapshots = response["Snapshots"] as? [Any]
            else {
                throw DiskUtilityError.invalidPropertyList
            }
            entries = snapshots
        } catch {
            throw DiskUtilityError.invalidPropertyList
        }

        let privateSizes = (try? sizeProvider.privateSizes(for: volume)) ?? [:]

        return entries.map { entry in
            let entry = SnapshotPlist(dictionary: entry as? [String: Any])
            let uuid = UUID(uuidString: entry.snapshotUUID) ?? UUID()
            return APFSSnapshot(
                uuid: uuid,
                rawUUID: entry.snapshotUUID,
                name: entry.snapshotName,
                xid: entry.snapshotXID,
                purgeable: entry.purgeable,
                revertTo: entry.revertTo,
                rootTo: entry.rootTo,
                limitingContainerShrink: entry.limitingContainerShrink,
                metadataIsComplete: entry.metadataIsComplete,
                privateSizeBytes: privateSizes[uuid],
                volume: volume
            )
        }
    }

    private func ensureSuccess(_ result: CommandResult) throws {
        guard result.status == 0 else {
            throw DiskUtilityError.commandFailed(result.outputText)
        }
    }
}

extension DiskUtilityScanner: SnapshotScanning {}

private struct DiskInfoPlist: Decodable {
    let deviceIdentifier: String
    let volumeName: String
    let mountPoint: String

    enum CodingKeys: String, CodingKey {
        case deviceIdentifier = "DeviceIdentifier"
        case volumeName = "VolumeName"
        case mountPoint = "MountPoint"
    }
}

private struct SnapshotPlist {
    let limitingContainerShrink: Bool
    let purgeable: Bool
    let revertTo: Bool
    let rootTo: Bool
    let snapshotName: String
    let snapshotUUID: String
    let snapshotXID: Int64
    let metadataIsComplete: Bool

    init(dictionary: [String: Any]?) {
        guard let dictionary else {
            limitingContainerShrink = false
            purgeable = false
            revertTo = false
            rootTo = false
            snapshotName = ""
            snapshotUUID = ""
            snapshotXID = 0
            metadataIsComplete = false
            return
        }

        var isComplete = true

        func bool(_ key: String) -> Bool {
            guard let value = dictionary[key] as? Bool else {
                isComplete = false
                return false
            }
            return value
        }

        func string(_ key: String) -> String {
            guard let value = dictionary[key] as? String else {
                isComplete = false
                return ""
            }
            return value
        }

        func int64(_ key: String) -> Int64 {
            guard let value = dictionary[key] as? NSNumber else {
                isComplete = false
                return 0
            }
            return value.int64Value
        }

        limitingContainerShrink = bool("LimitingContainerShrink")
        purgeable = bool("Purgeable")
        revertTo = bool("RevertTo")
        rootTo = bool("RootTo")
        snapshotName = string("SnapshotName")
        snapshotUUID = string("SnapshotUUID")
        snapshotXID = int64("SnapshotXID")
        metadataIsComplete = isComplete
    }
}
