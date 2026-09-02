import AppKit
import Foundation
import Sparkle
import iSnapNukeCore
import iSnapNukeLocalization

enum AppUpdateConfiguration {
    private static let policyURLKey = "iSnapNukeUpdatePolicyURL"
    private static let policyPublicKeyKey = "iSnapNukeUpdatePolicyPublicKey"
    private static let sparklePublicKeyKey = "SUPublicEDKey"

    static func makeLiveEvaluator() -> any UpdatePolicyEvaluating {
        guard
            let policyURLString = Bundle.main.object(
                forInfoDictionaryKey: policyURLKey
            ) as? String,
            let policyURL = URL(string: policyURLString),
            let policyPublicKey = configuredString(forInfoDictionaryKey: policyPublicKeyKey),
            isSparkleConfigured,
            let verifier = try? Ed25519UpdatePolicyVerifier(
                publicKeyBase64: policyPublicKey
            )
        else {
            return DisabledUpdatePolicyEvaluator()
        }

        return UpdatePolicyService(
            fetcher: URLSessionUpdatePolicyClient(url: policyURL),
            cache: FileUpdatePolicyCache(
                fileURL: FileUpdatePolicyCache.defaultFileURL(
                    bundleIdentifier: Bundle.main.bundleIdentifier ?? "com.xuanci.isnapnuke"
                )
            ),
            verifier: verifier
        )
    }

    static var isSparkleConfigured: Bool {
        guard
            let publicKey = configuredString(forInfoDictionaryKey: sparklePublicKeyKey),
            let rawPublicKey = Data(base64Encoded: publicKey)
        else {
            return false
        }
        return rawPublicKey.count == 32
    }

    private static func configuredString(forInfoDictionaryKey key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

@MainActor
final class SparkleUpdateInstaller: NSObject, UpdateInstalling {
    private var updaterController: SPUStandardUpdaterController?

    func checkForUpdates() {
        guard AppUpdateConfiguration.isSparkleConfigured else {
            NSAlert(
                error: NSError(
                    domain: "iSnapNuke.Update",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: L10n.text(
                            "update.install_unavailable_title"
                        ),
                        NSLocalizedRecoverySuggestionErrorKey: L10n.text(
                            "update.install_unavailable_body"
                        ),
                    ]
                )
            ).runModal()
            return
        }

        let controller: SPUStandardUpdaterController
        if let updaterController {
            controller = updaterController
        } else {
            controller = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
            updaterController = controller
        }
        controller.checkForUpdates(nil)
    }
}

@MainActor
final class DemoUpdateInstaller: UpdateInstalling {
    func checkForUpdates() {
        let alert = NSAlert()
        alert.messageText = L10n.text("update.demo_install_title")
        alert.informativeText = L10n.text("update.demo_install_body")
        alert.addButton(withTitle: L10n.text("action.ok"))
        alert.runModal()
    }
}

@MainActor
final class SessionUpdateDeferralStore: UpdateDeferralStoring {
    var deferredBuild: Int?
}

enum UpdateDemoScenario: String {
    case optional
    case required
    case upToDate
    case offline

    static func resolve(arguments: [String]) -> UpdateDemoScenario? {
        for (index, argument) in arguments.enumerated() {
            if argument.hasPrefix("--demo-update=") {
                return UpdateDemoScenario(
                    rawValue: String(argument.dropFirst("--demo-update=".count))
                )
            }
            if argument == "--demo-update", index + 1 < arguments.count {
                return UpdateDemoScenario(rawValue: arguments[index + 1])
            }
        }
        return nil
    }
}

struct DemoUpdatePolicyEvaluator: UpdatePolicyEvaluating {
    let scenario: UpdateDemoScenario

    func cachedEvaluation(for currentVersion: AppVersion) async -> UpdatePolicyEvaluation {
        evaluation(for: currentVersion)
    }

    func refreshEvaluation(for currentVersion: AppVersion) async -> UpdatePolicyEvaluation {
        evaluation(for: currentVersion)
    }

    private func evaluation(for currentVersion: AppVersion) -> UpdatePolicyEvaluation {
        guard scenario != .offline else {
            return UpdatePolicyEvaluation(
                decision: nil,
                source: .none,
                failure: .unavailable
            )
        }

        let policy: UpdatePolicy
        switch scenario {
        case .optional:
            policy = demoPolicy(
                latestVersion: "1.1.0",
                latestBuild: currentVersion.build + 1,
                minimumVersion: currentVersion.marketingVersion.description,
                minimumBuild: currentVersion.build
            )
        case .required:
            policy = demoPolicy(
                latestVersion: "1.1.0",
                latestBuild: currentVersion.build + 1,
                minimumVersion: "1.1.0",
                minimumBuild: currentVersion.build + 1
            )
        case .upToDate:
            policy = demoPolicy(
                latestVersion: currentVersion.marketingVersion.description,
                latestBuild: currentVersion.build,
                minimumVersion: currentVersion.marketingVersion.description,
                minimumBuild: currentVersion.build
            )
        case .offline:
            preconditionFailure("Offline policies return before creating a policy.")
        }

        return UpdatePolicyEvaluation(
            decision: policy.decision(for: currentVersion),
            source: .network
        )
    }

    private func demoPolicy(
        latestVersion: String,
        latestBuild: Int,
        minimumVersion: String,
        minimumBuild: Int
    ) -> UpdatePolicy {
        UpdatePolicy(
            latestVersion: try! SemanticVersion(latestVersion),
            latestBuild: latestBuild,
            minimumSupportedVersion: try! SemanticVersion(minimumVersion),
            minimumSupportedBuild: minimumBuild,
            releaseNotes: [
                "en": "This is a local demo update. No files will be downloaded.",
                "zh-Hant": "這是本機更新示範，不會下載任何檔案。",
            ],
            publishedAt: .now
        )
    }
}
