import XCTest
@testable import iSnapNukeCore

final class SnapshotSafetyEvaluatorTests: XCTestCase {
    func testDataPurgeableSnapshotIsDeletable() {
        let snapshot = makeSnapshot()

        let assessment = SnapshotSafetyEvaluator.assess(snapshot)

        XCTAssertEqual(assessment.source, .other)
        XCTAssertEqual(assessment.safety, .deletable)
    }

    func testSystemUpdateIsProtectedEvenIfMarkedPurgeable() {
        let snapshot = makeSnapshot(
            role: .system,
            name: "com.apple.os.update-MSUPrepareUpdate",
            purgeable: true
        )

        let assessment = SnapshotSafetyEvaluator.assess(snapshot)

        XCTAssertEqual(assessment.source, .macOSUpdate)
        XCTAssertFalse(assessment.safety.isDeletable)
        XCTAssertEqual(assessment.safety.reasons.count, 2)
    }

    func testRevertOrRootSnapshotIsProtected() {
        let revertSnapshot = makeSnapshot(revertTo: true)
        let rootSnapshot = makeSnapshot(rootTo: true)

        XCTAssertFalse(SnapshotSafetyEvaluator.safety(for: revertSnapshot).isDeletable)
        XCTAssertFalse(SnapshotSafetyEvaluator.safety(for: rootSnapshot).isDeletable)
    }

    func testNonPurgeableSnapshotIsProtected() {
        let snapshot = makeSnapshot(purgeable: false)

        let safety = SnapshotSafetyEvaluator.safety(for: snapshot)

        XCTAssertFalse(safety.isDeletable)
        XCTAssertEqual(safety.reasons.count, 1)
    }

    func testInvalidDeviceIdentifierIsProtected() {
        let snapshot = makeSnapshot(deviceIdentifier: "not-a-disk")

        XCTAssertFalse(SnapshotSafetyEvaluator.safety(for: snapshot).isDeletable)
    }

    func testInvalidUUIDIsProtected() {
        let snapshot = APFSSnapshot(
            uuid: UUID(),
            rawUUID: "invalid-uuid",
            name: "com.example.snapshot",
            xid: 12,
            purgeable: true,
            revertTo: false,
            rootTo: false,
            limitingContainerShrink: false,
            volume: APFSVolume(
                role: .data,
                deviceIdentifier: "disk3s1",
                name: "Data",
                mountPoint: "/System/Volumes/Data"
            )
        )

        XCTAssertFalse(SnapshotSafetyEvaluator.safety(for: snapshot).isDeletable)
    }

    func testForceDeletionAllowsProtectedSnapshotsWithValidIdentifiers() {
        let snapshot = makeSnapshot(
            role: .system,
            name: "com.apple.os.update-MSUPrepareUpdate",
            purgeable: false
        )

        let assessment = SnapshotSafetyEvaluator.assess(snapshot)

        XCTAssertFalse(assessment.safety.isDeletable)
        XCTAssertTrue(assessment.isForceDeletable)
        XCTAssertFalse(SnapshotDeletionMode.standard.permits(assessment))
        XCTAssertTrue(SnapshotDeletionMode.forceAdministrator.permits(assessment))
    }

    func testForceDeletionRejectsMalformedIdentifiers() {
        let invalidDevice = SnapshotSafetyEvaluator.assess(
            makeSnapshot(deviceIdentifier: "not-a-disk")
        )
        let invalidUUID = SnapshotSafetyEvaluator.assess(
            APFSSnapshot(
                uuid: UUID(),
                rawUUID: "invalid-uuid",
                name: "com.example.snapshot",
                xid: 12,
                purgeable: true,
                revertTo: false,
                rootTo: false,
                limitingContainerShrink: false,
                volume: APFSVolume(
                    role: .data,
                    deviceIdentifier: "disk3s1",
                    name: "Data",
                    mountPoint: "/System/Volumes/Data"
                )
            )
        )

        XCTAssertFalse(invalidDevice.isForceDeletable)
        XCTAssertFalse(invalidUUID.isForceDeletable)
    }

    func testSourceDetectionRecognizesKnownSources() {
        XCTAssertEqual(
            SnapshotSafetyEvaluator.source(for: "com.synology.activebackup.job"),
            .synologyActiveBackup
        )
        XCTAssertEqual(
            SnapshotSafetyEvaluator.source(for: "com.apple.TimeMachine.2026-08-30.local"),
            .timeMachine
        )
        XCTAssertEqual(
            SnapshotSafetyEvaluator.source(for: "com.apple.os.update-abc"),
            .macOSUpdate
        )
    }

    private func makeSnapshot(
        role: VolumeRole = .data,
        deviceIdentifier: String = "disk3s1",
        name: String = "com.example.snapshot",
        purgeable: Bool = true,
        revertTo: Bool = false,
        rootTo: Bool = false
    ) -> APFSSnapshot {
        APFSSnapshot(
            uuid: UUID(uuidString: "0FA116AA-913B-4A65-95B0-D5769B5C8097")!,
            name: name,
            xid: 12,
            purgeable: purgeable,
            revertTo: revertTo,
            rootTo: rootTo,
            limitingContainerShrink: false,
            volume: APFSVolume(
                role: role,
                deviceIdentifier: deviceIdentifier,
                name: "Data",
                mountPoint: "/System/Volumes/Data"
            )
        )
    }
}
