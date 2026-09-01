import XCTest
@testable import iSnapNukeCore

final class SnapshotDeletionSummaryTests: XCTestCase {
    func testCompleteSuccessRequiresAtLeastOneDeletedResult() {
        let summary = SnapshotDeletionSummary(
            results: [.deleted(UUID()), .deleted(UUID())]
        )

        XCTAssertEqual(summary.deletedCount, 2)
        XCTAssertEqual(summary.issueCount, 0)
        XCTAssertTrue(summary.isCompleteSuccess)
    }

    func testPartialSuccessIsNotCompleteSuccess() {
        let summary = SnapshotDeletionSummary(
            results: [
                .deleted(UUID()),
                .failed(UUID(), message: "Permission denied"),
            ]
        )

        XCTAssertEqual(summary.deletedCount, 1)
        XCTAssertEqual(summary.issueCount, 1)
        XCTAssertFalse(summary.isCompleteSuccess)
    }

    func testFailureIsNotCompleteSuccess() {
        let summary = SnapshotDeletionSummary(
            results: [.failed(UUID(), message: "Command failed")]
        )

        XCTAssertEqual(summary.deletedCount, 0)
        XCTAssertEqual(summary.issueCount, 1)
        XCTAssertFalse(summary.isCompleteSuccess)
    }

    func testSkippedResultIsNotCompleteSuccess() {
        let summary = SnapshotDeletionSummary(
            results: [.skipped(UUID(), reason: "Snapshot is no longer available")]
        )

        XCTAssertEqual(summary.deletedCount, 0)
        XCTAssertEqual(summary.issueCount, 1)
        XCTAssertFalse(summary.isCompleteSuccess)
    }

    func testEmptyResultsAreNotCompleteSuccess() {
        let summary = SnapshotDeletionSummary(results: [])

        XCTAssertEqual(summary.deletedCount, 0)
        XCTAssertEqual(summary.issueCount, 0)
        XCTAssertFalse(summary.isCompleteSuccess)
    }
}
