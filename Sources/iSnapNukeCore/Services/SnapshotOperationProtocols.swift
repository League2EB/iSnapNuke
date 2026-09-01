import Foundation

public protocol SnapshotScanning: Sendable {
    func scan() async throws -> [AssessedSnapshot]
}

public protocol SnapshotDeleting: Sendable {
    func delete(
        _ target: AssessedSnapshot,
        mode: SnapshotDeletionMode
    ) async -> SnapshotDeletionResult
}

public extension SnapshotDeleting {
    func delete(_ target: AssessedSnapshot) async -> SnapshotDeletionResult {
        await delete(target, mode: .standard)
    }
}

public protocol SnapshotDeletionPausing: Sendable {
    func pause(for duration: Duration) async
}

public struct TaskSnapshotDeletionPauser: SnapshotDeletionPausing {
    public init() {}

    public func pause(for duration: Duration) async {
        try? await Task.sleep(for: duration)
    }
}

public struct ImmediateSnapshotDeletionPauser: SnapshotDeletionPausing {
    public init() {}

    public func pause(for _: Duration) async {}
}

public struct SnapshotDeletionTiming: Equatable, Sendable {
    public let successDisplayDuration: Duration
    public let rowAnimationDuration: TimeInterval

    public init(
        successDisplayDuration: Duration,
        rowAnimationDuration: TimeInterval
    ) {
        self.successDisplayDuration = successDisplayDuration
        self.rowAnimationDuration = rowAnimationDuration
    }

    public static let standard = SnapshotDeletionTiming(
        successDisplayDuration: .milliseconds(360),
        rowAnimationDuration: 0.28
    )
}

public struct SnapshotDeletionProgress: Equatable, Sendable {
    public let current: Int
    public let total: Int

    public init(current: Int, total: Int) {
        self.current = current
        self.total = total
    }
}

public enum SnapshotOperationState: Equatable, Sendable {
    case queued(SnapshotDeletionProgress)
    case deleting(SnapshotDeletionProgress)
    case succeeded
    case failed(message: String)
    case skipped(reason: String)

    public var progress: SnapshotDeletionProgress? {
        switch self {
        case let .queued(progress), let .deleting(progress):
            progress
        case .succeeded, .failed, .skipped:
            nil
        }
    }
}
