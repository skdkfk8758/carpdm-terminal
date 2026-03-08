import CarpdmCore
import AppKit
import SwiftTerm
import SwiftUI

public struct ShellTerminalView: NSViewRepresentable {
    public var workingDirectory: String?

    public init(workingDirectory: String?) {
        self.workingDirectory = workingDirectory
    }

    public func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView(frame: .zero)
        terminal.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        terminal.startProcess(
            executable: "/bin/zsh",
            args: ["-l"],
            currentDirectory: workingDirectory
        )
        return terminal
    }

    public func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}
