import XCTest
@testable import iSnapNukeCore

final class DiskUtilityScannerTests: XCTestCase {
    func testScannerParsesAndAssessesFixtureSnapshots() async throws {
        let scanner = fixtureScanner(runner: FixtureRunner.standard)

        let snapshots = try await scanner.scan()

        XCTAssertEqual(snapshots.count, 3)
        XCTAssertEqual(snapshots.map(\.snapshot.volume.role), [.data, .data, .system])
        let synology = try XCTUnwrap(
            snapshots.first { $0.snapshot.name == "com.synology.activebackup.example" }
        )
        let retained = try XCTUnwrap(
            snapshots.first { $0.snapshot.name == "com.example.retained" }
        )
        let systemUpdate = try XCTUnwrap(
            snapshots.first { $0.snapshot.name == "com.apple.os.update-example" }
        )

        XCTAssertEqual(synology.source, .synologyActiveBackup)
        XCTAssertTrue(synology.safety.isDeletable)
        XCTAssertEqual(synology.snapshot.privateSizeBytes, 5_191_966_720)
        XCTAssertFalse(retained.safety.isDeletable)
        XCTAssertEqual(retained.snapshot.privateSizeBytes, 1_073_819_648)
        XCTAssertFalse(systemUpdate.safety.isDeletable)
    }

    func testInvalidSnapshotUUIDIsListedAsProtected() async throws {
        var responses = FixtureRunner.standard.responses
        responses[FixtureRunner.key(["apfs", "listSnapshots", "disk3s1", "-plist"])] = .success(
            plist(named: "invalid-snapshot-list")
        )
        let scanner = fixtureScanner(runner: FixtureRunner(responses: responses))

        let snapshots = try await scanner.scan()

        XCTAssertEqual(snapshots.count, 2)
        let malformed = try XCTUnwrap(
            snapshots.first { $0.snapshot.name == "com.example.invalid" }
        )
        XCTAssertFalse(malformed.safety.isDeletable)
        XCTAssertFalse(malformed.safety.reasons.isEmpty)
    }

    func testIncompleteSnapshotMetadataIsListedAsProtected() async throws {
        var responses = FixtureRunner.standard.responses
        responses[FixtureRunner.key(["apfs", "listSnapshots", "disk3s1", "-plist"])] = .success(
            plist(named: "incomplete-snapshot-list")
        )
        let scanner = fixtureScanner(runner: FixtureRunner(responses: responses))

        let snapshots = try await scanner.scan()

        XCTAssertEqual(snapshots.count, 2)
        let incomplete = try XCTUnwrap(
            snapshots.first { $0.snapshot.name == "com.example.incomplete" }
        )
        XCTAssertFalse(incomplete.snapshot.metadataIsComplete)
        XCTAssertFalse(incomplete.safety.isDeletable)
        XCTAssertFalse(incomplete.safety.reasons.isEmpty)
    }
}
