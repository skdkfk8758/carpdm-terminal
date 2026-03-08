import Foundation
import Sparkle
import SwiftUI

@MainActor
final class AppUpdater: ObservableObject {
    private let updaterController: SPUStandardUpdaterController?

    init() {
        // Sparkle only works from a bundled app, not from `swift run`.
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            updaterController = nil
            return
        }

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var canCheckForUpdates: Bool {
        updaterController != nil
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }
}
