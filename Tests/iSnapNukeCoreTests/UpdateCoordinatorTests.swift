import XCTest
@testable import iSnapNukeCore

@MainActor
final class UpdateCoordinatorTests: XCTestCase {
    func testOptionalUpdateCanBeDeferredForItsSpecificBuild() async {
        let policy = makeUpdatePolicy(latestBuild: 2, minimumBuild: 1)
        let evaluator = StubUpdatePolicyEvaluator(
            cached: UpdatePolicyEvaluation(decision: .optional(policy), source: .cache),
            refreshed: UpdatePolicyEvaluation(decision: .optional(policy), source: .network)
        )
        let installer = RecordingUpdateInstaller()
        let deferralStore = InMemoryUpdateDeferralStore()
        let coordinator = UpdateCoordinator(
            currentVersion: makeUpdateVersion(build: 1),
            evaluator: evaluator,
            installer: installer,
            deferralStore: deferralStore
        )

        await coordinator.start()
        await coordinator.refreshAfterLaunch()
        XCTAssertEqual(coordinator.state, .optional(policy))

        coordinator.deferOptionalUpdate()
        XCTAssertEqual(coordinator.state, .allowed)
        XCTAssertEqual(deferralStore.deferredBuild, 2)

        await coordinator.checkManually()
        XCTAssertEqual(coordinator.state, .optional(policy))
    }

    func testRequiredUpdateBlocksAfterDeletionFinishes() async {
        let requiredPolicy = makeUpdatePolicy(latestBuild: 3, minimumBuild: 2)
        let evaluator = StubUpdatePolicyEvaluator(
            cached: UpdatePolicyEvaluation(decision: .upToDate, source: .cache),
            refreshed: UpdatePolicyEvaluation(
                decision: .required(requiredPolicy),
                source: .network
            )
        )
        let coordinator = UpdateCoordinator(
            currentVersion: makeUpdateVersion(build: 1),
            evaluator: evaluator,
            installer: RecordingUpdateInstaller(),
            deferralStore: InMemoryUpdateDeferralStore()
        )

        coordinator.setRequiredTransitionBlocked(true)
        await coordinator.start()
        await coordinator.refreshAfterLaunch()
        XCTAssertEqual(coordinator.state, .allowed)

        coordinator.setRequiredTransitionBlocked(false)
        XCTAssertEqual(coordinator.state, .required(requiredPolicy))
    }

    func testInstallDelegatesToInstaller() {
        let installer = RecordingUpdateInstaller()
        let coordinator = UpdateCoordinator(
            currentVersion: makeUpdateVersion(),
            evaluator: StubUpdatePolicyEvaluator(
                cached: UpdatePolicyEvaluation(decision: .upToDate, source: .none),
                refreshed: UpdatePolicyEvaluation(decision: .upToDate, source: .none)
            ),
            installer: installer,
            deferralStore: InMemoryUpdateDeferralStore()
        )

        coordinator.installUpdate()

        XCTAssertEqual(installer.checkCount, 1)
    }
}
