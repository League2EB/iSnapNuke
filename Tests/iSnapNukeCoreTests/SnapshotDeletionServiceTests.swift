import XCTest
@testable import iSnapNukeCore
import iSnapNukeLocalization

final class SnapshotDeletionServiceTests: XCTestCase {
    func testProtectedSnapshotDoesNotRunAnyCommand() async {
        let runner = RecordingRunner(responses: [:])
        let service = SnapshotDeletionService(runner: runner)
        let protectedTarget = AssessedSnapshot(
            snapshot: makeSnapshot(purgeable: false),
            source: .other,
            safety: .protected(reasons: ["test"])
        )

        let result = await service.delete(protectedTarget)

        XCTAssertEqual(result, .skipped(protectedTarget.id, reason: L10n.text("result.snapshot_protected")))
        let calls = await runner.calls()
        XCTAssertTrue(calls.isEmpty)
    }

    func testDeleteRescansThenUsesExactDiskutilArguments() async throws {
        let runner = RecordingRunner(responses: FixtureRunner.standard.responses.merging([
            FixtureRunner.key([
                "apfs",
                "deleteSnapshot",
                "disk3s1",
                "-uuid",
                "0FA116AA-913B-4A65-95B0-D5769B5C8097",
                "-wait",
            ]): .success(Data())
        ]) { _, new in new })
        let scanner = fixtureScanner(runner: runner)
        let scannedSnapshots = try await scanner.scan()
        let target = try XCTUnwrap(scannedSnapshots.first(where: { $0.safety.isDeletable }))
        let service = SnapshotDeletionService(runner: runner, scanner: scanner)

        let result = await service.delete(target)
        let calls = await runner.calls()

        XCTAssertEqual(result, .deleted(target.id))
        XCTAssertEqual(
            calls.last?.arguments,
            [
                "apfs",
                "deleteSnapshot",
                "disk3s1",
                "-uuid",
                "0FA116AA-913B-4A65-95B0-D5769B5C8097",
                "-wait",
            ]
        )
    }

    func testAdminRetryBuildsFixedWhitelistedCommand() async throws {
        let scannedSnapshots = try await fixtureScanner(runner: FixtureRunner.standard).scan()
        let target = try XCTUnwrap(scannedSnapshots.first(where: { $0.safety.isDeletable }))
        let adminCallKey = FixtureRunner.key([
            "-e",
            "do shell script \"/usr/sbin/diskutil apfs deleteSnapshot disk3s1 -uuid 0FA116AA-913B-4A65-95B0-D5769B5C8097 -wait\" with administrator privileges",
        ])
        let runner = RecordingRunner(responses: FixtureRunner.standard.responses.merging([
            adminCallKey: .success(Data())
        ]) { _, new in new })
        let service = AdminSnapshotDeletionService(
            runner: runner,
            scanner: fixtureScanner(runner: runner)
        )

        let result = await service.delete(target)
        let calls = await runner.calls()

        XCTAssertEqual(result, .deleted(target.id))
        let script = try XCTUnwrap(calls.last?.arguments.last)
        XCTAssertEqual(
            script,
            "do shell script \"/usr/sbin/diskutil apfs deleteSnapshot disk3s1 -uuid 0FA116AA-913B-4A65-95B0-D5769B5C8097 -wait\" with administrator privileges"
        )
    }

