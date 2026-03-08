import CarpdmCore
import CarpdmInfrastructure
import SwiftUI

public struct TerminalPanelView: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    public init(viewModel: WorkspaceViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        TabView(selection: $viewModel.selectedTerminalTabID) {
            ShellTerminalView(workingDirectory: viewModel.selectedProject?.rootPath)
                .id(viewModel.selectedProject?.id)
                .tabItem { Text("Shell") }
                .tag("shell")

            ForEach(viewModel.terminalTabs) { tab in
                ScrollView {
                    Text(tab.content.isEmpty ? "No output yet." : tab.content)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(Color(NSColor.textBackgroundColor))
                .tabItem { Text(tab.title) }
                .tag(tab.id)
            }
        }
    }
}

