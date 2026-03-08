import CarpdmCore
import SwiftUI

public struct WorkspaceRootView: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    public init(viewModel: WorkspaceViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VSplitView {
            HSplitView {
                ProjectSidebarView(viewModel: viewModel)

                Group {
                    switch viewModel.workspaceState.selectedSection {
                    case .backlog:
                        TaskBoardView(viewModel: viewModel)
                    case .notes:
                        NotesListView(notes: viewModel.notes)
                    case .sessions:
                        sessionsView
                    case .files:
                        changedFilesView
                    }
                }
                .frame(minWidth: 420)

                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.workspaceState.selectedSection == .backlog {
                        TaskDetailView(viewModel: viewModel)
                    } else {
                        inspectorFallback
                    }
                    Divider()
                    ApprovalQueueView(viewModel: viewModel)
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Context")
                            .font(.headline)
                        ScrollView {
                            Text(viewModel.currentContext)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(16)
                .frame(minWidth: 320, maxWidth: 360)
            }

            TerminalPanelView(viewModel: viewModel)
                .frame(minHeight: 180, idealHeight: viewModel.workspaceState.terminalHeight)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Open Project") { viewModel.openProjectPicker() }
                Button("Refresh") { viewModel.refresh() }
                Button("Command Palette") { viewModel.openCommandPalette() }
                    .keyboardShortcut("k", modifiers: [.command])
            }
        }
        .overlay(alignment: .bottomLeading) {
            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .padding(8)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .padding()
            }
        }
        .sheet(isPresented: $viewModel.isCommandPalettePresented) {
            CommandPaletteView(viewModel: viewModel)
        }
    }

    private var sessionsView: some View {
        List(viewModel.sessions) { session in
            VStack(alignment: .leading, spacing: 4) {
                Text("\(session.agentType.displayName) · \(session.role.rawValue)")
                Text(session.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var changedFilesView: some View {
        List(viewModel.gitSummary.changedFiles) { file in
            HStack {
                Text(file.statusCode)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.path)
                    Text("Reveal in Finder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Reveal") {
                    viewModel.revealChangedFile(file)
                }
            }
        }
    }

    private var inspectorFallback: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Inspector")
                .font(.headline)
            Text("Choose a task from the backlog to inspect planning, outputs, and approval state.")
                .foregroundStyle(.secondary)
        }
    }
}

private struct CommandPaletteView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @State private var query = ""

    private let commands: [(String, String)] = [
        ("open-project", "Open Project"),
        ("new-task", "New Task"),
        ("run-plan", "Run Plan"),
        ("run-implementation", "Run Implementation"),
        ("run-review", "Run Pre-Commit Review")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Search commands", text: $query)
            List(filteredCommands, id: \.0) { command in
                Button(command.1) {
                    viewModel.performCommand(command.0)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(width: 380, height: 280)
    }

    private var filteredCommands: [(String, String)] {
        guard !query.isEmpty else { return commands }
        return commands.filter { $0.1.localizedCaseInsensitiveContains(query) }
    }
}
