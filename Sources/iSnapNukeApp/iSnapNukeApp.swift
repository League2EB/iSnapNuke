import AppKit
import Foundation
import SwiftUI
import iSnapNukeCore
import iSnapNukeLocalization

@main
struct iSnapNukeApp: App {
    @NSApplicationDelegateAdaptor(iSnapNukeAppDelegate.self) private var appDelegate
    @StateObject private var viewModel: SnapshotViewModel
    @StateObject private var updateCoordinator: UpdateCoordinator

    #if DEBUG
        @StateObject private var demoController: DemoModeController
        private let launchesDemoMode: Bool
    #endif

    init() {
        let appVersion = (try? AppVersion(bundle: .main)) ?? {
            try! AppVersion(marketingVersion: "0.0.0", build: "1")
        }()

        #if DEBUG
            let updateDemoScenario = UpdateDemoScenario.resolve(
                arguments: ProcessInfo.processInfo.arguments
            )
            let updateEvaluator: any UpdatePolicyEvaluating = if let updateDemoScenario {
                DemoUpdatePolicyEvaluator(scenario: updateDemoScenario)
            } else {
                AppUpdateConfiguration.makeLiveEvaluator()
            }
            let updateInstaller: any UpdateInstalling = if updateDemoScenario == nil {
                SparkleUpdateInstaller()
            } else {
                DemoUpdateInstaller()
            }
            let updateDeferralStore: any UpdateDeferralStoring = if updateDemoScenario == nil {
                UserDefaultsUpdateDeferralStore()
            } else {
                SessionUpdateDeferralStore()
            }
        #else
            let updateEvaluator: any UpdatePolicyEvaluating =
                AppUpdateConfiguration.makeLiveEvaluator()
            let updateInstaller: any UpdateInstalling = SparkleUpdateInstaller()
            let updateDeferralStore: any UpdateDeferralStoring =
                UserDefaultsUpdateDeferralStore()
        #endif

        _updateCoordinator = StateObject(
            wrappedValue: UpdateCoordinator(
                currentVersion: appVersion,
                evaluator: updateEvaluator,
                installer: updateInstaller,
                deferralStore: updateDeferralStore
            )
        )

        #if DEBUG
            let demoController = DemoModeController()
            let launchesDemoMode = ProcessInfo.processInfo.arguments.contains("--demo")
            _demoController = StateObject(wrappedValue: demoController)
            _viewModel = StateObject(
                wrappedValue: launchesDemoMode ? demoController.viewModel : SnapshotViewModel()
            )
            self.launchesDemoMode = launchesDemoMode
        #else
            _viewModel = StateObject(wrappedValue: SnapshotViewModel())
        #endif
    }

    var body: some Scene {
        WindowGroup("iSnapNuke") {
            appContent
                .task {
                    await updateCoordinator.start()
                    await updateCoordinator.refreshAfterLaunch()
                }
                .onChange(of: viewModel.isDeleting) { _, isDeleting in
                    updateCoordinator.setRequiredTransitionBlocked(isDeleting)
                }
        }
            .defaultSize(width: 520, height: 640)
            .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button(L10n.text("update.check_for_updates")) {
                    Task { await updateCoordinator.checkManually() }
                }
                .disabled(updateCoordinator.isChecking)
            }
        }
    }

    @ViewBuilder
    private var appContent: some View {
        Group {
            switch updateCoordinator.state {
            case .checking:
                UpdateCheckPanel()
            case let .required(policy):
                RequiredUpdatePanel(
                    policy: policy,
                    isChecking: updateCoordinator.isChecking,
                    onInstall: updateCoordinator.installUpdate,
                    onRetry: {
                        Task { await updateCoordinator.checkManually() }
                    },
                    onQuit: { NSApplication.shared.terminate(nil) }
                )
            case .allowed, .optional:
                rootPanel
            }
        }
        .sheet(
            isPresented: Binding(
                get: {
                    if case .optional = updateCoordinator.state {
                        return true
                    }
                    return false
                },
                set: { isPresented in
                    if !isPresented {
                        updateCoordinator.deferOptionalUpdate()
                    }
                }
            )
        ) {
            if case let .optional(policy) = updateCoordinator.state {
                OptionalUpdateSheet(
                    policy: policy,
                    onInstall: updateCoordinator.installUpdate,
                    onLater: updateCoordinator.deferOptionalUpdate
                )
            }
        }
        .alert(
            manualCheckAlertTitle,
            isPresented: Binding(
                get: { updateCoordinator.manualCheckResult != nil },
                set: { isPresented in
                    if !isPresented {
                        updateCoordinator.dismissManualCheckResult()
                    }
                }
            )
        ) {
            Button(L10n.text("action.ok"), role: .cancel) {
                updateCoordinator.dismissManualCheckResult()
            }
        } message: {
            Text(manualCheckAlertBody)
        }
    }

    @ViewBuilder
    private var rootPanel: some View {
        #if DEBUG
            SnapshotPanel(
                viewModel: viewModel,
                demoController: launchesDemoMode ? demoController : nil
            )
                .frame(minWidth: 520, idealWidth: 520, minHeight: 640, idealHeight: 640)
        #else
            SnapshotPanel(viewModel: viewModel)
                .frame(minWidth: 520, idealWidth: 520, minHeight: 640, idealHeight: 640)
        #endif
    }

    private var manualCheckAlertTitle: String {
        switch updateCoordinator.manualCheckResult {
        case .upToDate:
            L10n.text("update.manual_up_to_date_title")
        case .unavailable, .none:
            L10n.text("update.manual_unavailable_title")
        }
    }

    private var manualCheckAlertBody: String {
        switch updateCoordinator.manualCheckResult {
        case .upToDate:
            L10n.text("update.manual_up_to_date_body")
        case .unavailable, .none:
            L10n.text("update.manual_unavailable_body")
        }
    }
}

final class iSnapNukeAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }
}
