import CarpdmCore
import SwiftUI

public struct ProjectSidebarView: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    public init(viewModel: WorkspaceViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Projects")
                    .font(.headline)
                Spacer()
                Button("Open…") {
                    viewModel.openProjectPicker()
                }
            }

            List {
                ForEach(viewModel.projects) { project in
                    Button {
                        viewModel.selectProject(project)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.name)
                            Text(project.rootPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(viewModel.selectedProject?.id == project.id ? Color.accentColor.opacity(0.12) : Color.clear)
                }
            }
            .frame(maxHeight: 180)

            Divider()

            Text("Workspace")
                .font(.headline)

            ForEach(SidebarSection.allCases) { section in
                Button {
                    viewModel.workspaceState.selectedSection = section
                } label: {
                    Label(section.rawValue.replacingOccurrences(of: "_", with: " ").capitalized, systemImage: icon(for: section))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
            }

            Spacer()

            if let project = viewModel.selectedProject {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Agents")
                        .font(.headline)
                    ForEach(project.defaultAgents, id: \.self) { agent in
                        let health = viewModel.cliHealth[agent]
                        HStack {
                            Circle()
                                .fill((health?.isAvailable ?? false) ? .green : .orange)
                                .frame(width: 8, height: 8)
                            Text(agent.displayName)
                            Spacer()
                            Text((health?.isAvailable ?? false) ? "Ready" : "Missing")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 260, maxWidth: 280)
    }

    private func icon(for section: SidebarSection) -> String {
        switch section {
        case .backlog: "rectangle.3.group"
        case .notes: "note.text"
        case .sessions: "text.bubble"
        case .files: "doc.text"
        }
    }
}