    func testForceAdministratorDeletesProtectedUpdateSnapshot() async throws {
        let target = assess(
            makeSnapshot(
                role: .system,
                deviceIdentifier: "disk3s5",
                name: "com.apple.os.update-example",
                purgeable: false
            )
        )
        let expectedScript = "do shell script \"/usr/sbin/diskutil apfs deleteSnapshot disk3s5 -uuid 0FA116AA-913B-4A65-95B0-D5769B5C8097 -wait\" with administrator privileges"
        let runner = RecordingRunner(responses: [
            FixtureRunner.key(["-e", expectedScript]): .success(Data()),
        ])
        let service = AdminSnapshotDeletionService(
            runner: runner,
            scanner: StaticSnapshotScanner(snapshots: [target])
        )

        let result = await service.delete(target, mode: .forceAdministrator)
        let calls = await runner.calls()

        XCTAssertEqual(result, .deleted(target.id))
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].arguments, ["-e", expectedScript])
    }

    func testForceAdministratorRejectsMalformedProtectedSnapshotBeforeScanning() async {
        let target = AssessedSnapshot(
            snapshot: APFSSnapshot(
                uuid: UUID(),
                rawUUID: "not-a-uuid",
                name: "com.apple.os.update-example",
                xid: 12,
                purgeable: false,
                revertTo: false,
                rootTo: false,
                limitingContainerShrink: false,
                volume: APFSVolume(
                    role: .system,
                    deviceIdentifier: "disk3s5",
                    name: "Macintosh HD",
                    mountPoint: "/"
                )
            ),
            source: .macOSUpdate,
            safety: .protected(reasons: ["test"])
        )
        let runner = RecordingRunner(responses: [:])
        let service = AdminSnapshotDeletionService(
            runner: runner,
            scanner: StaticSnapshotScanner(snapshots: [target])
        )

        let result = await service.delete(target, mode: .forceAdministrator)
        let calls = await runner.calls()

        XCTAssertEqual(
            result,
            .skipped(
                target.id,
                reason: SnapshotDeletionError.malformedInput.localizedDescription
            )
        )
        XCTAssertTrue(calls.isEmpty)
    }

    func testForceAdministratorBatchContinuesAfterFailure() async {
        let first = assess(
            makeSnapshot(
                role: .system,
                deviceIdentifier: "disk3s5",
                name: "com.apple.os.update-first",
                purgeable: false
            )
        )
        let second = assess(
            makeSnapshot(
                uuid: "E35DF2CA-16E1-448A-AD02-059C0DB240C2",
                role: .system,
                deviceIdentifier: "disk3s5",
                name: "com.apple.os.update-second",
                purgeable: false
            )
        )
        let firstScript = adminScript(for: first)
        let secondScript = adminScript(for: second)
        let runner = RecordingRunner(responses: [
            FixtureRunner.key(["-e", firstScript]): CommandResult(
                status: 1,
                standardOutput: Data(),
                standardError: Data("Operation not permitted".utf8)
            ),
            FixtureRunner.key(["-e", secondScript]): .success(Data()),
        ])
        let service = AdminSnapshotDeletionService(
            runner: runner,
            scanner: StaticSnapshotScanner(snapshots: [first, second])
        )

        let results = await service.delete(
            [first, second],
            mode: .forceAdministrator
        )
        let calls = await runner.calls()

        XCTAssertEqual(
            results,
            [
                .failed(first.id, message: "Operation not permitted"),
                .deleted(second.id),
            ]
        )
        XCTAssertEqual(calls.map(\.arguments), [["-e", firstScript], ["-e", secondScript]])
    }

    func testDeletionStopsFollowingBatchAfterFailure() async throws {
        let scannedSnapshots = try await fixtureScanner(runner: FixtureRunner.standard).scan()
        let target = try XCTUnwrap(scannedSnapshots.first(where: { $0.safety.isDeletable }))
        let failureKey = FixtureRunner.key([
            "apfs",
            "deleteSnapshot",
            "disk3s1",
            "-uuid",
            "0FA116AA-913B-4A65-95B0-D5769B5C8097",
            "-wait",
        ])
        let runner = RecordingRunner(responses: FixtureRunner.standard.responses.merging([
            failureKey: CommandResult(
                status: 1,
                standardOutput: Data(),
                standardError: Data("Permission denied".utf8)
            )
        ]) { _, new in new })
        let service = SnapshotDeletionService(
            runner: runner,
            scanner: fixtureScanner(runner: runner)
        )

        let results = await service.delete([target, target])

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].isLikelyPermissionFailure)
    }

    private func makeSnapshot(
        uuid: String = "0FA116AA-913B-4A65-95B0-D5769B5C8097",
        role: VolumeRole = .data,
        deviceIdentifier: String = "disk3s1",
        name: String = "com.example.snapshot",
        purgeable: Bool
    ) -> APFSSnapshot {
        APFSSnapshot(
            uuid: UUID(uuidString: uuid)!,
            name: name,
            xid: 1,
            purgeable: purgeable,
            revertTo: false,
            rootTo: false,
            limitingContainerShrink: false,
            volume: APFSVolume(
                role: role,
                deviceIdentifier: deviceIdentifier,
                name: role == .data ? "Data" : "Macintosh HD",
                mountPoint: role == .data ? "/System/Volumes/Data" : "/"
            )
        )
    }

    private func assess(_ snapshot: APFSSnapshot) -> AssessedSnapshot {
        SnapshotSafetyEvaluator.assess(snapshot)
    }

    private func adminScript(for target: AssessedSnapshot) -> String {
        "do shell script \"/usr/sbin/diskutil apfs deleteSnapshot \(target.snapshot.volume.deviceIdentifier) -uuid \(target.snapshot.rawUUID) -wait\" with administrator privileges"
    }
}

private struct StaticSnapshotScanner: SnapshotScanning {
    let snapshots: [AssessedSnapshot]

    func scan() async throws -> [AssessedSnapshot] {
        snapshots
    }
}

private actor RecordingRunner: CommandRunning {
    struct Call: Sendable {
        let executable: URL
        let arguments: [String]
    }

    private let responses: [String: CommandResult]
    private var recordedCalls: [Call] = []

    init(responses: [String: CommandResult]) {
        self.responses = responses
    }

    func run(executable: URL, arguments: [String]) async throws -> CommandResult {
        recordedCalls.append(Call(executable: executable, arguments: arguments))
        guard let result = responses[FixtureRunner.key(arguments)] else {
            throw TestRunnerError.missingResponse(arguments)
        }
        return result
    }

    func calls() -> [Call] {
        recordedCalls
    }
}
