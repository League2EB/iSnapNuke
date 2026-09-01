import Foundation
import iSnapNukeLocalization

public enum VolumeRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case data
    case system

    public var id: String { rawValue }

    public var localizedTitle: String {
        switch self {
        case .data: L10n.text("volume.data")
        case .system: L10n.text("volume.system")
        }
    }
}

public struct APFSVolume: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let role: VolumeRole
    public let deviceIdentifier: String
    public let name: String
    public let mountPoint: String

    public var id: String { "\(role.rawValue)-\(deviceIdentifier)" }

    public init(role: VolumeRole, deviceIdentifier: String, name: String, mountPoint: String) {
        self.role = role
        self.deviceIdentifier = deviceIdentifier
        self.name = name
        self.mountPoint = mountPoint
    }
}

public struct APFSSnapshot: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let uuid: UUID
    public let rawUUID: String
    public let name: String
    public let xid: Int64
    public let purgeable: Bool
    public let revertTo: Bool
    public let rootTo: Bool
    public let limitingContainerShrink: Bool
    public let metadataIsComplete: Bool
    public let privateSizeBytes: Int64?
    public let volume: APFSVolume

    public var id: UUID { uuid }

    public init(
        uuid: UUID,
        rawUUID: String? = nil,
        name: String,
        xid: Int64,
        purgeable: Bool,
        revertTo: Bool,
        rootTo: Bool,
        limitingContainerShrink: Bool,
        metadataIsComplete: Bool = true,
        privateSizeBytes: Int64? = nil,
        volume: APFSVolume
    ) {
        self.uuid = uuid
        self.rawUUID = rawUUID ?? uuid.uuidString
        self.name = name
        self.xid = xid
        self.purgeable = purgeable
        self.revertTo = revertTo
        self.rootTo = rootTo
        self.limitingContainerShrink = limitingContainerShrink
        self.metadataIsComplete = metadataIsComplete
        self.privateSizeBytes = privateSizeBytes
        self.volume = volume
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case rawUUID
        case name
        case xid
        case purgeable
        case revertTo
        case rootTo
        case limitingContainerShrink
        case metadataIsComplete
        case privateSizeBytes
        case volume
    }
}

public enum SnapshotSource: Equatable, Sendable {
    case macOSUpdate
    case timeMachine
    case synologyActiveBackup
    case other

    public var localizedName: String {
        switch self {
        case .macOSUpdate: L10n.text("source.macos_update")
        case .timeMachine: L10n.text("source.time_machine")
        case .synologyActiveBackup: L10n.text("source.synology")
        case .other: L10n.text("source.other")
        }
    }
}

public enum SnapshotSafety: Equatable, Sendable {
    case deletable
    case protected(reasons: [String])

    public var isDeletable: Bool {
        if case .deletable = self {
            return true
        }
        return false
    }

    public var localizedStatus: String {
        switch self {
        case .deletable: L10n.text("safety.deletable")
        case .protected: L10n.text("safety.protected")
        }
    }

    public var reasons: [String] {
        if case let .protected(reasons) = self {
            return reasons
        }
        return []
    }
}

public struct AssessedSnapshot: Equatable, Sendable, Identifiable {
    public let snapshot: APFSSnapshot
    public let source: SnapshotSource
    public let safety: SnapshotSafety

    public var id: UUID { snapshot.id }

    public init(snapshot: APFSSnapshot, source: SnapshotSource, safety: SnapshotSafety) {
        self.snapshot = snapshot
        self.source = source
        self.safety = safety
    }
}

public extension AssessedSnapshot {
    var isForceDeletable: Bool {
        UUID(uuidString: snapshot.rawUUID) != nil
            && DeviceIdentifier.isValid(snapshot.volume.deviceIdentifier)
    }
}

public enum SnapshotDeletionMode: Equatable, Sendable {
    case standard
    case forceAdministrator

    public func permits(_ snapshot: AssessedSnapshot) -> Bool {
        switch self {
        case .standard:
            snapshot.safety.isDeletable
        case .forceAdministrator:
            snapshot.isForceDeletable
        }
    }
}

public enum SnapshotDeletionResult: Equatable, Sendable {
    case deleted(UUID)
    case skipped(UUID, reason: String)
    case failed(UUID, message: String)

    public var uuid: UUID {
        switch self {
        case let .deleted(uuid), let .skipped(uuid, _), let .failed(uuid, _):
            uuid
        }
    }
}

public enum DeviceIdentifier {
    public static func isValid(_ identifier: String) -> Bool {
        identifier.range(
            of: #"^disk[0-9]+s[0-9]+(?:s[0-9]+)?$"#,
            options: .regularExpression
        ) != nil
    }
}
