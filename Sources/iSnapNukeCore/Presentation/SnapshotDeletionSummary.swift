import Foundation

public struct SnapshotDeletionSummary: Equatable, Sendable {
    public let results: [SnapshotDeletionResult]

    public init(results: [SnapshotDeletionResult]) {
        self.results = results
    }

    public var deletedCount: Int {
        results.reduce(into: 0) { count, result in
            if case .deleted = result {
                count += 1
            }
        }
    }

    public var issueCount: Int {
        results.count - deletedCount
    }

    public var isCompleteSuccess: Bool {
        !results.isEmpty && issueCount == 0
    }
}
