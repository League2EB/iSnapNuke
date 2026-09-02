import Combine
import Foundation

public enum UpdateGateState: Equatable, Sendable {
    case checking
    case allowed
    case optional(UpdatePolicy)
    case required(UpdatePolicy)
}

public enum UpdateManualCheckResult: Equatable, Sendable {
    case upToDate
    case unavailable
}

@MainActor
public protocol UpdateInstalling: AnyObject {
    func checkForUpdates()
}

@MainActor
public protocol UpdateDeferralStoring: AnyObject {
    var deferredBuild: Int? { get set }
}

@MainActor
public final class UserDefaultsUpdateDeferralStore: UpdateDeferralStoring {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "deferredUpdateBuild"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public var deferredBuild: Int? {
        get {
            guard defaults.object(forKey: key) != nil else { return nil }
            return defaults.integer(forKey: key)
        }
        set {
            if let newValue {
                defaults.set(newValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }
}

@MainActor
public final class UpdateCoordinator: ObservableObject {
    @Published public private(set) var state: UpdateGateState = .checking
    @Published public private(set) var isChecking = false
    @Published public private(set) var lastRefreshFailure: UpdateRefreshFailure?
    @Published public private(set) var manualCheckResult: UpdateManualCheckResult?

    private let currentVersion: AppVersion
    private let evaluator: any UpdatePolicyEvaluating
    private let installer: any UpdateInstalling
    private let deferralStore: any UpdateDeferralStoring
    private var hasStarted = false
    private var blocksRequiredTransition = false
    private var pendingRequiredPolicy: UpdatePolicy?
    private var installsOptionalUpdateAfterSheetDismissal = false

    public init(
        currentVersion: AppVersion,
        evaluator: any UpdatePolicyEvaluating,
        installer: any UpdateInstalling,
        deferralStore: any UpdateDeferralStoring = UserDefaultsUpdateDeferralStore()
    ) {
        self.currentVersion = currentVersion
        self.evaluator = evaluator
        self.installer = installer
        self.deferralStore = deferralStore
    }

    public func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        isChecking = true

        let cached = await evaluator.cachedEvaluation(for: currentVersion)
        apply(cached, honorsDeferral: true)
        if state == .checking {
            state = .allowed
        }
        isChecking = false
    }

    public func refreshAfterLaunch() async {
        guard hasStarted else { return }
        isChecking = true
        let refreshed = await evaluator.refreshEvaluation(for: currentVersion)
        apply(refreshed, honorsDeferral: true)
        isChecking = false
    }

    public func checkManually() async {
        isChecking = true
        manualCheckResult = nil

        let evaluation = await evaluator.refreshEvaluation(for: currentVersion)
        lastRefreshFailure = evaluation.failure

        guard let decision = evaluation.decision else {
            manualCheckResult = .unavailable
            isChecking = false
            return
        }

        switch decision {
        case .upToDate:
            state = .allowed
            manualCheckResult = .upToDate
        case let .optional(policy):
            state = .optional(policy)
        case let .required(policy):
            applyRequired(policy)
        }

        isChecking = false
    }

    public func deferOptionalUpdate() {
        guard case let .optional(policy) = state else { return }
        installsOptionalUpdateAfterSheetDismissal = false
        deferralStore.deferredBuild = policy.latestBuild
        state = .allowed
    }

    public func installUpdate() {
        installer.checkForUpdates()
    }

    public func beginOptionalUpdateInstallation() {
        guard case .optional = state else { return }
        installsOptionalUpdateAfterSheetDismissal = true
        state = .allowed
    }

    public func optionalUpdateSheetDidDismiss() {
        guard installsOptionalUpdateAfterSheetDismissal else { return }
        installsOptionalUpdateAfterSheetDismissal = false
        installer.checkForUpdates()
    }

    public func dismissManualCheckResult() {
        manualCheckResult = nil
    }

    public func setRequiredTransitionBlocked(_ isBlocked: Bool) {
        blocksRequiredTransition = isBlocked
        guard !isBlocked, let pendingRequiredPolicy else { return }
        self.pendingRequiredPolicy = nil
        state = .required(pendingRequiredPolicy)
    }

    private func apply(
        _ evaluation: UpdatePolicyEvaluation,
        honorsDeferral: Bool
    ) {
        lastRefreshFailure = evaluation.failure
        guard let decision = evaluation.decision else { return }

        switch decision {
        case .upToDate:
            state = .allowed
            if let deferredBuild = deferralStore.deferredBuild,
               deferredBuild <= currentVersion.build
            {
                deferralStore.deferredBuild = nil
            }

        case let .optional(policy):
            if honorsDeferral, deferralStore.deferredBuild == policy.latestBuild {
                state = .allowed
            } else {
                state = .optional(policy)
            }

        case let .required(policy):
            applyRequired(policy)
        }
    }

    private func applyRequired(_ policy: UpdatePolicy) {
        if blocksRequiredTransition {
            pendingRequiredPolicy = policy
        } else {
            pendingRequiredPolicy = nil
            state = .required(policy)
        }
    }
}
