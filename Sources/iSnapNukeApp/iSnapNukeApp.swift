import AppKit
import Foundation
import SwiftUI
import iSnapNukeCore

@main
struct iSnapNukeApp: App {
    @NSApplicationDelegateAdaptor(iSnapNukeAppDelegate.self) private var appDelegate
    @StateObject private var viewModel: SnapshotViewModel

    #if DEBUG
        @StateObject private var demoController: DemoModeController
        private let launchesDemoMode: Bool
    #endif

    init() {
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
            rootPanel
        }
            .defaultSize(width: 520, height: 640)
            .windowResizability(.contentMinSize)
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
}

final class iSnapNukeAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }
}
