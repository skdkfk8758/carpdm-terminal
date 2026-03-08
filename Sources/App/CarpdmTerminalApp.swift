import CarpdmFeatures
import SwiftUI

@MainActor
@main
struct CarpdmTerminalApp: App {
    @StateObject private var viewModel: WorkspaceViewModel
    @StateObject private var updater = AppUpdater()

    init() {
        let viewModel = (try? AppEnvironment.makeViewModel()) ?? WorkspaceViewModel.preview
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some Scene {
        WindowGroup {
            WorkspaceRootView(viewModel: viewModel)
                .frame(minWidth: 1320, minHeight: 820)
                .task {
                    viewModel.load()
                }
        }
        .commands {
            CommandMenu("Workspace") {
                Button("Open Project") { viewModel.openProjectPicker() }
                Button("Refresh") { viewModel.refresh() }
                Button("Command Palette") { viewModel.openCommandPalette() }
                    .keyboardShortcut("k", modifiers: [.command])
            }

            CommandMenu("Updates") {
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            }
        }
    }
}
