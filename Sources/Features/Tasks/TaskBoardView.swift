import CarpdmCore
import SwiftUI

public struct TaskBoardView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @State private var showingNewTaskSheet = false
    @State private var title = ""
    @State private var description = ""

    public init(viewModel: WorkspaceViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Backlog")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("New Task") {
                    showingNewTaskSheet = true
                }
            }

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(TaskStatus.allCases) { status in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(status.displayName)
                                .font(.headline)
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 8) {
                                    ForEach(viewModel.tasks.filter { $0.status == status }) { task in
                                        Button {
                                            viewModel.selectTask(task)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 6) {
                                                HStack {
                                                    Text(task.title)
                                                        .font(.subheadline.weight(.medium))
                                                    Spacer()
                                                    Text(task.metadata.priority.rawValue.capitalized)
                                                        .font(.caption2)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.secondary.opacity(0.15))
                                                        .clipShape(Capsule())
                                                }
                                                Text(task.body.goal.isEmpty ? "No goal yet" : task.body.goal)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(3)
                                            }
                                            .padding(10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(viewModel.selectedTaskDraft?.id == task.id ? Color.accentColor.opacity(0.14) : Color(NSColor.windowBackgroundColor))
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            ForEach(TaskStatus.allCases) { destination in
                                                Button(destination.displayName) {
                                                    viewModel.moveTask(task, to: destination)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .frame(width: 240)
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewTaskSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("New Task")
                    .font(.title3.weight(.semibold))
                TextField("Title", text: $title)
                TextEditor(text: $description)
                    .frame(height: 140)
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showingNewTaskSheet = false
                    }
                    Button("Create") {
                        viewModel.createTask(title: title, description: description)
                        title = ""
                        description = ""
                        showingNewTaskSheet = false
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .frame(width: 420)
        }
    }
}

